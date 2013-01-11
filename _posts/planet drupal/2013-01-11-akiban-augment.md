--- 
title: Akiban as a MySQL Replica with Drupal 7
layout: post
category: planet drupal
---

I [previously wrote][prev_akiban_post] about how to install Drupal 7
completely on [Akiban][akiban_home]. However, this is not how our current customers are
using us. The vast majority of all Drupal installations currently run on
MySQL. What we at Akiban are currently aiming to do is to be deployed as
a regular MySQL slave and if there are any queries that are problematic
for MySQL, we work with customers to make sure those queries get
executed by Akiban (and with a significant performance improvement).

In this post, I wanted to cover how to setup Akiban as a MySQL slave and how a
query is typically re-directed to an Akiban server from Drupal. This
article is specific to Drupal 7.

First, I setup a regular Drupal install on Ubuntu 12.04 with MySQL
5.5.28. This is going to serve as the master server. To configure
replication in MySQL is pretty [straightforward][mysql_repl]. The following needs to
be placed in your `my.cnf` file and MySQL needs to be re-started:

{% highlight console %}
log-bin=mysql-bin
server-id=11
{% endhighlight %}

A user needs to be created for replication:

{% highlight console %}
CREATE USER 'repl'@'%' IDENTIFIED BY 'password';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
{% endhighlight %}

Next steps are to take a consistent snapshot of your Drupal schema with
`mysqldump` and capture the output of `SHOW MASTER STATUS` to get the
appropriate binlog co-ordinates.

Next, we need to setup an Akiban MySQL slave. We will use an entirely
separate instance for this purpose. First, the software to install on
this slave is:

{% highlight console %}
sudo apt-get install -y mysql-client mysql-server
sudo apt-get install -y python-software-properties
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 0AA4244A
sudo add-apt-repository "deb http://software.akiban.com/apt-developer/lucid main"
sudo apt-get update
sudo apt-get install -y akiban-server akiban-adapter-mysql postgresql-client
echo "INSTALL PLUGIN akibandb SONAME 'libakibandb_engine.so'" | mysql -u
root
{% endhighlight %}

Issuing the `SHOW PLUGINS` command on this slave will now show the
`AkibanDB` storage engine. The next step is to now import the
`mysqldump` file taken from the master and configure replication. On the
slave server, you need to make sure `server-id` is set in the `my.cnf`
file. Then to enable replication, a `CHANGE MASTER` command needs to be
issued. An example of what that command might look like is:

{% highlight console %}
CHANGE MASTER TO
  MASTER_HOST = 'ec2-23-20-112-161.compute-1.amazonaws.com',
  MASTER_USER = 'repl',
  MASTER_PASSWORD = 'password',
  MASTER_LOG_FILE = 'mysql-bin.000001',
  MASTER_LOG_POS = 403
{% endhighlight %}

Finally, issuing `START SLAVE` starts up replication. The observant
among you will notice all tables are still InnoDB on the slave. We have
done nothing to convert any tables to Akiban yet. Before we get to that
I want to configure Drupal running on the master server to know about
the Akiban slave so it can send queries to it. First, we need to install
the [Akiban database module][akiban_drupal] in Drupal (the akiban
directory should be copied to whatever the appropriate location for your
Drupal install is) and the PHP client drivers for PostgreSQL:

{% highlight console %}
sudo apt-get install -y git php5-pgsql
git clone http://git.drupal.org/sandbox/posulliv/1835778.git akiban
cd akiban
git checkout 7.x
cd ../
sudo cp -R akiban /var/www/drupal/includes/database/.
{% endhighlight %}

Now, the `settings.php` file needs to be updated to know about this
Akiban server:

{% highlight php %}
$databases = array (
  'default' =>
  array (
    'default' =>
    array (
      'database' => 'drupal',
      'username' => 'drupal',
      'password' => 'drupal',
      'host' => 'localhost',
      'port' => '',
      'driver' => 'mysql',
      'prefix' => '',
    ),
    'slave' =>
    array (
      'database' => 'drupal',
      'username' => 'drupal',
      'password' => 'drupal',
      'host' => 'ec2-23-22-113-161.compute-1.amazonaws.com',
      'port' => '15432',
      'driver' => 'akiban',
      'prefix' => '',
    ),
  ),
);
{% endhighlight %}

I would suggest enabling query logging on the Akiban server so you can see read
queries being sent to the slave. Query logging can be enabled by modifying the
`/etc/akiban/config/server.properties` file to have these entries:

{% highlight console %}
akserver.querylog.enabled=true
akserver.querylog.filename=/var/log/akiban/queries.log
akserver.querylog.exec_time_threshold=0
{% endhighlight %}

All queries issued against Akiban will now be logged to the
`/var/log/akiban/queries.log` file since we set the query execution time
threshold to 0. Akiban needs to re-started for this to take effect.

By default, very few queries from Drupal core are sent to a slave database. The 
search module is probably the best module to test with to see queries being
sent to Akiban. The search module can be accessed from your Drupal site 
by going to `http://your.ip.address/drupal/?q=search`

First, we need to convert those tables to Akiban, otherwise any search
will now fail since no tables have been converted to Akiban yet. To
convert these tables to Akiban, we simply issue the following in MySQL:

{% highlight sql %}
STOP SLAVE;
ALTER TABLE search_total ENGINE=AkibanDB;
ALTER TABLE search_index ENGINE=AkibanDB;
ALTER TABLE node ENGINE=AkibanDB;
ALTER TABLE search_index ADD CONSTRAINT `__akiban_fk_00` FOREIGN KEY (sid) REFERENCES node (nid);
ANALYZE TABLE node;
ANALYZE TABLE search_index;
ANALYZE TABLE search_total;
START SLAVE;
{% endhighlight %}

The relevant tables are now converted to Akiban.
Now, try searching content for a keyword. If everything is working correctly, queries
should start appearing in the query log on the Akiban server when issuing content
searches.

This is obviously a pretty simple example but now its pretty trivial to
send more queries to Akiban. Just change the database target, convert
the appropriate tables to Akiban on the slave, and away you go!

If there is anything you would like more information on, please let me
know in the comments or hit me up on [twitter][my_twitter] and I'd be
more than happy to dig in. We also have a [public mailing
list][mailing_list] for the Akiban project and I'd encourage anyone
who's interested to subscribe to that list and let us know how we're
doing! Finally, I'll be presenting on this topic at [drupalcamp
MA][drupalcamp_link] on January 19th and I am also delivering a joint
[webinar][webinar_link] with Acquia in February on this topic.

[prev_akiban_post]: http://posulliv.github.com/2012/12/14/drupal-7-install-akiban/
[akiban_home]: http://akiban.com/
[mysql_repl]: http://dev.mysql.com/doc/refman/5.5/en/replication-howto.html
[mailing_list]: https://groups.google.com/a/akiban.com/d/forum/akiban-user)
[downloads]: http://akiban.com/downloads
[dries_post]: http://buytaert.net/using-the-akiban-database-with-drupal
[my_twitter]: https://twitter.com/intent/user?screen_name=posulliv
[docs_link]: http://www.akiban.com/ak-docs/admin/server/server.config.html
[akiban_drupal]: http://drupal.org/sandbox/posulliv/1835778
[webinar_link]: http://www.akiban.com/webinars/how-to-ensure-sql-queries-don-t-slow-your-drupal-website#.UPA7B4njktg
[drupalcamp_link]: http://drupalcampma.com/how-solve-problem-drupal-queries-akiban
