/*****************
 * Variables
 *****************/
variable "ssh_keyfile" { default = "id_rsa" }

variable "mysql_root_password" { default = "mysql_password" }
variable "mysql_user_name" { default = "demo" }
variable "mysql_user_password" { default = "demo_password" }

variable "mysql_server_ids" {}
variable "server01_ssh_ip" {}
variable "server02_ssh_ip" {}
variable "server01_private_ip" {}
variable "server02_private_ip" {}

resource "null_resource" "db_replication" {
    triggers{
        mysql_server_ids = "${var.mysql_server_ids}"
    }
 
    # MySQLレプリケーション開始
    provisioner "remote-exec" {
        connection {
            user = "root"
            host = "${var.server01_ssh_ip}"
            private_key = "${file("${path.root}/${var.ssh_keyfile}")}"
        }
        inline = [
            "cat << EOF | mysql -u root --password='${var.mysql_root_password}'\n${template_file.start_replication_sql01.rendered}\nEOF\n"
        ]
    }
    provisioner "remote-exec" {
        connection {
            user = "root"
            host = "${var.server02_ssh_ip}"
            private_key = "${file("${path.root}/${var.ssh_keyfile}")}"
        }
        inline = [
            "cat << EOF | mysql -u root --password='${var.mysql_root_password}'\n${template_file.start_replication_sql02.rendered}\nEOF\n"
        ]
    }
}

resource "template_file" "start_replication_sql01" {
    template = "${file("${path.module}/start_replication.sql")}"
    vars {
        master_ip = "${var.server01_private_ip}"
        user_name = "${var.mysql_user_name}"
        password = "${var.mysql_user_password}"
    }
}
resource "template_file" "start_replication_sql02" {
    template = "${file("${path.module}/start_replication.sql")}"
    vars {
        master_ip = "${var.server02_private_ip}"
        user_name = "${var.mysql_user_name}"
        password = "${var.mysql_user_password}"
    }
}

