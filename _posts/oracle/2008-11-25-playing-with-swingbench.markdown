--- 
wordpress_id: 33
layout: post
title: Playing with Swingbench
wordpress_url: http://posulliv.com/?p=33
---
<a href="http://www.dominicgiles.com/swingbench.html">Swingbench</a> is a free load generator (and benchmarks generator) designed by <a href="http://www.dominicgiles.com/index.html">Dominic Giles</a> to stress test an Oracle database. In this post, I will be playing with Swingbench and showing how it can be used. This article will focus on comparing the performance of buffered I/O versus un-buffered I/O (i.e. direct I/O) using the Swingbench tool. Since this article is not about direct I/O (I encourage the interested reader to have a look <a href="http://kevinclosson.wordpress.com/2007/02/23/oracle-direct-io-brought-to-you-by-deranged-monkeys/">here</a> for more information on this topic), any results presented here should not be considered conclusive. The results presented are very simple and not complicated at all so should not be taken very seriously. The main point of this article is demonstrate the Swingbench utility; how to set it up and use it.

<span style="font-weight: bold;">A Note About the Environment Used for Testing</span>

Before we delve into using Swingbench, I thought I should mention a little about the environment used for testing as it affects the results a lot! The box used to run the database in this post is a Dell Latitude D810 laptop with a 2.13 GHz processor and 1GB of RAM. It is running on Solaris 10, specifically the 11/06 release. The datafiles and redo log files are stored on a Maxtor OneTouch II external hard drive connected via a USB 2.0 interface.

The datafiles for the database reside on a 80 GB partition which is formatted with a UFS filesystem and the redo logs reside on a 20 GB partition which is also formatted with a UFS filesystem. The database is not running in archive log mode and there is no flash recovery area configured.

<span style="font-weight: bold;">Enabling Direct I/O</span>

One quick section on how we will be enabling direct I/O for testing purposes. The UFS file system (as does most file systems) supports mounting the file system options which enable processes to bypass the OS page cache. One way to enable direct I/O on a UFS file system is to mount the file system with the <code>forcedirectio</code> mount option as so:
<pre># mount -o forcedirectio /dev/dsk/c2t1d0s1 /u02</pre>
Another method which is possible is setting the <code>FILESYSTEMIO_OPTIONS=SETALL</code> parameter within Oracle (available in 9i and later). As <a href="http://blogs.sun.com/glennf/">Glenn Fawcett</a> states in <a href="http://blogs.sun.com/glennf/entry/where_do_you_cache_oracle">this excellent post</a> on direct I/O, the <code>SETALL</code> value passed to the <code>FILESYSTEMIO_OPTIONS</code> parameters sets all the options for a particular file system to enable direct I/O or async I/O. When this parameter is set as stated, Oracle will use an API to enable direct I/O when it opens database files.

<span style="font-weight: bold;">Swingbench Installation and Configuration</span>

Now that we've got the preliminaries out of the way, its time to get on to the main reason for this post. The Swingbench code is shipped in a zip file which can be downloaded from <a href="http://www.dominicgiles.com/downloads.html">here</a>. A prerequisite for running Swingbench is that a Java virtual machine needs to be present on the machine which you will be running Swingbench on.

After unzipping the Swingbench zip file, you will need to edit the <code>swingbench.env</code> file (if on a UNIX platform) found in the top-level swingbench directory. The following variables need to be modified according to your environment:
<ul>
	<li><code>ORACLE_HOME</code></li>
	<li><code>JAVA_HOME</code></li>
	<li><code>SWINGHOME</code></li>
</ul>
If using the Oracle instance client software instead of a full RDBMS install on the machine you are running Swingbench, the <code>CLASSPATH</code> variable must also be modified from <code>$ORACLE_HOME/jdbc/lib/ojdbc14.jar</code> to <code>$ORACLE_HOME/lib/ojdbc14.jar</code>.

<span style="font-weight: bold;">Installing Calling Circle</span>

The Calling Circle is an open-source preconfigured benchmark which comes with Swingbench. The Order Entry benchmark also comes with Swingbench but for the purposes of this article, we will only discuss the Calling Circle benchmark.

