provider "sakuracloud" {
    token = "先ほど取得した[ACCESS_TOKEN]"
    secret = "先ほど取得した[ACCESS_TOKEN_SECRET]"
}

resource "sakuracloud_disk" "disk"{
    name = "disk01"
    source_archive_name = "CentOS 7.2 64bit"
    # 任意のパスワードを設定してください。
    password = "YourPassword"
}

resource "sakuracloud_server" "server" {
    name = "server01"
    disks = ["${sakuracloud_disk.disk.id}"]    
}
