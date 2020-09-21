#!/bin/bash


# Revoke and remove a peer (client) from the setup WireGuard interface.

# Copyright (c) 2020 Hamidreza Hosseinkhani (xei) under the terms of the MIT license.
# https://github.com/xei/wireguard-setup-scripts
# Some parts of this script are inspired from https://github.com/angristan/wireguard-install


function set_peer_name() {
	if [ $# -eq 0 ]
	then
		echo "Error: Please pass the peer's name as an argument!"
		echo "For example:"
		echo "sudo ./revoke-peer.sh client2"
		exit 1
	else
		PEER_NAME=$1
	fi
}

function check_root_priviledge() {
	if [ "${EUID}" -ne 0  ]
	then
		echo "Permission denied: Please run the script as root!"
		exit 1
	fi
}

function check_if_wireguard_is_setup() {
        if [[ ! -e /etc/wireguard/params ]]
	then
                echo "WireGuard is not setup on the machine as a VPN server!."
                exit 1
        fi
}

function retrieve_wireguard_params() {
	source /etc/wireguard/params
}

function unbind_peer_from_server() {
	if grep -Fxq "### Peer Name: ${PEER_NAME}" /etc/wireguard/${NIC_WG}.conf
	then
		sed -i "/^### Peer Name: ${PEER_NAME}\$/,/^$/d" /etc/wireguard/${NIC_WG}.conf
	else
		echo "There is no any peer with name \"${PEER_NAME}\" bound to \"${NIC_WG}\" WireGuard interface."
		echo "Please check it and try again!"
		exit 1
	fi
}

function restart_wireguard_service() {
	systemctl is-active --quiet "wg-quick@${NIC_WG}"
	WG_IS_RUNNING=$?
	if [[ ${WG_IS_RUNNING} -eq 0 ]]
	then
		systemctl restart "wg-quick@${NIC_WG}"
	fi
}

# TODO: find a better solution (without changing directory)
function remove_config_file() {
	#find /etc/wireguard/peers/ -type d -name "[0-9]-${PEER_NAME}" -delete

	WD=$(pwd)
	cd /etc/wireguard/peers/
	ls | grep -P "[0-9]-${PEER_NAME}" | xargs -d "\n" rm -rf
	cd ${WD}
}


function main() {
	set_peer_name $1
	check_root_priviledge
	check_if_wireguard_is_setup
	retrieve_wireguard_params
	unbind_peer_from_server
	restart_wireguard_service
	remove_config_file

	echo "Peer \"${PEER_NAME}\" revoked from \"${NIC_WG}\" WireGuard interface successfully."
	echo "Its config directory is also removed from /etc/wireguard/peers/"
	echo ""
}


main $1
