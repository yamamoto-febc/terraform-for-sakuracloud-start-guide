/*********************
 * Provider settings
 *********************/
provider "sakuracloud" {
    token = "[ACCESS_TOKEN]"
    secret = "[ACCESS_TOKEN_SECRET]"
}

/*****************
 * Variables
 *****************/
variable "slack_webhook" {
    default = "https://hooks.slack.com/services/X0XXX0XXX/X0XXXXXXX/9XXXOxxxxO8XxxX4XX1xxxxx"
}
variable "mysql_values" {
    default = {
        root_password = "mysql_password"
        user_name = "demo"
        user_password = "demo_password"
        server_id_is1a = "201"
        server_id_tk1a = "202"
    }
}
variable "private_ip_addresses" {
    default = {
        is1a_web_servers_01 = "192.168.2.101"
        is1a_web_servers_02 = "192.168.2.102"
        tk1a_web_servers_01 = "192.168.2.111"
        tk1a_web_servers_02 = "192.168.2.112"
        is1a_db_server = "192.168.2.201"
        tk1a_db_server = "192.168.2.202"
    }
}
variable "ssh_keyfile" {
    default = {
        web = "id_rsa"
        db = "id_rsa_db"
    }
}
variable "dns_values" {
    default = {
        host_name = "web"
        domain = "fe-bc.net"
    }
}

/*****************
 * is1a resources
 *****************/
module "is1a_web_servers" {
    source = "./modules/web_server"
    zone = "is1a"
    # ssh
    ssh_key_id = "${sakuracloud_ssh_key.mykey.id}"
    ssh_keyfile = "${var.ssh_keyfile.web}"

    # switch
    switch_id = "${sakuracloud_switch.sw_is1a.id}"

    # ip_addresses
    private_ip_addresses = "${var.private_ip_addresses.is1a_web_servers_01},${var.private_ip_addresses.is1a_web_servers_02}"

    db01_ip = "${var.private_ip_addresses.is1a_db_server}"
    db02_ip = "${var.private_ip_addresses.tk1a_db_server}"

    # count
    servers = 2
}
module "is1a_db_server" {
    source = "./modules/db_server"
    zone = "is1a"
    # ssh
    ssh_key_id = "${sakuracloud_ssh_key.dbkey.id}"
    ssh_keyfile = "${var.ssh_keyfile.db}"

    # switch
    switch_id = "${sakuracloud_switch.sw_is1a.id}"

    # ip_addresses
    private_ip_addresses = "${var.private_ip_addresses.is1a_db_server}"

    # mysql_values
    mysql_root_password = "${var.mysql_values.root_password}"
    mysql_user_name = "${var.mysql_values.user_name}"
    mysql_user_password = "${var.mysql_values.user_password}"
    mysql_server_id = "${var.mysql_values.server_id_is1a}"
}
resource "sakuracloud_switch" "sw_is1a" {
    name = "sw_is1a"
    zone = "is1a"
    bridge_id = "${sakuracloud_bridge.br01.id}"
}

/*****************
 * tk1a resources
 *****************/
module "tk1a_web_servers" {
    source = "./modules/web_server"
    zone = "tk1a"
    # ssh
    ssh_key_id = "${sakuracloud_ssh_key.mykey.id}"
    ssh_keyfile = "${var.ssh_keyfile.web}"

    # switch
    switch_id = "${sakuracloud_switch.sw_tk1a.id}"

    # ip_addresses
    private_ip_addresses = "${var.private_ip_addresses.tk1a_web_servers_01},${var.private_ip_addresses.tk1a_web_servers_02}"

    db01_ip = "${var.private_ip_addresses.is1a_db_server}"
    db02_ip = "${var.private_ip_addresses.tk1a_db_server}"

    # count
    servers = 2
}
module "tk1a_db_server" {
    source = "./modules/db_server"
    zone = "tk1a"
    # ssh
    ssh_key_id = "${sakuracloud_ssh_key.dbkey.id}"
    ssh_keyfile = "${var.ssh_keyfile.db}"

    # switch
    switch_id = "${sakuracloud_switch.sw_tk1a.id}"

    # ip_addresses
    private_ip_addresses = "${var.private_ip_addresses.tk1a_db_server}"

    # mysql_values
    mysql_root_password = "${var.mysql_values.root_password}"
    mysql_user_name = "${var.mysql_values.user_name}"
    mysql_user_password = "${var.mysql_values.user_password}"
    mysql_server_id = "${var.mysql_values.server_id_tk1a}"
}
resource "sakuracloud_switch" "sw_tk1a" {
    name = "sw_tk1a"
    zone = "tk1a"
    bridge_id = "${sakuracloud_bridge.br01.id}"
}

/***************************************
 * MySQL Replication(by null_resource)
 ***************************************/
