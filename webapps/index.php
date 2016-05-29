<?php
    date_default_timezone_set('Asia/Tokyo');
    echo "Terraform for さくらのクラウド スタートガイド用デモ". "<br /><br />";
    echo "IPアドレス:" . $_SERVER[ 'SERVER_ADDR' ] . "<br />";
    echo "時刻：" . date("Y/m/d H:i:s"). "<br />";

    //DB接続してSQLで時刻取得
    $mysqli = new mysqli('demo', 'demo', 'demo_password');
    if ($mysqli->connect_error) {
        echo "fail on connect:".$mysqli->connect_error;
        exit();
    } 
    $mysqli->set_charset("utf8");
    $res = $mysqli->query("SELECT sysdate()");
    echo "DB時刻：" . $res->fetch_row()[0] . "<br />";
    $res->close();
    $mysqli->close();   
