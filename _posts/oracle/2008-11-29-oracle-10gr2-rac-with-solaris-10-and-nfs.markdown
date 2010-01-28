--- 
wordpress_id: 35
layout: post
title: Oracle 10gR2 RAC with Solaris 10 and NFS
wordpress_url: http://posulliv.com/?p=35
---
Recently, I setup a 2 node RAC environment for testing using Solaris 10 and NFS. This environment consisted of 2 RAC nodes running Solaris 10 and a Solaris 10 server which served as my NFS filer.

I thought it might prove useful to create a post on how this is achieved as I found it to be a relatively quick way to setup a cheap test RAC environment. Obviously, this setup is not supported by Oracle and should only be used for development and testing purposes.

This post will only detail the steps which are specific to this setup; meaning I wont talk about a number of steps which need to be performed such as setting up user equivalence and creating the database. I will mention when these steps should be performed but I point you to <a href="http://www.oracle.com/technology/pub/articles/hunter_rac10gr2_iscsi.html">Jeffrey Hunter's article </a>on building a 10gR2 RAC on Linux with iSCSI for more information on steps like this.

<span style="bold;">Overview of the Environment</span>

Here is a diagram of the architecture used which is based on Jeff Hunter's diagram from the previously mentioned article (click on the image to get a larger view):

<a href="http://3.bp.blogspot.com/_heUWGgTt1gk/STIMzMzaYQI/AAAAAAAAA5c/WghDP4suj7I/s1600-h/rac2.jpg"><img style="270px;" src="http://3.bp.blogspot.com/_heUWGgTt1gk/STIMzMzaYQI/AAAAAAAAA5c/WghDP4suj7I/s320/rac2.jpg" border="0" alt="" /></a>

You can see that I am using an external hard drive attached to the NFS filer for storage. This external hard drive will hold all my database and Clusterware files.

Again, the hardware used is the exact same as the hardware used in Jeff Hunter's article. Notice however that I do not have a public interface configured for my NFS filer. This is mainly because I did not have any spare network interfaces lying around for me to use!

<span style="bold;">Getting Started</span>

To get started, we will install Solaris 10 for the x86 architecture on all three machines. The ISO images for Solaris 10 x86 can be downloaded from Sun's website <a href="http://www.sun.com/software/solaris/get.jsp">here</a>. You will need a Sun Online account to access the downloads but registration is free and painless.

I won't be covering the Solaris 10 installation process here but for more information, I refer you to the official Sun basic installation guide found <a href="http://docs.sun.com/app/docs/doc/817-0544/6mgbagb19?a=view">here</a>.

When installing Solaris 10, make sure that you configure both network interfaces. Ensure that you do not use DHCP for either network interface and specify all the necessary details for your environment.

After installation, you should update the <code>/etc/inet/hosts</code> file on all hosts. For my environment as shown in the diagram above, my <code>hosts</code> file looked like the following:

<pre>
#
# Internet host table
#
127.0.0.1 localhost

# Public Network - (pcn0)
172.16.16.27 solaris1
172.16.16.28 solaris2

# Private Interconnect - (pcn1)
192.168.2.111 solaris1-priv
192.168.2.112 solaris2-priv

# Public Virtual IP (VIP) addresses for - (pcn0)
172.16.16.31 solaris1-vip
172.16.16.32 solaris2-vip

# NFS Filer - (pcn1)
192.168.2.195 solaris-filer
</pre>
<br>
The network settings on the RAC nodes will need to be adjusted as they can affect cluster interconnect transmissions. The UDP parameters which need to be modified on Solaris are <code>udp_recv_hiwat</code> and <code>udp_xmit_hiwat</code>. The default values for these parameters on Solaris 10 are 57344 bytes. Oracle recommends that these parameters are set to at least 65536 bytes.

To see what these parameters are currently set to, perform the following:

<pre>
# ndd /dev/udp udp_xmit_hiwat
57344
# ndd /dev/udp udp_recv_hiwat
57344
</pre>
<br>
To set the values of these parameters to 65536 bytes in current memory, perform the following:

