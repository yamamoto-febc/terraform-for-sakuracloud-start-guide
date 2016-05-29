/*****************
 * Variables
 *****************/
variable "ssh_key_id" {}
variable "ssh_keyfile"{ default = "id_rsa" }
variable "zone" { default = "is1a" }
variable "switch_id" {}
variable "servers" {}
variable "private_ip_addresses" {}
variable "name_suffix" { default = "web" }
variable "db01_ip" {}
variable "db02_ip" {}

/*****************
 * Disk
 *****************/
resource "sakuracloud_disk" "disk" {
    name = "${format("disk_%s_%s_%02d" , "${var.zone}" ,  "${var.name_suffix}" , count.index+1)}"
    source_archive_name = "CentOS 7.2 64bit"
    ssh_key_ids = ["${var.ssh_key_id}"]
    disable_pw_auth = true
    count = "${var.servers}"
    zone = "${var.zone}"
}
/*****************
 * Server 
 *****************/
resource "sakuracloud_server" "server" {
    name = "${format("server_%s_%s_%02d" , "${var.zone}" , "${var.name_suffix}" , count.index+1)}"
    disks = ["${element(sakuracloud_disk.disk.*.id,count.index)}"]
    additional_interfaces = ["${var.switch_id}"]
    packet_filter_ids = ["${sakuracloud_packet_filter.pf_web.id}"]
    tags = ["@virtio-net-pci"]
    count = "${var.servers}"
    zone = "${var.zone}"
    # サーバーにはSSHで接続
    connection {
        user = "root"
        host = "${self.base_nw_ipaddress}"
        private_key = "${file("${path.root}/${var.ssh_keyfile}")}"
    }

    # yumでapache+PHPのインストール
    provisioner "remote-exec" {
        inline = [
          "yum install -y httpd httpd-devel php php-mbstring php-mysqlnd php-pecl-mysqlnd-ms",
          "systemctl restart httpd.service",
          "systemctl enable httpd.service",
          "systemctl stop firewalld.service",
          "systemctl disable firewalld.service"
        ]
    }

    # Webコンテンツをアップロード
    provisioner "file" {
        source = "${path.root}/webapps/"
        destination = "/var/www/html"
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

    # mysqlnd_ms設定
    provisioner "file" {
        source = "${path.module}/mysqlnd_ms.ini"
        destination = "/etc/php.d/mysqlnd_ms.ini"
    }
    provisioner "remote-exec" {
        inline = [
            "cat << EOF > /etc/mysqlnd_ms.json \n ${template_file.mysqlnd_ms_json.rendered}\nEOF\n",
            "systemctl restart httpd.service"
        ]
    }
}

resource "template_file" "mysqlnd_ms_json" {
    template = "${file("${path.module}/mysqlnd_ms.json")}"
    vars {
        server01_ip = "${var.db01_ip}"
        server02_ip = "${var.db02_ip}"
    }
}

/*****************
 * PacketFilter
 *****************/
resource "sakuracloud_packet_filter" "pf_web" {
    name = "${format("pf_%s_web" , var.zone)}"
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
        dest_port = "80"
        description = "Allow www"
        allow = true
    }
    expressions = {
        protocol = "tcp"
        source_nw = "0.0.0.0/0"
        dest_port = "443"
        description = "Allow www(ssl)"
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
