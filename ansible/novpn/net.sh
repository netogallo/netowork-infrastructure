#!/bin/sh

NET_PHY=wlp6s0
NET_VPN=tun0
INF="$1" # your current interface name such as eth0, wlp4s0 and so on
STA="$2" # status such as UP or DOWN

echo "$INF is $STA" >> /tmp/network2

if [ "$INF" == "$NET_VPN" ] && [ "$STA" == "up" ];
then
    NOVPN=novpn2
    GW_CMD="ip route  | sed -nE 's|default via (([0-9]\|\.)+) dev $NET_PHY.*$|\1|p'"
    GW=`sh -c "$GW_CMD"`
    IP_PHY_CMD="ip route | sed -nE 's|^.*wlp6s0(([a-z]\|\s)+)(([0-9]\|\.)+) metric.*$|\3|p'"
    IP_PHY=`sh -c "$IP_PHY_CMD"`
    RT_TABLE_CMD="cat /etc/iproute2/rt_tables | grep $NOVPN"
    RT_TABLE=`sh -c "$RT_TABLE_CMD"`

    if [ "" == "$RT_TABLE" ];
    then
        echo "200 $NOVPN" >> /etc/iproute2/rt_tables
    fi

    IP_ROUTE_CMD="ip route list table $NOVPN | grep Error"
    IP_ROUTE=`sh -c "$IP_ROUTE_CMD"`

    if [ "" == "$IP_ROUTE" ];
    then
        ip route add default via $GW dev $NET_PHY table $NOVPN
    fi

    ip rule add fwmark 0x2 table $NOVPN
    iptables -m cgroup -A OUTPUT --path "/$NOVPN.slice/" -t mangle -o $NET_VPN -p tcp -j MARK --set-mark 2
    iptables -A POSTROUTING -t nat -o $NET_PHY -p tcp -j SNAT --to $IP_PHY
    #systemd-run --uid=neto -E DISPLAY=:2 --slice=$NOVPN firefox
fi