<pre>
# ndd -set /dev/udp udp_xmit_hiwat 65536
# ndd -set /dev/udp udp_recv_hiwat 65536
</pre>
<br>
Now we obviously want these parameters to be set to these values when the system boots. The official Oracle documentation is incorrect when it states that the parameters are set on boot when they are placed in the <code>/etc/system</code> file. The values placed in <code>/etc/system</code> will have no affect on Solaris 10. Bug 5237047 has more information on this.

So what we will do is to create a startup script called <code>udp_rac</code> in <code>/etc/init.d</code>. This script will have the following contents:

<pre>
#!/sbin/sh
case "$1" in
'start')
ndd -set /dev/udp udp_xmit_hiwat 65536
ndd -set /dev/udp udp_recv_hiwat 65536
;;
'state')
ndd /dev/udp udp_xmit_hiwat
ndd /dev/udp udp_recv_hiwat
;;
*)
echo "Usage: $0 { start | state }"
exit 1
;;
esac
</pre>
<br>
Now, we need to create a link to this script in the <code>/etc/rc3.d</code> directory:

<pre>
# ln -s /etc/init.d/udp_rac /etc/rc3.d/S86udp_rac
</pre>
<br>
<span style="bold;">Configuring the NFS Filer</span>

Now that we have Solaris installed on all our machines, its time to start configuring our NFS filer. As I mentioned before, I will be using an external hard drive for storing all my database files and Clusterware files. If you're not using an external hard drive you can ignore the next paragraph.

In my <a href="http://padraigs.blogspot.com/2007/03/creating-ufs-file-system-on-external.html">previous post</a>, I talked about creating a UFS file system on an external hard drive in Solaris 10. I am going to be following that post exactly. So if you perform what I mention in that post, you will have a UFS file system ready for mounting.

Now, I have a UFS file system created on the <code>/dev/dsk/c2t0d0s0</code> device. I will create a directory for mounting this file system and then mount it:

<pre>
# mkdir -p /export/rac
# mount -F ufs /dev/dsk/c2t0d0s0 /export/rac
</pre>
<br>
Now that we have created the base directory, lets create directories inside this which will contain the various files for our RAC environment.

<pre>
# cd /export/rac
# mkdir crs_files
# mkdir oradata
</pre>
<br>
The <code>/export/rac/crs_files</code> directory will contain the OCR and the voting disk files used by Oracle Clusterware. The <code>/export/rac/oradata</code> directory will contain all the Oracle data files, control files, redo logs and archive logs for the cluster database.

Obviously, this setup is not ideal since everything is on the same device. For setting up this environment, I didn't care. All I wanted to do was get a quick RAC environment up and running and show how easily it can be done with NFS. More care should be taken in the previous step but I'm lazy...

Now we need to make these directories accessible to the Oracle RAC nodes. I will be accomplishing this using NFS. We first need to edit the <code>/etc/dfs/dfstab</code> file to specify which directories we want to share and what options we want to use when sharing them. The <code>dfstab</code> file I configured looked like so:

<pre>
#       Place share(1M) commands here for automatic execution
#       on entering init state 3.
#
#       Issue the command 'svcadm enable network/nfs/server' to
#       run the NFS daemon processes and the share commands, after adding
#       the very first entry to this file.
#
#       share [-F fstype] [ -o options] [-d ""]  [resource]
#       .e.g,
#       share  -F nfs  -o rw=engineering  -d "home dirs"  /export/home2
share -F nfs -o rw,anon=175 /export/rac/crs_files
share -F nfs -o rw,anon=175 /export/rac/oradata
</pre>
<br>
The <code>anon</code> option in the <code>dfstab</code> file as shown above, is the user ID of the oracle user on the cluster nodes. This user ID should be the same on all nodes in the cluster.

After editing the <code>dfstab</code> file, the NFS daemon process needs to be restarted. You can do this on Solaris 10 like so:
<pre>
# svcadm restart nfs/server
</pre>
<br>
To check if the directories are exported correctly, the following can be performed from the NFS filer:

<pre>
# share
-               /export/rac/crs_files   rw,anon=175   ""
-               /export/rac/oradata     rw,anon=175   ""
#
</pre>
<br>
The specified directories should now be accessible from the Oracle RAC nodes. To verify that these directories are accessible from the RAC nodes, run the following from both nodes (<code>solaris1</code> and <code>solaris2</code> in my case):

