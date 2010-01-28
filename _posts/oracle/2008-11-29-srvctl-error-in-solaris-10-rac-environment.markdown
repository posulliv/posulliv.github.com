--- 
wordpress_id: 37
layout: post
title: srvctl Error in Solaris 10 RAC Environment
wordpress_url: http://posulliv.com/?p=37
---
If you install a RAC environment on Solaris 10 and set kernel parameters using resource control projects (which is the recommended method in Solaris 10), then you will likely encounter issues when trying to start the cluster database or an individual instance using the <code>srvctl</code> utility. As an example, this is likely what you will encounter:

<pre>
$ srvctl start instance -d orclrac -i orclrac2
PRKP-1001 : Error starting instance orclrac2 on node nap-rac02
CRS-0215: Could not start resource 'ora.orclrac.orclrac2.inst'.
$
</pre>

along with the following messages in the alert log

<pre>
Tue Apr 24 11:36:21 2007
Starting ORACLE instance (normal)
Tue Apr 24 11:36:21 2007
WARNING: EINVAL creating segment of size 0x0000000024802000
fix shm parameters in /etc/system or equivalent
</pre>

This is because the <code>srvctl</code> utility is unable to get the correct shared memory related settings using <code>prctl</code> as it reads the settings from the <code>/etc/system</code> file. This is documented in bug 5340239 on Metalink.

The only workaround for this at the moment (that I know of) is to manually add the necessary shm parameters to the <code>/etc/system</code> file, for example:

<pre>
set semsys:seminfo_semmni=100
set semsys:seminfo_semmsl=256
set shmsys:shminfo_shmmax=4294967295
set shmsys:shminfo_shmmni=100
</pre>