module "db_replication" {
    source = "./modules/db_replication"
    ssh_keyfile = "${var.ssh_keyfile.db}"

    # mysql_values
    mysql_root_password = "${var.mysql_values.root_password}"
    mysql_user_name = "${var.mysql_values.user_name}"
    mysql_user_password = "${var.mysql_values.user_name}"

    # replication target servers
    mysql_server_ids = "${element(split("," , module.is1a_db_server.ids),0)},${element(split("," , module.tk1a_db_server.ids),0)}"

    server01_ssh_ip = "${element(split("," , module.is1a_db_server.ip_addresses),0)}"
    server02_ssh_ip = "${element(split("," , module.tk1a_db_server.ip_addresses),0)}"

    server01_private_ip = "${var.private_ip_addresses.is1a_db_server}"
    server02_private_ip = "${var.private_ip_addresses.tk1a_db_server}"
}

/*****************
 * Bridge
 *****************/
resource "sakuracloud_bridge" "br01"{
    name = "br01"
}

/*****************
 * SSH key
 *****************/
resource "sakuracloud_ssh_key" "mykey" {
    name = "mykey"
    public_key = "${file("${path.root}/${var.ssh_keyfile.web}.pub")}"
}

resource "sakuracloud_ssh_key" "dbkey" {
    name = "dbkey"
    public_key = "${file("${path.root}/${var.ssh_keyfile.db}.pub")}"
}

/*****************
 * SimpleMonitor
 *****************/
# ping監視(DBサーバー)
resource "sakuracloud_simple_monitor" "ping_monitor_db" {
    count = 2
    target = "${element(concat(split(",",module.is1a_db_server.ip_addresses),split("," , module.tk1a_db_server.ip_addresses)) , count.index)}"
    health_check = {
        protocol = "ping"
        delay_loop = 60
    }
    notify_email_enabled = false
    notify_slack_enabled = true
    notify_slack_webhook = "${var.slack_webhook}"
}

# ping監視(webサーバー4台分)
resource "sakuracloud_simple_monitor" "ping_monitor_web" {
    count = 4
    target = "${element(concat(split(",",module.is1a_web_servers.ip_addresses),split("," , module.tk1a_web_servers.ip_addresses)) , count.index)}"
    health_check = {
        protocol = "ping"
        delay_loop = 60
    }
    notify_email_enabled = false
    notify_slack_enabled = true
    notify_slack_webhook = "${var.slack_webhook}"
}
# web監視(webサーバー4台分)
resource "sakuracloud_simple_monitor" "http_monitor_web" {
    count = 4
    target = "${element(concat(split(",",module.is1a_web_servers.ip_addresses),split("," , module.tk1a_web_servers.ip_addresses)) , count.index)}"
    health_check = {
        protocol = "http"
        delay_loop = 60
        path = "/index.php"
        status = "200"
    }
    notify_email_enabled = false
    notify_slack_enabled = true
    notify_slack_webhook = "${var.slack_webhook}"
}

/*****************
 * GSLB
 *****************/
resource "sakuracloud_gslb" "gslb" {
    name = "gslb01"
    health_check = {
        protocol = "http"
        delay_loop = 10
        host_header = "${var.dns_values.host_name}.${var.dns_values.domain}"
        path = "/index.php"
        status = "200"
    }
    servers = {
        ipaddress = "${element(split("," , module.is1a_web_servers.ip_addresses),0)}"
    }
    servers = {
        ipaddress = "${element(split("," , module.is1a_web_servers.ip_addresses),1)}"
    }
    servers = {
        ipaddress = "${element(split("," , module.tk1a_web_servers.ip_addresses),0)}"
    }
    servers = {
        ipaddress = "${element(split("," , module.tk1a_web_servers.ip_addresses),1)}"
    }
}

/*****************
 * DNS
 *****************/
resource "sakuracloud_dns" "dns" {
    zone = "${var.dns_values.domain}"
    records = {
        name = "${var.dns_values.host_name}"
        type = "CNAME"
        value = "${sakuracloud_gslb.gslb.FQDN}."
    }
}

/*****************
 * Output
 *****************/
output "ssh_is1a_web01" {
    value = "${element(split("," , module.is1a_web_servers.ssh_commands),0)}"
}
output "ssh_is1a_web02" {
    value = "${element(split("," , module.is1a_web_servers.ssh_commands),1)}"
}
output "ssh_is1a_db" {
    value = "${element(split("," , module.is1a_db_server.ssh_commands),0)}"
}
output "ssh_tk1a_web01" {
    value = "${element(split("," , module.tk1a_web_servers.ssh_commands),0)}"
}
output "ssh_tk1a_web02" {
    value = "${element(split("," , module.tk1a_web_servers.ssh_commands),1)}"
}
output "ssh_tk1a_db" {
    value = "${element(split("," , module.tk1a_db_server.ssh_commands),0)}"
}
