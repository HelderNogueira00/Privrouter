#!/bin/bash
#scripted by HelderNogueira

function get_val() {

    conf_file="$1";
    conf_param="$2";

    if [ "${conf_file}" == "" ] || [ "${conf_param}" == "" ]; then 

        echo "invalid arguments for get_val function";
        return;
    fi

    conf_value="$(grep "^${conf_param}" ${conf_file} | cut -d '=' -f2)";
    echo "${conf_value}";
}

ROUTING_TABLES='/etc/iproute2/rt_tables';
PRIVROUTER_DIR='/etc/privrouter';

LAN_CONF="${PRIVROUTER_DIR}/conf/main/lan.conf";
MAIN_CONF="${PRIVROUTER_DIR}/conf/main/main.conf";

TEMP_DIR='/tmp/privrouter/';
SEQUENCE_LOG='/tmp/privrouter/seq.log';
TEMP_LOCAL_DIR=''

TUNNELS_CONF="${PRIVROUTER_DIR}/conf/tunnels/";
CIRCUITS_CONF="${PRIVROUTER_DIR}/conf/circuits/";
PROFILES_CONF="${PRIVROUTER_DIR}/conf/profiles/";
RULESETS_CONF="${PRIVROUTER_DIR}/conf/rulesets/";
NETWORKS_CONF="${PRIVROUTER_DIR}/conf/networks/";
GATEWAYS_CONF="${PRIVROUTER_DIR}/conf/gateways/";

#Load main configuration
LAN_CIDR="$(get_val ${LAN_CONF} 'cidr')";
LAN_ADDR="$(echo $LAN_CIDR | cut -d '/' -f1)";
LAN_IFNAME="$(get_val ${LAN_CONF} 'ifname')";
LAN_MANAGEMENTIP="$(get_val ${LAN_CONF} 'management_ip')";

MAIN_BOOTWAIT="$(get_val ${MAIN_CONF} 'net_wait')";
MAIN_VIRTUAL="$(get_val ${MAIN_CONF} 'net_virtual')";