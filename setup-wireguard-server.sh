#!/bin/bash


# Setup Wireguard as a VPN server on a supported Linux distribution. (Debian, Ubuntu, CentOS, Fedora and Arch Linux)

# Copyright (c) 2020 Hamidreza Hosseinkhani (xei) under the terms of the MIT license.
# https://github.com/xei/wireguard-setup-scripts
# Some parts of this script are inspired from https://github.com/angristan/wireguard-install


function check_root_priviledge() {
	if [ "${EUID}" -ne 0  ]; then
		echo "Permission denied: Please run the script as root!"
		exit 1
	fi
}

function check_if_virtualization_is_supported() {
	virt=$(systemd-detect-virt)
	
	if [ $virt == "openvz" ]; then
		echo "Virtualization solution (OpenVZ) is not supported."
		exit 1
	fi

	if [ $virt == "lxc" ]; then
                echo "Virtualization solution (LXC) is not supported yet."
                exit 1
        fi
}

function check_if_wireguard_is_already_setup() {
        if [[ -e /etc/wireguard/params ]]; then
                echo "WireGuard is already setup on the machine as a VPN server!."
                exit 1
        fi
}

function ask_for_custom_server_params() {
        echo "Some custom parameters are needed to setup WireGuard VPN server."
        echo "You can leave the default options and just press Enter key."
        echo ""

        until [[ ${IPV4} =~ ^([0-9]{1,3}\.){3} ]]; do
                read -rp "Enter a private IPv4 for WireGuard server: " -e -i 10.0.0.1 IPV4
        done

        until [[ ${IPV6} =~ ^([a-f0-9]{1,4}:){3,4}: ]]; do
                read -rp "Enter a private IPv6 for WireGuard server: " -e -i fd42:42:42::1 IPV6
        done

        until [[ ${PORT} =~ ^[0-9]+$ ]] && [ "${PORT}" -ge 1 ] && [ "${PORT}" -le 65535 ]; do
                read -rp "Enter a port [1-65535] for WireGuard to listen: " -e -i 51820 PORT
        done

        until [[ ${NIC_WG} =~ ^[a-zA-Z0-9_]+$ ]]; do
                read -rp "Enter a name for WireGuard network interface: " -e -i wg0 NIC_WG
        done
	
	echo ""
}

function get_os_name() {
	if [[ -e /etc/debian_version ]]; then
		source /etc/os-release
		OS="${ID}" # debian or ubuntu
	elif [[ -e /etc/fedora-release ]]; then
		OS=fedora
	elif [[ -e /etc/centos-release ]]; then
		OS=centos
	elif [[ -e /etc/arch-release ]]; then
		OS=arch
	else
		OS=unknown
	fi
}

# Reference: https://www.wireguard.com/install/#ubuntu-module-tools
function install_packages_on_ubuntu() {
	apt update
	apt install -y wireguard qrencode
}

# Reference: https://www.wireguard.com/install/#debian-module-tools
function install_packages_on_debian() {
	apt update
	apt install -y wireguard iptables qrencode
}

# Reference: https://www.wireguard.com/install/#fedora-tools
function install_packages_on_fedora() {
	dnf install -y wireguard-tools iptables qrencode
}

# Reference: https://www.wireguard.com/install/#centos-8-module-plus-module-kmod-module-dkms-tools
function install_packages_on_centos() {
	sudo yum -y install elrepo-release epel-release
        sudo yum -y install kmod-wireguard wireguard-tools iptables qrencode
}

# Reference: https://www.wireguard.com/install/#arch-module-tools
function install_packages_on_arch() {
	pacman -S --noconfirm wireguard-tools iptables qrencode
}

function open_wireguard_port_in_ufw() {
	ufw allow OpenSSH
	ufw allow ${PORT}/udp
	
	ufw status | grep -qw active
	UFW_IS_ACTIVE=$?
	if [[ ${UFW_IS_ACTIVE} -eq 0 ]]; then
		ufw reload
	else
		ufw --force enable
	fi
}

function enable_ip_forwarding() {
        echo "net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1" >/etc/sysctl.d/wg.conf

        sysctl --system
}

function generate_keys() {
        PRIVATE_KEY=$(wg genkey)
        PUBLIC_KEY=$(echo "${PRIVATE_KEY}" | wg pubkey)
}

