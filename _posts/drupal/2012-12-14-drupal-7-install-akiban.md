--- 
title: Installing Drupal 7 with Akiban
layout: post
category: drupal
---

Dries recently published a [post][dries_post] highlighting some work we've done
with a particular customer in the Acquia cloud. What I wanted to cover
in this post was to how to perform an installation of Akiban and get a
Drupal 7 site up and running on Akiban. This post only covers a fresh
installation; later posts will cover how to do migration and augmenting an
existing site instead of running it entirely on Akbian.

This post is specific to Ubuntu but [Akiban][downloads] runs on CentOS
too (as well as OSX and Windows which we have installers for). If people
would like to see information specific to those platforms, please let me
know in the comments.

First things first, lets install Akiban!

{% highlight console %}
sudo apt-get install -y python-software-properties
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 0AA4244A
sudo add-apt-repository "deb http://software.akiban.com/apt-developer/ lucid main"
sudo apt-get update
sudo apt-get install -y akiban-server postgresql-client
{% endhighlight %}

The above will automatically start the Akiban server process and half of
your available memory will be allocated for the JVM heap by default. If
interested in modifying any configuration options, please see our
[documention][docs_link] on how to do this.

Next, we'll download Drupal 7 and install Apache along with the needed
PHP database drivers for Akiban.

{% highlight console %}
wget http://ftp.drupal.org/files/projects/drupal-7.17.tar.gz
tar zxvf drupal-7.17.tar.gz
sudo apt-get install -y apache2 php5-pgsql php5-gd libapache2-mod-php5 php-apc
sudo mkdir /var/www/drupal
sudo mv drupal-7.17/* drupal-7.17/.htaccess /var/www/drupal
sudo cp /var/www/drupal/sites/default/default.settings.php /var/www/drupal/sites/default/settings.php
sudo chown www-data:www-data /var/www/drupal/sites/default/settings.php
sudo mkdir /var/www/drupal/sites/default/files
sudo chown www-data:www-data /var/www/drupal/sites/default/files/
sudo service apache2 restart
{% endhighlight %}

The final piece of software we need is the Akiban database module for
Drupal. Right now, this module is a [sandbox project on
drupal.org][akiban_drupal] so the only way to download it is to check it
out with `git`:

{% highlight console %}
sudo apt-get install -y git
git clone http://git.drupal.org/sandbox/posulliv/1835778.git akiban
cd akiban
git checkout 7.x
cd ../
sudo cp -R akiban /var/www/drupal/includes/database/.
sudo chown -R www-data:www-data /var/www/drupal/includes/database/akiban
{% endhighlight %}

Notice we had to switch to the `7.x` branch. The `master` branch in this
repository is for running the module with Drupal 8.

The last thing which needs to be done is apply a tiny patch to Drupal
core. This patch only avoids the creation of 2 indexes in the `menu`
module. These index defitions are not compatible with Akiban with our
current release. Its likely this will be resolved in a future Akiban
release and so the need for this patch will be removed:

{% highlight console %}
sudo cp akiban/core.patch /var/www/drupal
cd /var/www/drupal
sudo patch -p1 < core.patch
cd
{% endhighlight %}

Drupal 7 can now be installed as you normally would. Just make sure to
select Akiban as the database during installation!

After installation completes successfully we want to group the tables
and gather statistics for out cost-based optimizer. 2 SQL scripts are
provided to achieve this. They can be run using `psql` as so:

{% highlight console %}
psql -h localhost -p 15432 drupal -f akiban/grouping.sql
psql -h localhost -p 15432 drupal -f akiban/gather_stats.sql
{% endhighlight %}

The commands above assume `drupal` is the name of schema in which Drupal
was installed. That should obviously be changed to the name of the
schema you specified during installation.

Thats it! You now have a bare Drupal 7 site running on the Akiban
database! I have some plans for more posts in the coming weeks. In particular,
some things I plan on covering are how to migrate a Drupal site running
on MySQL to Akiban and how to use Akiban as a query accelerator for a
Drupal site similar to the use case in the [post][dries_post] Dries
wrote. I'll also show what is possible with the REST access that we
enable straight to our database (hint: its on port 8091).

If there is anything you would like more information on, please let me
know in the comments or hit me up on [twitter][my_twitter] and I'd be
more than happy to dig in. We also have a [public mailing
list][mailing_list] for the Akiban project and I'd encourage anyone
who's interested to subscribe to that list and let us know how we're
doing!

[mailing_list]: https://groups.google.com/a/akiban.com/d/forum/akiban-user)
[downloads]: http://akiban.com/downloads
[dries_post]: http://buytaert.net/using-the-akiban-database-with-drupal
[my_twitter]: https://twitter.com/intent/user?screen_name=posulliv
[docs_link]: http://www.akiban.com/ak-docs/admin/server/server.config.html
[akiban_drupal]: http://drupal.org/sandbox/posulliv/1835778
