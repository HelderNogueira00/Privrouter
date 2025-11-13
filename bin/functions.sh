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

        NET_IFNAME=$(echo $MAIN_VIRTUAL | cut -d ':' -f2);
        NET_VIFNAME=$(echo $MAIN_VIRTUAL | cut -d ':' -f1);

        if [ "${NET_VIFNAME}" != "" ] && [ "${NET_IFNAME}" != "" ]; then 
            
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

function init_gateway {

    gw="${1}";
    gw_name="${2}";

    if [ "$(grep "${gw_name}" "${SEQUENCE_LOG}")" == "" ]; then
    
        #grab conf information
        gw_ifname=$(get_val ${gw} 'ifname');
        gw_timeout=$(get_val ${gw} 'timeout');
        gw_usedhcp=$(get_val ${gw} 'use_dhcp');
        gw_conntype=$(get_val ${gw} 'wireless');
        gw_cidr=$(get_val ${gw} 'cidr');
        gw_upst=$(get_val ${gw} 'upst');
        gw_ssid=$(get_val ${gw} 'ssid');
        gw_pass=$(get_val ${gw} 'pass');

        #parse vars
        gw_addr="$(ipcalc "${gw_cidr}" | grep 'Address' | awk '{print $2}')";
        gw_mask="$(ipcalc "${gw_cidr}" | grep 'Network' | awk '{print $2}')";

        #check if network interface exists
        if [ "$(ip -br a | grep -a "${gw_ifname}")" == "" ]; then 
            
            echo "Gateway Interface Not Found: ${gw_ifname}";
            return;
        fi 

        #clean current gateway ip configuration
        ip addr flush ${gw_ifname};
        ip link set dev ${gw_ifname} down;
        sleep 0.1

        #wifi type configuration
        if [ "${gw_conntype}" == "wireless" ]; then
        
            wifi_timeout=0
            psk_file=/tmp/privrouter/${gw_ifname}.psk;
            echo "country=PT" | tee ${psk_file}
		    echo "p2p_disabled=1" | tee -a ${psk_file}
		    echo "update_config=0" | tee -a ${psk_file}
		    echo "disable_scan_offload=1" | tee -a ${psk_file}
		    wpa_passphrase "${net_ssid}" "${net_pass}" | tee -a ${psk_file}
		    sed -i '/\#psk=.*/d' ${psk_file}
		    wpa_supplicant -i ${gw_ifname} -c ${psk_file} &>${TEMP_DIR}${gw_ifname}.supplicant &

            while [ "$(grep 'CONNECTED' "${TEMP_DIR}${gw_ifname}.supplicant")" == "" ] && [ $timeout -le $gw_timeout ]; do timeout=$((timeout+1));sleep 2; done
		    if [ $timeout -ge $gw_timeout ]; then echo "Gateway Wifi Connection Timed out: ${gw_ifname}"; break; fi
        fi

        #get dhcp ip conf 
        if [ "${gw_usedhcp}" == "yes" ]; then 

            dhclient -1 -v -sf /bin/true -lf ${TEMP_DIR}${gw_ifname}.leases ${gw_ifname}
		    gw_addr="$(grep 'fixed-address' ${TEMP_DIR}${gw_ifname}.leases | awk '{ print $2 }' | head -n1 | tr -d ';')/24";
		    gw_upst="$(grep 'routers' ${TEMP_DIR}${gw_ifname}.leases | awk '{ print $3 }' | head -n1 | tr -d ';')";
		    gw_mask="$(echo $gw_upst | sed 's/\.254/.0\/24/g')";
        fi

        #apply ip conf to interface
        ip link set dev ${gw_ifname} up
        ip addr add ${gw_cidr} dev ${gw_ifname}
        sleep 0.1

        #create routing table for this gateway
        echo -e "${gw_id}240\t${gw_ifname}gw" | sudo tee -a ${ROUTING_TABLES} &>/dev/null
	    ip route add $gw_mask dev $gw_ifname table ${gw_ifname}gw
	    ip route add default via $gw_upst dev $gw_ifname table ${gw_ifname}gw

    fi
}


function init_tunnel {


}

function init_network {


}

function apply_ruleset {


}

function apply_profile {


}

function init_circuit {

    for circuit in "${CIRCUITS_CONF}*.conf"; do
    
        circuit_name="$(echo $circuit | awk -F '/' '{print $NF}')";
        circuit_enabled=$(get_val ${circuit} 'enabled');
        if [ "${circuit_enabled}" != "yes" ]; then continue; fi
        
        circuit_timout=$(get_val ${circuit} 'timeout');
        circuit_maxretry=$(get_val ${circuit} 'max_retry');
        circuit_onerror=$(get_val ${circuit} 'on_error');
        circuit_gateway=$(get_val ${circuit} 'gateway');
        circuit_tunnel=$(get_val ${circuit} 'tunnel');
        circuit_network=$(get_val ${circuit} 'network');
        circuit_ruleset=$(get_val ${circuit} 'ruleset');

        #Find gateway and initialize it
        for gw in ${GATEWAYS_CONF}*.conf; do
            gateway_name=$(echo $gw | awk -F '/' '{ print $NF }' | cut -d '.' -f1);
            if [ "${circuit_gateway}" ==  "${gateway_name}"]; then init_gateway "${gw}" "${gateway_name}"; break; fi
        done

        #Find tunnel and initialize it
        for tun in ${TUNNELS_CONF}*.conf; do
            tunnel_name=$(echo $tun | awk -F '/' '{ print $NF }' | cut -d '.' -f1);
            if [ "${circuit_tunnel}" ==  "${tunnel_name}"]; then init_tunnel "${tun}" "${tunnel_name}"; break; fi
        done

        #Find network and initialize it
        for net in ${NETWORKS_CONF}*.conf; do
            network_name=$(echo $net | awk -F '/' '{ print $NF }' | cut -d '.' -f1);
            if [ "${circuit_network}" ==  "${network_name}"]; then init_network "${net}" "${network_name}"; break; fi
        done

        echo "[+] CIRCUIT => Initialization Sequence Completed";
    done
}

