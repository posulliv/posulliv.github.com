--- 
wordpress_id: 31
layout: post
title: Installing &amp; Configuring a USB NIC on Solaris
category: solaris
---
In this post, I will provide a very quick overview of how to install and configure a USB network interface on Solaris.

<span style="font-size:130%;"><span style="font-weight: bold;">Obtaining the USB Driver</span></span>

The driver for a generic USB network interface which should cover the majority of USB NIC devices can be downloaded from <a href="http://homepage2.nifty.com/mrym3/taiyodo/upf-0.8.0.tar.gz">here</a>.

<span style="font-size:130%;"><span style="font-weight: bold;">Installing the USB Driver</span></span>

After downloading the driver, uncompress the gunzipped file and extract the archive as the root user.

<span style="font-size:85%;"><span style="font-family: courier new;"># gunzip upf-0.8.0.tar.gz ; tar xvf upf-0.8.0.tar</span></span>

This will create a <span style="font-size:85%;"><span style="font-family: courier new;">upf-0.8.0</span></span> directory in the current directory. Change to the <span style="font-size:85%;"><span style="font-family: courier new;">upf-0.8.0</span></span> directory. Now we need to perform the following to install the driver:

<span style="font-size: 85%; font-family: courier new;"># make install
# ./adddrv.sh</span>

After this has been completed, the driver has been installed but the system needs to be rebooted before we can use the new driver. Reboot the system using the following procedure:

<span style="font-size:85%;"><span style="font-family: courier new;"># touch /reconfigure</span>
<span style="font-family: courier new;"> # shutdown -i 0 -g0 y</span></span>

This will scan for new hardware on reboot. The new NIC device will show up as <span style="font-size:85%;"><span style="font-family: courier new;">/dev/upf0</span></span>

<span style="font-size:130%;"><span style="font-weight: bold;">Configuring the NIC Device</span></span>

Once the USB driver has been installed and the system has been rebooted correctly, the NIC device can be configured as follows. (In this example, we will just make up an IP address to use).

<span style="font-size:85%;"><span style="font-family: courier new;"># ifconfig upf0 plumb</span>
<span style="font-family: courier new;"> # ifconfig upf0 192.168.2.111 netmask 255.255.255.0 up</span></span>

<span style="font-size:130%;"><span style="font-weight: bold;">Making Sure the NIC Device Starts on Boot</span></span>

To ensure that the new NIC device starts automatically on boot, we need to create a <span style="font-size:85%;"><span style="font-family: courier new;">/etc/hostname</span></span> file for that interface containing either the IP address configured for that interface of if we placed the IP address in the <span style="font-size:85%;"><span style="font-family: courier new;">/etc/inet/hosts</span></span> file, then the hostname for that interface.
