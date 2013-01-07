--- 
title: Field Storage Tests with Drupal 7
layout: post
category: planet drupal
---

I had some spare time this weekend and decided to do some tests with the
field storage layer. I really just wanted to re-produce the results
Moshe Weitzman [published][moshe_link] a while back. I also wanted to
see what the best results I could get were.

# Environment Details

The software and versions used for testing were:

 * EC2 EBS backed Large instance (8GB of memory) in the US-EAST availability zone
 * Ubuntu 12.04 ([ami-fd20ad94][ami_link] as listed in [official ubuntu
AMI's][ubuntu_amis])
 * MySQL 5.5.28
 * PostgreSQL 9.2
 * MongoDB 2.0.4
 * Drupal 7.17
 * Drush 5.1
 * Migrate 2.5
 
I ran tests against both MySQL and PostgreSQL with default settings for
both but I also ran tests where I modified the configuration of both
systems to be optimized for writes.

The configuration options I specified for MySQL when tuning it were:

{% highlight console %}
innodb_flush_log_at_trx_commit=0
innodb_doublewrite=0
log-bin=0
innodb_support_xa=0
innodb_buffer_pool_size=6G
innodb_log_file_size=512M
{% endhighlight %}

The configuration options I specified for PostgreSQL when tuning it
were:

{% highlight console %}
fsync = off
synchronous_commit = off
wal_writer_delay = 10000ms
wal_buffers = 16MB
checkpoint_segments = 64
shared_buffers = 6GB
{% endhighlight %}

# Dataset

The dataset used for the tests comes from the
[migrate_example_baseball][baseball_migrate]
module that comes as part of the migrate module. This dataset contains a
box score from every Major League Baseball game from the year 2000 to
the year 2009. Each year's data is contained in CSV file. Different
components of the box score are saved in fields hence stressing field
storage a lot.

# Results

Average throughput numbers for the various configurations I tested are
shown in the table below.

<table border="1">
  <tr>
    <th>Environment</th>
    <th>Average Throughput</th>
  </tr>
  <tr>
    <td>Default MySQL</td>
    <td>1932 nodes / minute</td>
  </tr>
  <tr>
    <td>Default PostgreSQL</td>
    <td>1649 nodes / minute</td>
  </tr>
  <tr>
    <td>Tuned MySQL</td>
    <td>3024 nodes / minute</td>
  </tr>
  <tr>
    <td>Tuned PostgreSQL</td>
    <td>1772 nodes / minute</td>
  </tr>
  <tr>
    <td>Default MySQL with MongoDB</td>
    <td>4609 nodes / minute</td>
  </tr>
  <tr>
    <td>Default PostgreSQL with MongoDB</td>
    <td>4810 nodes / minute</td>
  </tr>
  <tr>
    <td>Tuned MySQL with MongoDB</td>
    <td>7671 nodes / minute</td>
  </tr>
  <tr>
    <td>Tuned PostgreSQL with MongoDB</td>
    <td>5911 nodes / minute</td>
  </tr>
</table>

The image below shows the results graphically for different environments
I tested. The Y axis is throughput (node per minute) with the X axis specifying the CSV
file (corresponding to a MLB year) being imported.

<div>
  <img alt="Throughput numbers." src="/images/node_thruput.png"/>
</div>
<br>

# Conclusion

Its pretty obvious from glancing at the results above that using MongoDB
for field storage results in the best throughput. Tuned MySQL using
MongoDB for field storage gave me the best results. This is consistent
with what Moshe reported in his original article as well.

What was very interesting to me was the PostgreSQL numbers. The overhead
of having a table per field with the default SQL field storage seems to
be very high with PostgreSQL. Its interesting to see how much better an
optimized PostgreSQL does when using MongoDB for field storage.

After performing these tests, one experiment I really want to try now is
to create a field storage module for PostgreSQL that uses the [JSON data
type][postgres_json] included in the 9.2 release. Hopefully, I will get
some spare time in the coming week or two to work on that.


[moshe_link]: http://cyrve.com/mongodb
[postgres_json]: http://wiki.postgresql.org/wiki/What%27s_new_in_PostgreSQL_9.2#JSON_datatype
[ami_link]: https://console.aws.amazon.com/ec2/home?region=us-east-1#launchAmi=ami-fd20ad94
[ubuntu_amis]: http://cloud-images.ubuntu.com/releases/precise/release/
[baseball_migrate]: http://drupalcode.org/project/migrate.git/tree/refs/heads/7.x-2.x:/migrate_example_baseball
