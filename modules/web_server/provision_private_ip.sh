#!/bin/sh

# eth1のIP設定
cat << EOS >> /etc/sysconfig/network-scripts/ifcfg-eth1
BOOTPROTO=static
PREFIX0=24
DEVICE=eth1
IPADDR0=$1
ONBOOT=yes
EOS

#反映
ifdown eth1; ifup eth1