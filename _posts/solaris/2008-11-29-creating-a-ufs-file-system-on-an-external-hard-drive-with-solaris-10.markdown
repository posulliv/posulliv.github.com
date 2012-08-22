--- 
wordpress_id: 34
layout: post
title: Creating a UFS File System on an External Hard Drive with Solaris 10
category: solaris
---
Recently, I wanted to create a UFS file system on a Maxtor OneTouch II external hard drive I have. I wanted to use the external hard drive for storing some large files and I was going to use the drive exclusively with one of my Solaris systems. Now, I didn't find much information on the web about how to perform this with Solaris (maybe I wasn't searching very well or something) so I thought I would post the procedure I followed here so I'll know how to do it again if I need to.

After plugging the hard drive into my system via one of the USB ports, we can verify that the disk was recognized by the OS by examining the <code>/var/adm/messages</code> file. With the hard drive I was using, I saw entries like the following:

<pre>
Mar  2 13:10:33 solaris-filer usba: [ID 912658 kern.info] USB 2.0 device (usbd49,7100) 
operating at hi speed (USB 2.x) on USB 2.0 root hub: storage@3, scsa2usb0 at bus address 2
Mar  2 13:10:33 solaris-filer usba: [ID 349649 kern.info]       Maxtor OneTouch II L60LHYQG
Mar  2 13:10:33 solaris-filer genunix: [ID 936769 kern.info] scsa2usb0 is /pci@0,0/pci1028,11d@1d,7/storage@3
Mar  2 13:10:33 solaris-filer genunix: [ID 408114 kern.info] /pci@0,0/pci1028,11d@1d,7/storage@3 
(scsa2usb0) online
Mar  2 13:10:33 solaris-filer scsi: [ID 193665 kern.info] sd1 at scsa2usb0: target 0 lun 0
</pre>

The dmesg command could also be used to see similar information. Also, we could use the rmformat command (this lists removable media) to see this information in a much nicer format like so:

<pre>
# rmformat -l
Looking for devices...
   1. Logical Node: /dev/rdsk/c1t0d0p0
      Physical Node: /pci@0,0/pci-ide@1f,1/ide@1/sd@0,0
      Connected Device: QSI      CDRW/DVD SBW242U UD25
      Device Type: DVD Reader
   2. Logical Node: /dev/rdsk/c2t0d0p0
      Physical Node: /pci@0,0/pci1028,11d@1d,7/storage@3/disk@0,0
      Connected Device: Maxtor   OneTouch II      023g
      Device Type: Removable
#
</pre>

Now that we now the drive has been identified by Solaris (as <code>/dev/rdsk/c2t0d0p0</code>) we need to create one Solaris partition (this is Solaris 10 running on the x86 architecture) that uses the whole disk. This accomplished by passing the <code>-B</code> flag to the <code>fdisk</code> command, like so:

<pre>
# fdisk -B /dev/rdsk/c2t0d0p0
</pre>

Now we will print the disk table to standard out like so:

<pre>
# fdisk -W - /dev/rdsk/c2t0d0p0
</pre>

This will output the following information to the screen for the hard drive I am using:

<pre>
* /dev/rdsk/c2t0d0p0 default fdisk table
* Dimensions:
*    512 bytes/sector
*     63 sectors/track
*    255 tracks/cylinder
*   36483 cylinders
*
* systid:
*    1: DOSOS12
*    2: PCIXOS
*    4: DOSOS16
*    5: EXTDOS
*    6: DOSBIG
*    7: FDISK_IFS
*    8: FDISK_AIXBOOT
*    9: FDISK_AIXDATA
*   10: FDISK_0S2BOOT
*   11: FDISK_WINDOWS
*   12: FDISK_EXT_WIN
*   14: FDISK_FAT95
*   15: FDISK_EXTLBA
*   18: DIAGPART
*   65: FDISK_LINUX
*   82: FDISK_CPM
*   86: DOSDATA
*   98: OTHEROS
*   99: UNIXOS
*  101: FDISK_NOVELL3
*  119: FDISK_QNX4
*  120: FDISK_QNX42
*  121: FDISK_QNX43
*  130: SUNIXOS
*  131: FDISK_LINUXNAT
*  134: FDISK_NTFSVOL1
*  135: FDISK_NTFSVOL2
*  165: FDISK_BSD
*  167: FDISK_NEXTSTEP
*  183: FDISK_BSDIFS
*  184: FDISK_BSDISWAP
*  190: X86BOOT
*  191: SUNIXOS2
*  238: EFI_PMBR
*  239: EFI_FS
*

* Id    Act  Bhead  Bsect  Bcyl    Ehead  Esect  Ecyl    Rsect    Numsect
191   128  0      1      1       254    63     1023    16065    586083330
</pre>

We now need to calculate the maximum amount of usable storage. This is done by multiplying bytes/sectors (512 in my case) by the number of sectors listed at the bottom of the output shown above. We then divide this number by 1024*1024 to yield MBs.

So in my case, this will work out as 286173.5009765625 MB.

Now, we need to setup a partition table file. This will be a regular text file and you can name it whatever you like. For the sake of this post, I will name it disk_slices.txt. The contents of this file are:

<pre>
slices: 0 = 2MB, 286170MB, "wm", "root" :
      1 = 0, 1MB, "wu", "boot" :
      2 = 0, 286172MB, "wm", "backup"
</pre>

To create these slices on the disk, we run:

<pre>
# rmformat -s disk_slices.txt /dev/rdsk/c2t0d0p0
# devfsadm
# devfsadm -C
</pre>

To create the UFS file system on the newly created slice, I run the following and the output from running this command is also shown:

<pre>
# newfs /dev/rdsk/c2t0d0s0
newfs: construct a new file system /dev/rdsk/c2t0d0s0: (y/n)? y
/dev/rdsk/c2t0d0s0:     586076160 sectors in 95390 cylinders of 48 tracks, 128 sectors
      286170.0MB in 5962 cyl groups (16 c/g, 48.00MB/g, 5824 i/g)
super-block backups (for fsck -F ufs -o b=#) at:
32, 98464, 196896, 295328, 393760, 492192, 590624, 689056, 787488, 885920,
Initializing cylinder groups:
...............................................................................
........................................
super-block backups for last 10 cylinder groups at:
585105440, 585203872, 585302304, 585400736, 585499168, 585597600, 585696032,
585794464, 585892896, 585991328
#
</pre>

And now I'm finished, I now have a UFS file system created on my USB hard drive which can be mounted by my Solaris system. To mount this file system, I can just:

<pre>
# mount -F ufs /dev/rdsk/c2t0d0p0 /u01
</pre>
