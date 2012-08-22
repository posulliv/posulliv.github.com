--- 
wordpress_id: 36
layout: post
title: Building a Modified cp Binary on Solaris 10
category: solaris
---
I thought I would write a post on how I setup my Solaris 10 system to build an improved version of the stock cp(1) utility that comes with Solaris 10 in case anyone arrives here from Kevin Closson's blog. If you are looking for more background information on why I am performing this modification, have a look at <a href="http://kevinclosson.wordpress.com/2007/02/23/standard-file-utilities-with-direct-io/">this post</a> by Kevin Closson.

<span style="bold;">GNU Core Utilities</span>

We need to download the source code for the cp utility that we will be modifying. This source code is available as part of the <a href="http://www.gnu.org/software/coreutils/">GNU Core Utilities</a>.
<ul>
	<li><a href="http://ftp.gnu.org/pub/gnu/coreutils/coreutils-5.2.1.tar.gz">Coreutils 5.2.1</a></li>
</ul>
Down the software to an appropriate location on your system.

<span style="bold;">Modifying the Code</span>

Untar the code first on your system.

<pre>
# gunzip coreutils-5.2.1.tar.gz
# tar xvf coreutils-5.2.1.tar
</pre>

Proceed to the <code>coreutils-5.2.1/src</code> directory. Open the <code>copy.c</code> file with an editor. The following are the differences between the modified <code>copy.c</code> file and the original <code>copy.c</code> file:

<pre>
# diff -b copy.c.orig copy.c
287c315
&lt; buf_size =" ST_BLKSIZE"&gt;   /* buf_size = ST_BLKSIZE (sb);*/

288a317,319
&gt;
&gt;      buf_size = 8388608 ;
&gt;
</pre>

<span style="bold;">Building the Binary</span>

To build the modified cp binary, navigate first to the <code>coreutils-5.2.1</code> directory. Then enter the following (ensure that the <code>gcc</code> binary is in your <code>PATH</code> first; it is located at <code>/usr/sfw/bin/</code>):

<pre>
# ./configure
# /usr/ccs/bin/make
</pre>

We don't want to do <code>make install</code> as is the usual when building something from source like this as it would replace the stock cp(1) utility. Instead, we will copy the cp binary located in the <code>coreutils-5.2.1/src</code> directory like so:

<pre>
# cp coreutils-5.2.1/src/cp /usr/bin/cp8m
</pre>

<span style="bold;">Results of using the Modified cp</span>

See <a href="http://kevinclosson.wordpress.com/2007/03/15/copying-files-on-solaris-slow-or-fast-its-your-choice/">Kevin Closson's post</a> on copying files on Solaris for some in-depth discussion of this topic and more information on the reasoning behind making this modification to the cp(1) utility.
