#!/bin/bash
# Setup Pi-hole DNS sinkhole (Network-wide ad blocker) on a Linux server.

# Copyright (c) 2020 Hamidreza Hosseinkhani (xei) under the terms of the MIT license.
# https://github.com/xei/wireguard-setup-scripts

# For more information about installing Pi-hole please visit: https://github.com/pi-hole/pi-hole/#one-step-automated-install


function check_root_priviledge() {
	if [ "${EUID}" -ne 0  ]
  then
		echo "Permission denied: Please run the script as root!"
		exit 1
	fi
}

function run_pihole_installer() {
  curl -sSL https://install.pi-hole.net | bash
}

# TODO: UFW is just for Ubuntu. Find a general solution!
function set_firewall_rules() {
	ufw status | grep -qw active
	UFW_IS_ACTIVE=$?
	if [[ ${UFW_IS_ACTIVE} -eq 0 ]]
  then
		ufw allow 80/tcp
    ufw allow 53/tcp
    ufw allow 53/udp
    ufw allow 67/tcp
    ufw allow 67/udp
    ufw allow 546:547/udp
    
		ufw reload
	fi
}


function main() {
  check_root_priviledge
  run_pihole_installer
  set_firewall_rules
}


main
