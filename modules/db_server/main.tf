/*****************
 * Variables
 *****************/
variable "ssh_key_id" {}
variable "ssh_keyfile" { default = "id_rsa" }
variable "zone" { default = "is1a" }
variable "switch_id" {}
variable "private_ip_addresses" {}
variable "name_suffix" { default = "db" }

variable "mysql_root_password" { default = "mysql_password" }
variable "mysql_user_name" { default = "demo" }
variable "mysql_user_password" { default = "demo_password" }
variable "mysql_server_id" {}

/*****************
 * Disk
 *****************/
resource "sakuracloud_disk" "disk" {
    name = "${format("disk_%s_%s_%02d" , "${var.zone}" ,  "${var.name_suffix}" , count.index+1)}"
    source_archive_name = "CentOS 7.2 64bit"
    ssh_key_ids = ["${var.ssh_key_id}"]
    disable_pw_auth = true
    count = 1
    zone = "${var.zone}"
}
/*****************
 * Server 
 *****************/
resource "sakuracloud_server" "server" {
    name = "${format("server_%s_%s_%02d" , "${var.zone}" , "${var.name_suffix}" , count.index+1)}"
    disks = ["${element(sakuracloud_disk.disk.*.id,count.index)}"]
    additional_interfaces = ["${var.switch_id}"]
    packet_filter_ids = ["${sakuracloud_packet_filter.pf_db.id}"]
    tags = ["@virtio-net-pci"]
    count = 1
    zone = "${var.zone}"
    # サーバーにはSSHで接続
    connection {
        user = "root"
        host = "${self.base_nw_ipaddress}"
        private_key = "${file("${path.root}/${var.ssh_keyfile}")}"
    }

    # yumでmysqlのインストール
    provisioner "remote-exec" {
        inline = [
          "yum install -y mysql-community-server",
          "cat << EOF > /etc/my.cnf \n ${template_file.mycnf.rendered}\nEOF\n",
          "systemctl start mysql.service",
          "mysql -uroot -e 'GRANT ALL ON *.* TO ${var.mysql_user_name}@\"192.168.2.%\" IDENTIFIED BY \"${var.mysql_user_password}\"'" ,
          "mysqladmin -u root password '${var.mysql_root_password}'",
          "systemctl stop firewalld.service",
          "systemctl disable firewalld.service"
        ]
    }

    # IP設定スクリプトをアップロード
    provisioner "file" {
        source = "${path.module}/provision_private_ip.sh"
        destination = "/tmp/provision_private_ip.sh"
    }

    # IP設定実行
    provisioner "remote-exec" {
        inline = [
          "chmod +x /tmp/provision_private_ip.sh",
          "/tmp/provision_private_ip.sh ${element(split("," , var.private_ip_addresses) , count.index)}"
        ]
    }
}

resource "template_file" "mycnf" {
    template = "${file("${path.module}/my.cnf")}"
    vars {
        server_id = "${var.mysql_server_id}"
    }
}

/*****************
 * PacketFilter
 *****************/
resource "sakuracloud_packet_filter" "pf_db" {
    name = "${format("pf_%s_db" , var.zone)}"
    zone = "${var.zone}"
    expressions = {
        protocol = "tcp"
        source_nw = "0.0.0.0/0"
        dest_port = "22"
        description = "Allow SSH"
        allow = true
    }
    expressions = {
        protocol = "tcp"
        source_nw = "0.0.0.0/0"
        dest_port = "32768-61000"
        description = "Allow return packet(tcp)"
        allow = true
    }
    expressions = {
        protocol = "udp"
        source_nw = "0.0.0.0/0"
        dest_port = "32768-61000"
        description = "Allow return packet(udp)"
        allow = true
    }
    expressions = {
        protocol = "icmp"
        source_nw = "0.0.0.0"
        allow = true
        description = "Allow all icmp"
    }
    expressions = {
        protocol = "fragment"
        source_nw = "0.0.0.0"
        allow = true
        description = "Allow all fragment"
    }
    expressions = {
        protocol = "ip"
        source_nw = "0.0.0.0"
        allow = false
        description = "Deny all"
    }
}


output "ids"{
    value = "${join("," ,sakuracloud_server.server.*.id)}"
}
output "ip_addresses" {
    value = "${join("," ,sakuracloud_server.server.*.base_nw_ipaddress)}"
}
output "names" {
    value = "${join("," , sakuracloud_server.server.*.base_nw_ipaddress)}"
}
output "ssh_commands" {
    value = "${join("," , formatlist("ssh root@%s -i %s/%s" , sakuracloud_server.server.*.base_nw_ipaddress , path.root , var.ssh_keyfile))}"
}
