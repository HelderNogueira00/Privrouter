#!/bin/bash
source /etc/privrouter/bin/functions.sh

mkdir '/tmp/privrouter'
load_main &>/tmp/privrouter/init.log
