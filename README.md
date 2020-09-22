# Setup WireGuard VPN and Pi-hole ad blocker like a piece of cake 🍰
Here you can find some useful shell scripts in order to setup WireGuard VPN server and Pi-hole network-wide ad blocker on a Linux server as easily as possible.

<p>&nbsp;</p>

## What is a VPN
A [VPN (Virtual private network)](https://en.wikipedia.org/wiki/Virtual_private_network) extends your private network (e.g. the LAN in your office) across a public network (usually the Internet) so that the remote or mobile users and branch offices can connect to the private network remotely through the Internet in a secure way and access to corporate applications and private resources such as IP cameras, fax machines, private servers, etc.

<p align="center">
  <img width="460" height="300" src="https://upload.wikimedia.org/wikipedia/commons/e/e8/VPN_overview-en.svg">
</p>

The major applications of VPNs are:
1. Remote access to corporate resources such as shared documents in a private network, printers, fax machines, IP cameras, private servers etc.
3. Encrypt your transfering data and make your internet surfing more secure in a public unsecure Internet connection. (e.g. WIFI connection in hotels)
4. Stay anonymous on the Internet.
5. Get around Internet censorship, [geo-blocking](https://en.wikipedia.org/wiki/Geo-blocking) and sanctions in some countries.

## WireGuard
There are a bunch of tunneling protocols in order to make a VPN. For example [PPTP](https://www.bgocloud.com/knowledgebase/32/mikrotik-chr-how-to-setup-pptp-vpn-server.html), [L2TP](https://blog.johannfenech.com/mikrotik-l2tp-ipsec-vpn-server/), [IKEv2/IPSec](https://nordvpn.com/blog/ikev2ipsec/), [OpenVPN](https://github.com/angristan/openvpn-install) and of course [WireGuard](https://www.wireguard.com/).

Among these all, WireGuard seems to be the most interesting. It is lite (about 4,000 lines of code), fast and secure. So in 2020, WireGuard was officially added to the Linux kernel 5.6 release (so also Android kernels) by Linus Torvalds.

<p align="center">
  <img width="460" height="300" src="https://cdn.shortpixel.ai/client/to_webp,q_glossy,ret_img,w_758/https://www.the-digital-life.com/wp-content/uploads/2020/04/image.png">
</p>

## Pi-hole
[Pi-hole](https://pi-hole.net) is a Linux network-level advertisement and Internet tracker blocking application which acts as a [DNS sinkhole](https://en.wikipedia.org/wiki/DNS_sinkhole), intended for use on a private network.

The application acts as a DNS server for a private network (replacing any pre-existing DNS server provided by another device or the ISP), with the ability to block advertisements and tracking domains for users' devices without installing any client-side software.

Because Pi-hole blocks domains at the network level, it is able to block advertisements, such as banner advertisements on a webpage, but it can also block advertisements in unconventional locations, such as on Android, iOS and smart TVs.

Using VPN services, Pi-Hole can block domains without using a DNS filter setup in a router. Any device that supports VPN can use Pi-Hole on a cellular network or a home network without a DNS server configured.

<p align="center">
  <img width="460" height="300" src="https://upload.wikimedia.org/wikipedia/commons/5/5e/Pi-hole_Screenshot.png">
</p>

<p>&nbsp;</p>

## Setup the server
Here you can follow the instructions step by step to setup a VPN/AdBlocker server using WireGuard and Pi-hole.
### Buy a linux server
WireGuard and Pi-hole are really lite softwares so that you can run them on a lite Linux instance with 1 vCore and 1GB of RAM without any problem.

The scripts are tested on Ubuntu 20.04 but you can run them on Debian, Fedora, CentOS and Arch Linux.


You can buy a cheap Linux IaaS from these cloud providers for the VPN server:
Cloud Provider | Location | Price (starting at) | Traffic |
|--|--|--|--|
Vultr | Worldwide (USA is recommended because of sanctions!) | $3.50/month | - |
Digital Ocean | Worldwide (USA is recommended because of sanctions!) | $5/month | -
Hetzner | Germany (Finland did not work as VPN server for me!) | €3/month | 20 TB |

### Clone the repository
Run the following commands to download the scripts:
```
wget -O - https://github.com/xei/wireguard-setup-scripts/archive/master.tar.gz | tar xz
cd wireguard-setup-scripts-master
```

### Setup WireGuard server
Run the following command to setup the WireGuard server:
```
sudo ./setup-wireguard-server.sh
```
You have to answer some questions in order to configure the server. However you can leave the default values.
```
Enter a private IPv4 for WireGuard server: 10.0.0.1
Enter a private IPv6 for WireGuard server: fd42:42:42::1
Enter a port [1-65535] for WireGuard to listen: 51820
Enter a name for WireGuard network interface: wg0
```

When you see the message `WireGuard is setup successfully.` you can go on.

### Setup Pi-hole DNS sinkhole
Run the following command to start Pi-hole installer:
```
sudo ./setup-pihole.sh
```
For more information about installer wizard vistit the [official documentation](https://docs.pi-hole.net).

### Create a new peer (client)
Run the following command to create a new client (here named `xei-pc`):
```
sudo ./create-new-peer.sh xei-mobile
```
This command will generate a QR code that can be scanned by Wireguard client mobile application. It also generate a config file in `/etc/wireguard/peers/xei-mobile/` directory that can be used instead of the QR code.

Note that you can not connect to the VPN as one client with more than one devices at the same time. You have to create different clients for different devices. for example `xei-pc` and `xei-mobile`.

> You have to modify the client's config file and change `DNS` section to something like `1.1.1.1` or `8.8.8.8` if you are not going to setup `Pi-hole` or other DNS servers.

### Revoke a peer (client)
You can remove a client by running the following command:
```
sudo ./revoke-peer.sh xei-mobile
```
`xei-mobile` is the name of the client you want to remove.

### Remove WireGuard server
You can remove the WireGuard server completely by running the following command:
```
sudo ./remove-wireguard-server.sh
```
Note that the above script will remove the directory `/etc/wireguard` and its contents including all peers' config files. Backup the direcory if it is necessary.

Note that the above script will not remove Pi-hole. In order to remove Pi-hole visit its [official documentation](https://docs.pi-hole.net).

### WireGuard client applications
When you create a new peer (client) with the above command, a config file will be generated in `/etc/wireguard/peers/client-name/` directory that should be imported to WireGuard client application.

WireGuard client application is available in almost all platforms:

[Download WireGuard client application for Windows](https://download.wireguard.com/windows-client/wireguard-amd64-0.1.1.msi)

[Download WireGuard client application for macOS](https://itunes.apple.com/us/app/wireguard/id1451685025?ls=1&mt=12)

[Download WireGuard client application for Linux](https://www.wireguard.com/install)

[Download WireGuard client application for Android](https://play.google.com/store/apps/details?id=com.wireguard.android)

[Download WireGuard client application for iOS](https://itunes.apple.com/us/app/wireguard/id1441195209?ls=1&mt=8)

<p>&nbsp;</p>

## Inspiration
This repository is heavily inspired by a great similar repository by [angristan](https://github.com/angristan/wireguard-install).

## Donation
Give a ⭐ if this project helped you!
