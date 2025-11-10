#!/bin/bash
source /etc/privrouter/bin/vars.sh

function load_main() {

    #Kill all previous instances
    killall tor &>/dev/null
    killall dhclient &>/dev/null
    killall wpa_supplicant &>/dev/null

    #Clean temp dirs
    rm -rf "${PRIVROUTER_DIR}/tmp/*";

    #setup base iprules
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F

    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP

    iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

    iptables -A INPUT -p tcp -s ${LAN_MANAGEMENTIP} -d ${LAN_ADDR} --dport 22 -j ACCEPT 
    
    if [ ! -f "${ROUTING_TABLES}" ]; then mkdir -p '/etc/iproute2/'; fi
    cp "${PRIVROUTER_DIR}/baks/rt_tables" "${ROUTING_TABLES}";
    #delete active namespaces

    #Wait for rfkill to load
    if [ "${MAIN_BOOTWAIT}" != "" ] && [ "$(which rfkill)" != "" ]; then

	    while [ "$(ip -br a | grep ${MAIN_BOOTWAIT})" == "" ] || [ "$(rfkill | grep "${MAIN_BOOTWAIT}")" == "" ]; do sleep 4; done
	    rfkill unblock "${MAIN_BOOTWAIT}";
    fi

    #Setup virtual wifi interfaces
    if [ "${MAIN_VIRTUAL}" != "" ]; then

        echo "main virtual"
        NET_IFNAME=$(echo $MAIN_VIRTUAL | cut -d ':' -f2);
        NET_VIFNAME=$(echo $MAIN_VIRTUAL | cut -d ':' -f1);

        if [ "${NET_VIFNAME}" != "" ] && [ "${NET_IFNAME}" != "" ]; then 
            
            echo "ifnames ok"
            if [ "$(ip -br a | grep "${NET_IFNAME}")" != "" ]; then

                ok=$(iw dev ${NET_IFNAME} interface add $NET_VIFNAME type station);
                echo "VIRTUAL_OK=$ok" > /tmp/privrouter/actions.lst;
                sleep 0.1
            fi
        fi
    fi
    
    #setup lan interface
    if [ "$(ip -br a | grep "${LAN_IFNAME}")" == "" ]; then return; fi
    ip addr add ${LAN_CIDR} dev ${LAN_IFNAME}
    ip link set dev ${LAN_IFNAME} up
    sleep 0.1 

    #enable ssh for management ip and allow forwarding
    sed -i '/ListenAddress/d' '/etc/ssh/sshd_config';
    sed -i "1aListenAddress ${LAN_ADDR}" '/etc/ssh/sshd_config';
    systemctl stop sshd ssh &>/dev/null
    systemctl start sshd ssh &>/dev/null
    sysctl -w net.ipv4.ip_forward=1;
}