The Calling Circle benchmark implements an example OLTP online telecommunications application. The goal of this application is to simulate a randomized workload of customer transactions and measure transaction throughput and response times. Approximately 97 % of the transactions cause at least one database update, with well over three quarters performing two or more updates. More information can be found in the Readme.txt file which comes with the Swingbench software.

The first step for installing Calling Circle is to create the Calling Circle schema (CC) in the database. This is achieved using the <code>ccwizard</code> executable found in the <code>swingbench/bin</code> directory .
<pre>$ ./ccwizard</pre>
Click [Next] on the welcome screen and you will then be presented with the screen shown on the below:

<a href="http://4.bp.blogspot.com/_heUWGgTt1gk/STIJy46YGgI/AAAAAAAAA4k/ihrvixJyzhM/s1600-h/cc1.JPG" onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}"><img id="BLOGGER_PHOTO_ID_5274288883479616002" style="margin: 0px auto 10px; display: block; text-align: center; cursor: pointer; width: 400px; height: 268px;" src="http://4.bp.blogspot.com/_heUWGgTt1gk/STIJy46YGgI/AAAAAAAAA4k/ihrvixJyzhM/s400/cc1.JPG" border="0" alt="" /></a>

Choose the option to create the Calling Circle schema. In the next screen, enter the connection details of the database you will be creating the schema in. This will involve entering the host name, port number (if not using the default port of 1521 for your listener) and the database service name. Also, ensure that you choose the type IV Thin JDBC driver. Click [Next] when you have entered this information.

The next screen involves the schema details for the Calling Circle schema. Enter appropriate locations for the datafiles on your system. When finished entering information on this screen, click [Next] to continue. This will bring you to the Schema Sizing window as shown below:

<a href="http://2.bp.blogspot.com/_heUWGgTt1gk/STIKYmx3XTI/AAAAAAAAA4s/5cCmn4wE19w/s1600-h/cc2.JPG" onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}"><img id="BLOGGER_PHOTO_ID_5274289531447106866" style="margin: 0px auto 10px; display: block; text-align: center; cursor: pointer; width: 320px; height: 216px;" src="http://2.bp.blogspot.com/_heUWGgTt1gk/STIKYmx3XTI/AAAAAAAAA4s/5cCmn4wE19w/s320/cc2.JPG" border="0" alt="" /></a>

Use the slider to select the schema size you wish to use. For this post, I chose to use a schema size with 2,023,019 customers which implies a tablespace of size 2.1GB for data and a tablespace of size 1.3GB for indexes. When finished choosing your schema size, click [Next] to continue. Click [Finish] on the next screen to complete the wizard and create the schema. A progress bar will appear as shown below

<a href="http://4.bp.blogspot.com/_heUWGgTt1gk/STIK0KMrsLI/AAAAAAAAA40/_6lpY2NkQns/s1600-h/cc3.JPG" onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}"><img id="BLOGGER_PHOTO_ID_5274290004811296946" style="margin: 0px auto 10px; display: block; text-align: center; cursor: pointer; width: 320px; height: 216px;" src="http://4.bp.blogspot.com/_heUWGgTt1gk/STIK0KMrsLI/AAAAAAAAA40/_6lpY2NkQns/s320/cc3.JPG" border="0" alt="" /></a>

<span style="font-weight: bold;">Creating the Input Data for Calling Circle</span>

Before each run of the Calling Circle application it is necessary to create the input data for the benchmark to run. This is accomplished using the ccwizard program we used previously for creating the Calling Circle schema. Start up the ccwizard program again and click [Next] on the welcome screen. On the "Select Task" screen show previously, this time select to "Generate Data for Benchmark Run" and click [Next].

In the "Schema Details" window which follows, enter the details of the schema which you created in the last section. Click [Next] once all the necessary information has been entered. You will then be presented with the "Benchmark Details" screen as shown below:

<a href="http://3.bp.blogspot.com/_heUWGgTt1gk/STILE_DDDvI/AAAAAAAAA48/KTrL5Upydjs/s1600-h/cc4.JPG" onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}"><img id="BLOGGER_PHOTO_ID_5274290293875871474" style="margin: 0px auto 10px; display: block; text-align: center; cursor: pointer; width: 320px; height: 217px;" src="http://3.bp.blogspot.com/_heUWGgTt1gk/STILE_DDDvI/AAAAAAAAA48/KTrL5Upydjs/s320/cc4.JPG" border="0" alt="" /></a>

