#!/bin/bash


# Create and bind a new peer (client) to the setup WireGuard interface.

# Copyright (c) 2020 Hamidreza Hosseinkhani (xei) under the terms of the MIT license.
# https://github.com/xei/wireguard-setup-scripts
# Some parts of this script are inspired from https://github.com/angristan/wireguard-install


function check_root_priviledge() {
	if [ "${EUID}" -ne 0  ]; then
		echo "Permission denied: Please run the script as root!"
		exit 1
	fi
}

function check_if_wireguard_is_setup() {
        if [[ ! -e /etc/wireguard/params ]]; then
                echo "WireGuard is not setup on the machine as a VPN server!."
		echo "Please run \"sudo ./setup-wireguard-server.sh\" at first."
                exit 1
        fi
}

function retrieve_peer_id() {
	if [[ -e /etc/wireguard/last-peer-id ]]; then
                source /etc/wireguard/last-peer-id
                ((PEER_ID=PEER_ID+1))
        else
                PEER_ID=2 # 2-254 , 1 is reserved for the server
        fi
}

function retrieve_wireguard_params() {
	source /etc/wireguard/params

	SUBNET_V4="${SERVER_PRIVATE_IPV4::-1}"
        SUBNET_V6="${SERVER_PRIVATE_IPV6::-1}"

        IPV4="${SUBNET_V4}${PEER_ID}"
        IPV6="${SUBNET_V6}${PEER_ID}"

	DNS=${SERVER_PRIVATE_IPV4}
}

function generate_keys() {
        PRIVATE_KEY=$(wg genkey)
        PUBLIC_KEY=$(echo "${PRIVATE_KEY}" | wg pubkey)
        PRESHARED_KEY=$(wg genpsk)
}

function ask_for_peer_name() {
	until [[ ${PEER_NAME} =~ ^[a-zA-Z0-9_]+$ ]]; do
		read -rp "Enter a name for WireGuard peer (client): " -e -i peer${PEER_ID} PEER_NAME
	done
}

function create_config_file() {
	mkdir -p /etc/wireguard/peers/${PEER_ID}-${PEER_NAME}

	echo "[Interface]
PrivateKey = ${PRIVATE_KEY}
Address = ${IPV4}/24, ${IPV6}/64
DNS = ${DNS}

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
PresharedKey = ${PRESHARED_KEY}
Endpoint = ${SERVER_PUBLIC_IPV4}:${SERVER_PORT}
AllowedIPs = 0.0.0.0/0" > "/etc/wireguard/peers/${PEER_ID}-${PEER_NAME}/${PEER_NAME}.conf"

	cat /etc/wireguard/peers/${PEER_ID}-${PEER_NAME}/${PEER_NAME}.conf | qrencode -o /etc/wireguard/peers/${PEER_ID}-${PEER_NAME}/${PEER_NAME}.png
}

function bind_peer_to_server() {
	echo "
[Peer]
# ${PEER_ID}-${PEER_NAME}
PublicKey = ${PUBLIC_KEY}
PresharedKey = ${PRESHARED_KEY}
AllowedIPs = ${IPV4}/24, ${IPV6}/64" >> "/etc/wireguard/${NIC_WG}.conf"

	systemctl restart wg-quick@${NIC_WG}
	wg show ${NIC_WG}
}

function update_last_peer_id_file() {
	echo "PEER_ID=${PEER_ID}" > "/etc/wireguard/last-peer-id"
}

function print_config_as_qr_code() {
        qrencode -t ansiutf8 <"/etc/wireguard/peers/${PEER_ID}-${PEER_NAME}/${PEER_NAME}.conf"
}


function main() {
	check_root_priviledge
	check_if_wireguard_is_setup
	retrieve_peer_id
	retrieve_wireguard_params
	generate_keys
	ask_for_peer_name
	create_config_file
	bind_peer_to_server
	update_last_peer_id_file

	echo "Peer \"${PEER_NAME}\" with ID: \"${PEER_ID}\" is bound to \"${NIC_WG}\" WireGuard interface successfully."
	echo "You can find the peer configuration file in \"/etc/wireguard/peers/${PEER_ID}-${PEER_NAME}/\""	
	echo "You can also scan the following QR code by WireGuard mobile application to establish a VPN tunnel easily."
	echo ""
	print_config_as_qr_code
}


main
