--- 
title: Configuring Drupal 7.x With PostgreSQL Replication
layout: post
category: drupal
---
{% include JB/setup %}

One of the new features in Drupal 7 is that it supports sending queries to
a read-only slave database. Since version 9.0, PostgreSQL supports replication
natively. In this post, I wanted to cover how to configure replication in
PostgreSQL and have Drupal make use of a slave. I will use the master/slave
terminology that is common in the MySQL world when referring to the master
(primary) and slave (standby) servers in this post.

First, I installed PostgreSQL 9.1 on my master server along with Drupal 7.12
The steps taken to install and configure Drupal with PostgreSQL 9.1 on my master server
are outlined in this [gist][pg_gist]. Then I installed PostgreSQL 9.1 on another
server that will serve as a slave. My initial setup on the slave was quite 
simple and only involved a basic install and nothing else. The following commands
were all I executed on the slave server to get a base PostgreSQL install:

{% highlight console %}
sudo apt-get install python-software-properties
sudo add-apt-repository ppa:pitti/postgresql
sudo apt-get update
sudo apt-get install postgresql-9.1 libpq-dev postgresql-contrib-9.1
{% endhighlight %}

Once the basic Drupal install was up and running on the master and the slave server
has a basic PostgreSQL install, I started on 
configuring replication. Replication in general is documented in depth in the
online PostgreSQL [documentation][pg_rep_docs]. In this post, I will be 
configuring streaming replication which allows a slave server to service read
queries.

The steps that need to be performed to configure streaming
replication are (I will cover how to perform each step):

 * create a replication user for slaves to connect with
 * enable continuous archiving on the master
 * configure the master to allow remote connections with the replication user
 * take a base backup to be used for setting up a slave
 * set up a file-based log-shipping slave

The first step is to create a user for replication on the master:

{% highlight console %}
sudo su postgres
psql
create role repl replication login password 'repl';
{% endhighlight %}

Next, the master needs to be have continuous archiving enabled. This is 
achieved by editing the `/etc/postgresql/9.1/main/postgresql.conf` file
on the master and ensuring the following parameters are set:

{% highlight bash %}
wal_level = hot_standby
max_wal_senders = 3 # limits number of concurrent connections from standby
listen_addresses = '0.0.0.0'
archive_mode = on
archive_command = 'test ! -f /mnt/postgres/archivedir/%f && cp %p /mnt/postgres/archivedir/%f'
{% endhighlight %}

Now to allow remote connections for the replication user, the 
`/etc/postgresql/9.1/main/pg_hba.conf` file on the master server needs to
have an entry like (this assumes the slave server I have configured has the IP
address 10.39.111.10):

{% highlight bash %}
host  replication   repl 10.39.111.10/32      md5
{% endhighlight %}

Once the above modifications have been mode, we need to restart the PostgreSQL
service:

{% highlight console %}
sudo service postgresql restart
{% endhighlight %}

The master is now configured. Next we go to the slave server to take a base backup
using [`pg_basebackup`][base_backup] along with configuring the slave to use
this base backup for its data directory:

{% highlight console %}
sudo service postgresql stop
sudo mv /var/lib/postgresql/9.1/main/ /var/lib/postgresql/9.1/orig_main
sudo su postgres
pg_basebackup -D /var/lib/postgresql/9.1/main/ -P -h master_server -p 5432 -U repl -W
sudo ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /var/lib/postgresql/9.1/main/server.crt
sudo ln -s /etc/ssl/private/ssl-cert-snakeoil.key /var/lib/postgresql/9.1/main/server.key
{% endhighlight %}

The `pg_basebackup` command should result in output similar to the following:

{% highlight console %}
postgres@ip-10-39-111-9:/etc/postgresql/9.1/main$ pg_basebackup -D /var/lib/postgresql/9.1/main/ -P -h 10.76.241.129 -p 5432 -U repl -W
Password: 
WARNING:  skipping special file "./server.key"
WARNING:  skipping special file "./server.crt"
WARNING:  skipping special file "./server.key"
WARNING:  skipping special file "./server.crt"
1403786/1403786 kB (100%), 1/1 tablespace
NOTICE:  pg_stop_backup complete, all required WAL segments have been archived
postgres@ip-10-39-111-9:/etc/postgresql/9.1/main$ 
{% endhighlight %}