In this post, we will use 1000 transactions for each test as seen in the "Number of Transactions" dialog window above. Press [Next] to continue and you will be presented with the final screen. Click [Finish] to create the benchmark data.

<span style="font-weight: bold;">Starting the Benchmark Test</span>

Now that we have the Calling Circle schema created and the input data generated, we can start our tests. To start up Swingbench and ensure that it operates with the Calling Circle benchmark we can pass the sample Calling Circle configuration file (<code>ccconfig.xml</code>) which is supplied with Swingbench as a runtime parameter as so:
<pre>$ ./swingbench -c sample/ccconfig.xml</pre>
This will start up Swingbench with the sample configuration for the Calling Circle application but only a few settings need to be changed for is to use this configuration. All that needs to be changed is the connection settings for the host you have already setup the Calling Circle schema on. Change the connection settings as necessary for your environment.

The following screen shot show the Calling Circle application running in Swingbench:

<a href="http://1.bp.blogspot.com/_heUWGgTt1gk/STILZ5Z99TI/AAAAAAAAA5E/nsyz4cLLO3Y/s1600-h/cc6.JPG" onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}"><img id="BLOGGER_PHOTO_ID_5274290653138646322" style="margin: 0px auto 10px; display: block; text-align: center; cursor: pointer; width: 320px; height: 203px;" src="http://1.bp.blogspot.com/_heUWGgTt1gk/STILZ5Z99TI/AAAAAAAAA5E/nsyz4cLLO3Y/s320/cc6.JPG" border="0" alt="" /></a>

We will be performing 1000 transactions during each test run as specified when we generated the sample data. The Swingbench configuration we will be using for every test we perform is as follows:

<a href="http://3.bp.blogspot.com/_heUWGgTt1gk/STILqWF5wWI/AAAAAAAAA5M/BaEBxRorHJU/s1600-h/tab1.JPG" onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}"><img id="BLOGGER_PHOTO_ID_5274290935717020002" style="margin: 0px auto 10px; display: block; text-align: center; cursor: pointer; width: 320px; height: 56px;" src="http://3.bp.blogspot.com/_heUWGgTt1gk/STILqWF5wWI/AAAAAAAAA5M/BaEBxRorHJU/s320/tab1.JPG" border="0" alt="" /></a>

This workload is typical of an OLTP application with 40% reads and 60% writes. The number of users associated with the workload is 15. We will use this exact workload for every test we perform.

<span style="font-weight: bold;">Results &amp; Conclusion</span>

The measurements from Swingbench which we will use for comparing the performance of a UFS file system when Oracle uses direct I/O versus buffered I/O are the following:
<ul>
	<li>Transaction throughput (number of transactions per minute)</li>
	<li>Average response time for each transaction type</li>
</ul>
We will perform a run of the benchmark 5 times for each configuration we want to compare and then present the average of the measurements below. So we will run the tests 5 times with buffered I/O and then 5 times with un-buffered I/O by setting the <code>FILESYSTEMIO_OPTIONS</code> parameter.

So the comparisons from these 2 measurements are as follows:

<a href="http://4.bp.blogspot.com/_heUWGgTt1gk/STIMDvZVpMI/AAAAAAAAA5U/UNq_9k2HGN4/s1600-h/tab2.JPG" onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}"><img id="BLOGGER_PHOTO_ID_5274291372006155458" style="margin: 0px auto 10px; display: block; text-align: center; cursor: pointer; width: 320px; height: 55px;" src="http://4.bp.blogspot.com/_heUWGgTt1gk/STIMDvZVpMI/AAAAAAAAA5U/UNq_9k2HGN4/s320/tab2.JPG" border="0" alt="" /></a>

While these tests were not very conclusive or thorough, they do show how Swingbench can be used for generating database activity. The measurements which I compared are only some of the measurements which Swingbench reports when finished running a benchmark. Hopefully I will be able to play and post a bit more on the excellent Swingbench utility in the future.
