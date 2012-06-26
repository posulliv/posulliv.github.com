--- 
title: Migrating Drupal 7 Site from MySQL to PostgreSQL on Ubuntu 10.04
layout: post
---

I recently needed to migrate a Drupal 7 site running on a MySQL 5.5 database
to a PostgreSQL 9.1 database. This brief post describes the steps I took to
achieve this. The steps outlined here were only tested on Ubuntu 10.04

First, I installed a fresh copy of PostgreSQL 9.1.

{% highlight bash %}
sudo apt-get install python-software-properties
sudo add-apt-repository ppa:pitti/postgresql
sudo apt-get update
sudo apt-get install postgresql-9.1 libpq-dev
{% endhighlight %}

After the installation is complete, a schema and user account is created for
Drupal.

{% highlight bash %}
sudo su postgres
createuser -D -A -P drupal
createdb --encoding=UTF8 -O drupal drupal
exit
{% endhighlight %}

The above creates a user account named drupal (you will be prompted for a 
password for the user account when running the command) and a schema named
drupal.

Next, PostgreSQL needs to be configured to allow connections from Apache for
Drupal. This is done by modifying the `/etc/postgresql/9.1/main/pg_hba.conf`
file. The following line needs to be commented out or deleted:

{% highlight bash %}
local   all             all                                     peer
{% endhighlight %}

The line to added in this file is:

{% highlight bash %}
host    drupal          drupal          127.0.0.1/32            password
{% endhighlight %}

After this file is modified, PostgreSQL needs to be restarted.

{% highlight bash %}
sudo service postgresql restart
{% endhighlight %}

For the migration, we are going to assume [drush][drush_link] is installed on
the server we will be performing the migration. We are also going to assume 
MySQL and PostgreSQL are running on the same server although this is certainly
not a requirement for these instructions.

The module that performs the real work of the migration is the 
[dbtng_migrator][dbtng_link] module. This module is installed in the same 
manner as any other Drupal module. After the module is installed, the
`settings.php` file for your drupal installation then needs to be modified
to point to your source and destination database. In my case, I updated my
`settings.php` file to look like:

{% highlight php %}
$databases = array (
  'default' => array (
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
  ),
  'dest' => array (
    'default' =>
      array (
        'database' => 'drupal',
        'username' => 'drupal',
        'password' => 'drupal',
        'host' => 'localhost',
        'port' =>'',
        'driver' => 'pgsql',
        'prefix' =>'',
      ),
    ),
);
{% endhighlight %}

As you can see in my case, the default schema that I am currently running on is
a MySQL database and I am planning on migrating to a PostgreSQL database 
running on the same machine.

Now, to perform the migration from the command line using `drush`, its as simple as:

{% highlight bash %}
drush cache-clear drush
drush dbtng-replicate default dest
{% endhighlight %}

When the migration finishes, output similar to the following will be seen (this
is just a small portion of the output):

{% highlight bash %}
$ drush dbtng-replicate default dest
...
cache_update successfully migrated.                    [status]
authmap successfully migrated.                         [status]
role_permission successfully migrated.                 [status]
role successfully migrated.                            [status]
users successfully migrated.                           [status]
users_roles successfully migrated.                     [status]
$
{% endhighlight %}

Finally, after the database migration is successfully completed, the 
`settings.php` file needs to be updated to point to the new database. In my
case, the database settings after my migration looked like:

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
      'driver' => 'pgsql',
      'prefix' => '',
    ),
  ),
);
{% endhighlight %}

That was it for my migration. Granted, I had a small drupal site to migrate and
the only additional modules I had installed were the views and devel modules so
I did not need to worry about contributed modules working with the PostgreSQL
database. Next step would be to be configure PostgreSQL in a more optimal 
which I did not go in to here.

[drush_link]: http://drupal.org/project/drush
[dbtng_link]: http://drupal.org/project/dbtng_migrator