Next, we configure the slave to be a hot standby and to allow remote client 
connections (since Drupal will be connecting to the slave). This is done by
editing the `/etc/postgresql/9.1/main/postgresql.conf` file on the slave to
have the following entries:

{% highlight bash %}
hot_standby = on
listen_addresses = '0.0.0.0'
{% endhighlight %}

To allow the drupal user to connect from the master server (where `apache` is
running), modify the `/etc/postgresql/9.1/main/pg_hba.conf` file on the slave
(assuming 10.76.241.129 is IP address of master):

{% highlight bash %}
host  drupal drupal 10.76.241.129/32      md5
{% endhighlight %}

Next, create a `recovery.conf` file in the PostgreSQL data directory on the 
slave server:

{% highlight console %}
sudo touch /var/lib/postgresql/9.1/main/recovery.conf
sudo chown postgres:postgres /var/lib/postgresql/9.1/main/recovery.conf
{% endhighlight %}

The following should be placed in the `recovery.conf` file (assuming 
10.76.241.129 is IP address of master):

{% highlight bash %}
standby_mode = 'on'
primary_conninfo = 'host=10.76.241.129 port=5432 user=repl password=repl'
{% endhighlight %}

The PostgreSQL service on the slave server is now ready to be started again:

{% highlight console %}
sudo service postgresql start
{% endhighlight %}

If everything worked correctly, log entries indicating replication is running
should be present. For example, on my slave server my log file had entries like:

{% highlight console %}
ubuntu@ip-10-39-111-9:/var/log/postgresql$ sudo tail -n 5 /var/log/postgresql/postgresql-9.1-main.log 
2012-07-07 22:06:50 UTC LOG:  streaming replication successfully connected to primary
2012-07-07 22:06:50 UTC LOG:  incomplete startup packet
2012-07-07 22:06:50 UTC LOG:  redo starts at 1/15000020
2012-07-07 22:06:50 UTC LOG:  consistent recovery state reached at 1/16000000
2012-07-07 22:06:50 UTC LOG:  database system is ready to accept read only connections
ubuntu@ip-10-39-111-9:/var/log/postgresql$ 
{% endhighlight %}

Now, Drupal running on the master server is ready to be configured to use a
PostgreSQL slave for read-only queries! The `settings.php` file for the Drupal
site needs to be updated to know about this slave database. My `settings.php`
file looked like (10.39.111.10 is IP address of slave server):

{% highlight php5 %}
$databases = array (
  'default' =>
  array (
    'default' =>
    array (
      'database' => 'drupal',
      'username' => 'drupal',
      'password' => 'drupal',
      'host' => 'localhost',
      'port' => '5432',
      'driver' => 'pgsql',
      'prefix' => '',
    ),
    'slave' =>
    array (
      'database' => 'drupal',
      'username' => 'drupal',
      'password' => 'drupal',
      'host' => '10.39.111.10',
      'port' => '5432',
      'driver' => 'pgsql',
      'prefix' => '',
    ),
  ),
);
{% endhighlight %}

I would suggest enabling query logging on the slave server so you can see read
queries being sent to the slave. Query logging can be enabled by modifying the
`/etc/postgresql/9.1/main/postgresql.conf` file to have these entries:

{% highlight console %}
logging_collector = on
log_directory = 'pg_log'
log_statement = 'all'
{% endhighlight %}

Query log files will then be generated in the `/var/lib/postgresql/9,1/main/pg_log`
directory.

By default, very few queries from Drupal core are sent to a slave database. The 
search module is probably the best module to test with to see queries being
sent to the slave server. The search module can be access from your drupal site 
by going to `http://your.ip.address/drupal/?q=search`

Try searching content for a keyword. If everything is working correctly, queries
should start appearing in the query log on the slave server when issuing content
searches.

That's about it for this post. Once replication is configured in PostgreSQL,
having Drupal send queries to the slave is pretty straightforward.

[pg_gist]:    https://gist.github.com/3012400
[pg_rep_docs]: http://www.postgresql.org/docs/9.1/static/warm-standby.html
[base_backup]: http://www.postgresql.org/docs/9.1/static/app-pgbasebackup.html
