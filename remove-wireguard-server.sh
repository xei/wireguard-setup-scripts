#!/bin/bash


# Remove Wireguard, its config files and peers that are setup by setup-wireguard-server.sh script on a Linux server.

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
                exit 1
        fi
}

function retrieve_wireguard_params() {
	source /etc/wireguard/params
}

function stop_wireguard_service() {
	systemctl stop "wg-quick@${NIC_WG}"
	systemctl disable "wg-quick@${NIC_WG}"

	# Check if WireGuard is still running
	systemctl is-active --quiet "wg-quick@${NIC_WG}"
	WG_IS_RUNNING=$?
	if [[ ${WG_IS_RUNNING} -eq 0 ]]; then
		echo "Stopping WireGuard service failed!"
		echo "Run the script again after killing the process!"
		exit 1
	fi
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

function remove_packages_from_ubuntu() {
	apt-get autoremove --purge -y wireguard qrencode
}

function remove_packages_from_debian() {
	apt-get autoremove --purge -y wireguard qrencode
}

function remove_packages_from_fedora() {
	dnf remove -y wireguard-tools qrencode
	dnf autoremove -y
}

function remove_packages_from_centos() {
	yum -y remove elrepo-release epel-release kmod-wireguard wireguard-tools qrencode
	rm -f "/etc/yum.repos.d/wireguard.repo"
	yum -y autoremove
}

function remove_packages_from_arch() {
	pacman -Rs --noconfirm wireguard-tools qrencode
}

function close_wireguard_port_in_ufw() {
	ufw status | grep -qw active
	UFW_IS_ACTIVE=$?
	if [[ ${UFW_IS_ACTIVE} -eq 0 ]]; then
		ufw delete allow ${SERVER_PORT}/udp
		ufw reload
	fi
}

function disable_ip_forwarding() {
	rm -f /etc/sysctl.d/wg.conf
        sysctl --system
}

function remove_config_dir() {
	rm -rf /etc/wireguard
}


function main() {
	check_root_priviledge
	check_if_wireguard_is_setup
	retrieve_wireguard_params
	stop_wireguard_service
	get_os_name
	if [[ ${OS} == 'ubuntu' ]]; then
		remove_packages_from_ubuntu
		close_wireguard_port_in_ufw
	elif [[ ${OS} == 'debian' ]]; then
		remove_packages_from_debian
	elif [[ ${OS} == 'fedora' ]]; then
		remove_packages_from_fedora
	elif [[ ${OS} == 'centos' ]]; then
		remove_packages_from_centos
	elif [[ ${OS} == 'arch' ]]; then
		remove_packages_from_arch
	elif [[ ${OS} == 'unknown' ]]; then
		echo "OS not supported: The installer script (so also this script) just supports Debian, Ubuntu, Fedora, CentOS or Arch Linux systems."
                exit 1
	fi
	disable_ip_forwarding
	remove_config_dir

	echo ""
	echo "WireGuard, its config files and peers all removed successfully."
	echo "This script did not do anything about Pi-hole ad blocker. If you want to remove it too, please visit its documentation."
}


main
