provider "sakuracloud" {
    token = "[ACCESS_TOKEN]"
    secret = "[ACCESS_TOKEN_SECRET]"
}

resource "sakuracloud_disk" "disk" {
    name = "${format("disk%02d" , count.index+1)}"
    source_archive_name = "CentOS 7.2 64bit"
    ssh_key_ids = ["${sakuracloud_ssh_key.mykey.id}"]
    disable_pw_auth = true
    count = 2
}

resource "sakuracloud_server" "server" {
    name = "${format("server%02d" , count.index+1)}"
    disks = ["${element(sakuracloud_disk.disk.*.id,count.index)}"]
    count = 2
    # 1: サーバーにはSSHで接続
    connection {
        user = "root"
        host = "${self.base_nw_ipaddress}"
        private_key = "${file("./id_rsa")}"
    }

    # ２： yumでapache+PHPのインストール
    provisioner "remote-exec" {
        inline = [
            "yum install -y httpd httpd-devel php php-mbstring",
            "systemctl restart httpd.service",
            "systemctl enable httpd.service",
            "systemctl stop firewalld.service",
            "systemctl disable firewalld.service"
        ]
    }

    # 3: Webコンテンツをアップロード
    provisioner "file" {
        source = "webapps/"
        destination = "/var/www/html"
    }

}

resource "sakuracloud_ssh_key" "mykey" {
    name = "mykey"
    public_key = "${file("./id_rsa.pub")}"
}

resource "sakuracloud_dns" "dns" {
    zone = "fe-bc.net"
    records = {
        name = "web"
        type = "A"
        value = "${sakuracloud_server.server.0.base_nw_ipaddress}"
    }
    records = {
        name = "web"
        type = "A"
        value = "${sakuracloud_server.server.1.base_nw_ipaddress}"
    }
}

output "global_ip" {
    value = "${join("\n" , formatlist("%s : %s" , sakuracloud_server.server.*.name , sakuracloud_server.server.*.base_nw_ipaddress))}"
}