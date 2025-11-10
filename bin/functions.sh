#!/bin/bash
source vars.sh

function init() {

    #Kill all previous instances
    killall tor &>/dev/null
    killall dhclient &>/dev/null
    killall wpa_supplicant &>/dev/null

    #Clean temp dirs
    rm -rf 
}