function create_config_file() {
	NIC_PUB="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"

	echo "[Interface]
Address = ${IPV4}/24, ${IPV6}/64
ListenPort = ${PORT}
PrivateKey = ${PRIVATE_KEY}" >"/etc/wireguard/${NIC_WG}.conf"

	if pgrep firewalld; then
		FIREWALLD_IPV4=$(echo "${IPV4}" | cut -d"." -f1-3)".0"
		FIREWALLD_IPV6=$(echo "${IPV6}" | sed 's/:[^:]*$/:0/')

		echo "PostUp = firewall-cmd --add-port ${PORT}/udp && firewall-cmd --add-rich-rule='rule family=ipv4 source address=${FIREWALLD_IPV4}/24 masquerade' && firewall-cmd --add-rich-rule='rule family=ipv6 source address=${FIREWALLD_IPV6}/24 masquerade'
PostDown = firewall-cmd --remove-port ${PORT}/udp && firewall-cmd --remove-rich-rule='rule family=ipv4 source address=${FIREWALLD_IPV4}/24 masquerade' && firewall-cmd --remove-rich-rule='rule family=ipv6 source address=${FIREWALLD_IPV6}/24 masquerade'" >>"/etc/wireguard/${NIC_WG}.conf"

	else
		echo "PostUp = iptables -A FORWARD -i ${NIC_WG} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${NIC_PUB} -j MASQUERADE; ip6tables -A FORWARD -i ${NIC_WG} -j ACCEPT; ip6tables -t nat -A POSTROUTING -o ${NIC_PUB} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${NIC_WG} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${NIC_PUB} -j MASQUERADE; ip6tables -D FORWARD -i ${NIC_WG} -j ACCEPT; ip6tables -t nat -D POSTROUTING -o ${NIC_PUB} -j MASQUERADE" >>"/etc/wireguard/${NIC_WG}.conf"

	fi
}

function start_wireguard_service() {
	systemctl start "wg-quick@${NIC_WG}"
	systemctl enable "wg-quick@${NIC_WG}"

	# Check if WireGuard is running
	systemctl is-active --quiet "wg-quick@${NIC_WG}"
	WG_IS_RUNNING=$?
	if [[ ${WG_IS_RUNNING} -eq 0 ]]; then
		wg show ${NIC_WG}
	else
		echo -e "\nWireGuard service is not running!"
		echo "Please run \"sudo systemctl status wg-quick@${NIC_WG}\" for more information."
		echo "If you get something like \"Cannot find device ${NIC_WG}\", please reboot the machine!"
		exit 1
	fi
}

function store_wireguard_params() {
	PUBLIC_IPV4==$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
	PUBLIC_IPV6=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)

	echo "NIC_WG=${NIC_WG}
SERVER_PRIVATE_IPV4=${IPV4}
SERVER_PRIVATE_IPV6=${IPV6}
SERVER_PUBLIC_IPV4=${PUBLIC_IPV4}
SERVER_PUBLIC_IPV6=${PUBLIC_IPV6}
SERVER_PORT=${PORT}
SERVER_PUBLIC_KEY=${PUBLIC_KEY}" >/etc/wireguard/params

	echo ""
	echo "WireGuard server params are stored in \"/etc/wireguard/params\" for future use."
	cat /etc/wireguard/params
	echo ""
}


function main() {
	check_root_priviledge
	check_if_virtualization_is_supported
	check_if_wireguard_is_already_setup
	ask_for_custom_server_params
	get_os_name
	if [[ ${OS} == 'ubuntu' ]]; then
		install_packages_on_ubuntu
		open_wireguard_port_in_ufw
	elif [[ ${OS} == 'debian' ]]; then
		install_packages_on_debian
	elif [[ ${OS} == 'fedora' ]]; then
		install_packages_on_fedora

		# Make sure the directory exists
        	mkdir /etc/wireguard >/dev/null 2>&1
        	chmod 600 -R /etc/wireguard/
	elif [[ ${OS} == 'centos' ]]; then
		install_packages_on_centos
	elif [[ ${OS} == 'arch' ]]; then
		install_packages_on_arch
	elif [[ ${OS} == 'unknown' ]]; then
		echo "OS not supported: Run the installer on a Debian, Ubuntu, Fedora, CentOS or Arch Linux system"
		echo "More information about installing WireGuard on different Linux distributions: https://www.wireguard.com/install"
                exit 1
	fi
	enable_ip_forwarding
	generate_keys
	create_config_file
	start_wireguard_service
	store_wireguard_params

	echo "WireGuard is setup successfully."
	echo "You can also setup Pi-hole ad blocker in your network by running \"sudo ./setup-pihole.sh\"."
	echo "Run \"sudo ./create-new-peer.sh\" to create and bind a new client."
}


main
