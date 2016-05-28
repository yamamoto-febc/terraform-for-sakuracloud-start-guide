provider "sakuracloud" {
    token = "先ほど取得した[ACCESS_TOKEN]"
    secret = "先ほど取得した[ACCESS_TOKEN_SECRET]"
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
}

resource "sakuracloud_ssh_key" "mykey" {
    name = "mykey"
    public_key = "${file("./id_rsa.pub")}"
}

output "global_ip" {
    value = "${join("\n" , formatlist("%s : %s" , sakuracloud_server.server.*.name , sakuracloud_server.server.*.base_nw_ipaddress))}"
}