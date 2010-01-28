--- 
wordpress_id: 206
layout: post
title: S3 Storage Engine with Memcached in Drizzle
wordpress_url: http://posulliv.com/?p=206
---
Previously, I had ported Brian's <a href="http://tangent.org/506/memcache_engine.html">memcached engine</a> to Drizzle and rencently, I've been doing some work with Amazon's S3 for school. Thus, I decided to have a look at Mark's <a href="http://fallenpegasus.com/code/mysql-awss3/">S3 storage engine</a> for MySQL. Over the last 2 days, I created a new version of the S3 storage engine for Drizzle with the option to use <a href="http://memcached.org/">Memcached</a> as a write-through cache for the S3 backend store. I see this work more as showing the cool things we can do in Drizzle and how quickly we can get prototypes up and running. I don't even know if this is a good idea or anything but its cool to be able to store all data in S3.

First, lets see how to create a table with this engine. The one constraint on tables created with this engine is that they need to have a primary key specified on the table. Each table that is created in this engine is represented as a bucket in S3. So whenever you create a table with this engine, you create a bucket in S3. So lets try creating a table:
<pre>drizzle&gt; create database demo;
Query OK, 1 row affected (0 sec)

drizzle&gt; use demo;
Database changed
drizzle&gt; create table padara (
    -&gt; a int primary key,
    -&gt; b varchar(255),
    -&gt; c varchar(255)) engine=mcaws;
ERROR 1005 (HY000): Can't create table 'demo.padara' (errno: 1005)
drizzle&gt;
</pre>
Lets get some more information on why that table creation failed:
<pre>drizzle&gt; show warnings;
+-------+------+-------------------------------------------------------------------------------------+
| Level | Code | Message                                                                             |
+-------+------+-------------------------------------------------------------------------------------+
| Error | 1005 | Amazon S3 Connection Pool has not been created (Did you specify your credentials?)
 |
| Error | 1005 | Can't create table 'demo.padara' (errno: 1005)                                      |
+-------+------+-------------------------------------------------------------------------------------+
2 rows in set (0 sec)

drizzle&gt;</pre>
As you see, we need to specify our Amazon AWS access credentials before we can utilize this store engine. For the moment, I have the following system variables associated with this plugin:
<pre>drizzle&gt; show variables like '%AWS%';
+-----------------------+-------+
| Variable_name         | Value |
+-----------------------+-------+
| mcaws_accesskey       |       |
| mcaws_mcservers       |       |
| mcaws_secretaccesskey |       |
+-----------------------+-------+
3 rows in set (0 sec)

drizzle&gt;</pre>
So I set the AWS access credentials by setting the appropriate system variables (this has to be done before tables can be created with this engine and in this order):
<pre>drizzle&gt; set global mcaws_accesskey = 'YOUR_ACCESS_KEY';
Query OK, 0 rows affected (0 sec)

drizzle&gt; set global mcaws_secretaccesskey = 'YOUR_SECRET_ACCESS_KEY';
Query OK, 0 rows affected (0 sec)

drizzle&gt; show variables like '%AWS%';
+-----------------------+------------------------------------------+
| Variable_name         | Value                                    |
+-----------------------+------------------------------------------+
| mcaws_accesskey       | YOUR_ACCESS_KEY                     |
| mcaws_mcservers       |                                          |
| mcaws_secretaccesskey | YOUR_SECRET_ACCESS_KEY |
+-----------------------+------------------------------------------+
3 rows in set (0 sec)

drizzle&gt;</pre>
Before creating the table, lets look at what buckets are associated with my S3 account. I'm going to use the <a href="http://www.s3fox.net/">S3Fox</a> firefox plugin for this (there is multiple other things you could use). Here are the buckets in my S3 account right now:

<a href="http://posulliv.com/wp-content/uploads/2009/11/s3fox.png"><img class="aligncenter size-medium wp-image-209" src="http://posulliv.com/wp-content/uploads/2009/11/s3fox-300x270.png" alt="" width="300" height="270" /></a>

I just have the one bucket for now. Now, I create a table using the S3 engine after specifying my AWS credentials:
<pre>
drizzle&gt; create table padara (
    -&gt; a int primary key,
    -&gt; b varchar(255),
    -&gt; c varchar(255)) engine=mcaws;