<pre>
# dfshares solaris-filer
RESOURCE                                  SERVER ACCESS    TRANSPORT
solaris-filer:/export/rac/crs_files    solaris-filer  -         -
solaris-filer:/export/rac/oradata      solaris-filer  -         -
#
</pre>
<br>
The output should be the same on both nodes.

<span style="bold;">Configure NFS Exports on Oracle RAC Nodes</span>

Now we need to configure the NFS exports on the two nodes in the cluster. First, we must create directories where we will be mounting the exports. In my case, I did this:

<pre>
# mkdir /u02
# mkdir /u03
</pre>
<br>
I am not using <code>u01</code> as I'm using this directory for installing the software. I will not be configuring a shared Oracle home in this article as I wanted to keep things as simple as possible but that might serve as a good future blog post.

For mounting the NFS exports, there are specific mount options which must be used with NFS in an Oracle RAC environment. The mount command which I used to manually mount these exports is as follows:

<pre>
# mount -F nfs -o rw,hard,nointr,rsize=32768,wsize=32768,noac,proto=tcp,forcedirectio,vers=3 \
solaris-filer:/export/rac/crs_files /u02
# mount -F nfs -o rw,hard,nointr,rsize=32768,wsize=32768,noac,proto=tcp,forcedirectio,vers=3 \
solaris-filer:/export/rac/oradata /u03
</pre>
<br>
Obviously, we want these exports to be mounted at boot. This is accomplished by adding the necessary lines to the <code>/etc/vfstab</code> file. The extra lines which I added to the <code>/etc/vfstab</code> file on both nodes were (the output below did not come out very well originally so I had to split each line into 2 lines):

<pre>
solaris-filer:/export/rac/crs_files   -   /u02   nfs   -   yes
rw,hard,bg,nointr,rsize=32768,wsize=32768,noac,proto=tcp,forcedirectio,vers=3
solaris-filer:/export/rac/oradata     -   /u03   nfs   -   yes
rw,hard,bg,nointr,rsize=32768,wsize=32768,noac,proto=tcp,forcedirectio,vers=3
</pre>
<br>
<span style="bold;">Configure the Solaris Servers for Oracle</span>

Now that we have shared storage setup, it's time to configure the Solaris servers on which we will be installing Oracle. One little thing which must be performed on Solaris is to create symbolic links for the SSH binaries. The Oracle Universal Installer and configuration assistants (such as NETCA) will look for the SSH binaries in the wrong location on Solaris. Even if the SSH binaries are included in your path when you start these programs, they will still look for the binaries in the wrong location. On Solaris, the SSH binaries are located in the <code>/usr/bin</code> directory by default. The OUI will throw an error stating that it cannot find the <code>ssh</code> or <code>scp</code> binaries. My simple workaround was to simply create a symbolic link in the <code>/usr/local/bin</code> directory for these binaries.

<pre>
# ln -s /usr/bin/ssh /usr/local/bin/ssh
# ln -s /usr/bin/scp /usr/local/bin/scp
</pre>
<br>
You should also create the oracle user and directories now before configuring kernel parameters.

For configuring and setting kernel parameters on Solaris 10 for Oracle, I point you to <a href="http://www.dizwell.com/prod/node/235">this excellent installation guide</a> for Oracle on Solaris 10 by Howard Rogers. It contains all the necessary information you need for configuring your Solaris 10 system for Oracle. Just remember to perform all steps mentioned in his article on both nodes in the cluster.

<span style="bold;">What's Left to Do</span>

From here on in, its quite easy to follow Jeff Hunter's <a href="http://www.oracle.com/technology/pub/articles/hunter_rac10gr2_iscsi.html">article</a>. Obviously, you wont be using ASM. The only differences between what to do now and what he has documented is file locations. So you could follow along from <a href="http://www.oracle.com/technology/pub/articles/hunter_rac10gr2_iscsi_2.html#14">section 14</a> and you should be able to get a 10gR2 RAC environment up and running. Obviously, there is some sections such as setting up OCFS2 and ASMLib that can be left out since we are installing on Solaris and not Linux.