Query OK, 0 rows affected (0.31 sec)

drizzle&gt;</pre>
and when I look at my buckets in S3, I should see a new bucket representing the new table I created:

<a href="http://posulliv.com/wp-content/uploads/2009/11/s3foxafter.png"><img class="aligncenter size-medium wp-image-212" src="http://posulliv.com/wp-content/uploads/2009/11/s3foxafter-300x270.png" alt="" width="300" height="270" /></a>

As can be seen, the bucket name is the database name concatenated with the table name - 'databasetable'. Next, lets insert some rows in the table and then see what objects are in the bucket:
<pre>drizzle&gt; insert into padara
    -&gt; values (1, 'padraig', 'sullivan');
Query OK, 1 row affected (0.07 sec)

drizzle&gt; insert into padara
    -&gt; values (2, 'domhnall', 'sullivan');
Query OK, 1 row affected (0.08 sec)

drizzle&gt; insert into padara
    -&gt; values (3, 'tomas', 'sullivan');
Query OK, 1 row affected (0.14 sec)

drizzle&gt;</pre>
<a href="http://posulliv.com/wp-content/uploads/2009/11/s3foxobjects.png"><img class="aligncenter size-medium wp-image-213" src="http://posulliv.com/wp-content/uploads/2009/11/s3foxobjects-300x270.png" alt="" width="300" height="270" /></a>

Now we can query the table. Queries on the table need to specify a primary key value in the WHERE clause for now so we will just be returning one row (I'll be looking into range queries pretty soon):
<pre>drizzle&gt; select *
    -&gt; from padara
    -&gt; where a = 2;
+---+----------+----------+
| a | b        | c        |
+---+----------+----------+
| 2 | domhnall | sullivan |
+---+----------+----------+
1 row in set (5 sec)

drizzle&gt;</pre>
That's basically the simple S3 engine. It works just like a regular storage engine except the data is stored on S3. Of course, the latency involved in interacting with S3 for every request can be quite limiting. For example, the simple query above took 5 seconds to retrieve the data. Thus, I added support for using memcached as a write-through cache for this engine. All we need to do is specify the memcached servers to use in the appropriate system variable:
<pre>drizzle&gt; set global mcaws_mcservers = 'localhost:19191';
Query OK, 0 rows affected (0 sec)

drizzle&gt;</pre>
Now, whenever we query a table created in this engine, we will check for the data in memcached first and if we miss in the cache, only then do we go to S3 for the data. When inserting new data, we insert it in both memcached and S3. Using memcached for this engine is totally optional. It can simply be used as a way to store data in S3 through the engine interface but I thought it might prove to be a useful option for an engine like this.

I wanted to show how clean the code to implement the functionality to do this in the plugin is. This goes to show the benefit of the great build system Monty Taylor has put a lot of work in to in Drizzle. I can easily utilize external libraries in my plugin - in this case <a href="https://launchpad.net/libmemcached">libmemcached</a> and <a href="http://aws.28msec.com/">libaws</a>. The code below first checks for data in memcached and if it is not present there, retrieves the data from S3 and updates memcached before returning to the engine.

[gist id=230509]

So thats about it for now. In the future, there are a few things I plan on working on for this engine:
<ul>
	<li>removing the need to have a table represented as a bucket in S3 (this design makes the code much simpler for now)</li>
</ul>
<ul>
	<li> increasing the size of the objects transferred from/to S3 - make the unit of transfer between the engine a page instead of a row as it is now</li>
</ul>
<ul>
	<li> create I_S tables for monitoring S3 usage</li>
</ul>
<ul>
	<li> add support for range queries</li>
</ul>
<ul>
	<li> remove the need for a table to have a primary key</li>
</ul>
If you are interested in downloading the branch and playing with it, you can get it and build it by:
<pre>$ bzr branch lp:~posulliv/drizzle/aws-mc-engine
$ cd aws-mc-engine
$ ./config/autorun.sh &amp;&amp; ./configure &amp;&amp; make</pre>
libmemcached and libaws are prequisites that you will need installed before compiling this plugin.

If anyone has any feedback or suggestions on what to do with this, that would be awesome. I really have no idea what to do with it!
