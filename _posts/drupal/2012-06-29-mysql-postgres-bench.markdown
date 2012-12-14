--- 
title: Comparing PostgreSQL 9.1 vs. MySQL 5.6 using Drupal 7.x
layout: post
category: drupal
---

Its tough to come across much information about running Drupal on PostgreSQL
I find beisdes the basics of installing Drupal on PostgreSQL. In particular, 
I'm interested in comparisons of running Drupal on PostgreSQL versus MySQL. 
Previous posts such as this [article][bits2_link] from [2bits][bits2_home] 
compares performance of MySQL versus PostgreSQL on Drupal 5.x and seems a bit 
outdated. This [post][group_link] from the 
[high performance drupal group][hpd_group] is also pretty dated and has
some information with similar comparisons.

In this post, I wanted to run similar tests to what was done in the 
[article][bits2_link] from 2bits but on a more recent version of Drupal - 7.x.
I also wanted to test out a few more complex queries that can get generated 
by the view module and see how they perform in MySQL versus PostgreSQL.

For this post, I used the latest GA version of PostgreSQL and for kicks, I went
with an aplha release of MySQL - 5.6. I would expect to see similar results for
5.5 in tests like this. I didn't use default configurations after installation
since I didn't see much benefit in testing that. The configurations I used for
both systems are documented below.

# Environment Setup

All results were gathered on EC2 instances. The base AMI used for these
results is an official AMI of Ubuntu 10.04 provided by [Canonical][images].
The particular AMI used as the base image for the results gathered in this post
was [ami-0baf7662][ami_link].

Images used were all launched in the US-EAST-1A availability zone and were
large instance types. After launching this base image I installed MySQL 5.6
and Drupal 7.12. The steps I took to install these components along with the
`my.cnf` file I used for MySQL are outlined in this [gist][ami_gist].

The PostgreSQL 9.1 setup I performed on a separate instance along with the
`postgresql.conf` settings I used are outlined in this [gist][pg_gist]. 

APC was installed and its default configuration was used on both servers.

## Data Generation

I used [drush][drush_link] and the [devel][devel_link] modules to generate data.
I generated the following data:

<table>
  <tr>
    <td>users</td><td>50000</td>
  </tr>
  <tr>
    <td>tags</td><td>1000</td>
  </tr>
  <tr>
    <td>vocabularies</td><td>5000</td>
  </tr>
  <tr>
    <td>menus</td><td>5000</td>
  </tr>
  <tr>
    <td>nodes</td><td>100000</td>
  </tr>
  <tr>
    <td>max comments per node</td><td>10</td>
  </tr>
</table>

I generated this data in the MySQL installation first. The data was
then migrated to the PostgreSQL instance using the [dbtng_migrator][dbtng_link]
module. This ensures the same data is used for all tests against MySQL and
PostgreSQL. I covered how to perform this migration in a previous [post][dbtng_post].

## pgbouncer

One additional setup item I performed for PostgreSQL was to install 
[pgbouncer][pgbouncer_link] and configure Drupal to connect through `pgbouncer`
instead of directly to PostgreSQL.

Installation and configuration on Ubuntu 10.04 is straightforward. The steps
to install `pgbouncer` and the configuration I used are outlined in this
[gist][pgb_gist].

The main reason for this change is the ApacheBench based test unfairly favors
MySQL due to its process model. Each connection results in a new thread being
spawned whereas with PostgreSQL, each new connection results in a new process
being forked. The overhead of forking a new process is much larger than spawning
a new thread. I did collect numbers for PostgreSQL without using `pgbouncer` 
and I do report them in the ApacheBench test section below.

`pgbouncer` maintains a connection pool that Drupal connects so
in my `settings.php` file for my Drupal PostgreSQL instance, I modified my 
database settings to be:

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
      'port' => '6432',
      'driver' => 'pgsql',
      'prefix' => '',
    ),
  ),
);
{% endhighlight %}

I performed this configuration step after I generated data in MySQL and migrated
it to PostgreSQL.

# Anonymous Users Testing with ApacheBench

First, loading the front page for each Drupal site 
with the [devel][devel_link] module enabled and reporting on query 
execution times, the following was reported:

<table border="1">
  <tr>
    <th>Database</th><th>Query Exec Times</th>
  </tr>
  <tr>
    <td>MySQL</td><td>Executed 65 queries in 31.69 ms</td>
  </tr>
  <tr>
    <td>PostgreSQL (with pgbouncer)</td>
    <td>Executed 66 queries in 49.84 ms</td>
  </tr>
    <td>PostgreSQL</td>
    <td>Executed 66 queries in 95 ms</td>
  <tr>
  </tr>
</table>

Straight out the gate, we can see there is not much difference here. 31
versus 50 ms is not going to be felt by many end users. If `pgbouncer`
is not used, query execution time is 3 times slower though.

Next, I went to do some simple benchmarks using ApacheBench.
The command used to run `ab` was (the number of concurrent
connections, X, was the only parameter varied):

{% highlight bash %}
ab -c X -n 100 http://drupal.url.com/ 
{% endhighlight %}

The `ab` command was always run from a separate EC2 instance in the same
availability zone and never on the same instance as which Drupal was running.

Results obtained with default Drupal configuration (page cache disabled) but
all other caching enabled are shown in the figure below. The raw numbers are 
presented in the table after the figure.

<div>
  <img alt="First results." src="/images/first_anon_res.png"/>
</div>

<table border="1">
  <tr>
    <th>Database</th><th>c = 1</th><th>c = 5</th><th>c = 10</th>
  </tr>
  <tr>
    <td>MySQL</td><td>11.71</td><td>16.53</td><td>16.28</td>
  </tr>
  <tr>
    <td>PostgreSQL (using pgbouncer)</td><td>8.44</td><td>11.03</td><td>11.10</td>
  </tr>
  <tr>
    <td>PostgreSQL</td><td>4.81</td><td>7.32</td><td>7.22</td>
  </tr>
</table>

The next test was run after all caches were cleared using `drush`. The command
issued was:

{% highlight bash %}
drush cc
{% endhighlight %}

Option 1 was then chosen to clear all caches. This was done before each `ab`
command was run. Results are shown in the figure with raw numbers presented in
the table after the figure.

<div>
  <img alt="Second results." src="/images/second_anon_res.png"/>
</div>

<table border="1">
  <tr>
    <th>Database</th><th>c = 1</th><th>c = 5</th><th>c = 10</th>
  </tr>
  <tr>
    <td>MySQL</td><td>10.50</td><td>14.08</td><td>6.28</td>
  </tr>
  <tr>
    <td>PostgreSQL (using pgbouncer)</td><td>7.92</td><td>9.23</td><td>7.32</td>
  </tr>
  <tr>
    <td>PostgreSQL</td><td>5</td><td>7.04</td><td>6.79</td>
  </tr>
</table>

Finally, the same test was run with Drupal's page cache enabled. Results are
shown in the figure below with raw numbers presented in the table after the
figure.

<div>
  <img alt="Third results." src="/images/third_anon_res.png"/>
</div>

<table border="1">
  <tr>
    <th>Database</th><th>c = 1</th><th>c = 5</th><th>c = 10</th>
  </tr>
  <tr>
    <td>MySQL</td><td>144</td><td>282</td><td>267</td>
  </tr>
  <tr>
    <td>PostgreSQL (using pgbouncer)</td><td>120</td><td>205</td><td>202</td>
  </tr>
  <tr>
    <td>PostgreSQL</td><td>35</td><td>45</td><td>46</td>
  </tr>
</table>

# Views Queries

The [views][views_link] module is known to sometimes generate queries that can
cause performance problems for MySQL.

## Image Gallery View

The first SQL query I want to look is generated by one of the sample templates
that come with the Views module. If you click 'Add view from template' in the
Views module, by default, you will only have 1 template to choose from - the 
Image Gallery template. After creating a view from this template and not 
modifying anything about that view, I see 2 problematic queries being generated.

The first query is a query that counts the number of the rows in the result set
for this view since this is a paginated view. The second query actually retrieves
the results with a LIMIT clause and the appropriate OFFSET dependending on what
page of the results the user is currently on. For this post, we'll just look at
the second query that retries results. That query is:

{% highlight sql %}
SELECT taxonomy_index.tid      AS taxonomy_index_tid, 
       taxonomy_term_data.name AS taxonomy_term_data_name, 
       Count(node.nid)         AS num_records 
FROM   node node 
       LEFT JOIN users users_node 
              ON node.uid = users_node.uid 
       LEFT JOIN field_data_field_image field_data_field_image 
              ON node.nid = field_data_field_image.entity_id 
                 AND ( field_data_field_image.entity_type = 'node' 
                       AND field_data_field_image.deleted = '0' ) 
       LEFT JOIN taxonomy_index taxonomy_index 
              ON node.nid = taxonomy_index.nid 
       LEFT JOIN taxonomy_term_data taxonomy_term_data 
              ON taxonomy_index.tid = taxonomy_term_data.tid 
WHERE  (( ( field_data_field_image.field_image_fid IS NOT NULL ) 
          AND ( node.status = '1' ) )) 
GROUP  BY taxonomy_term_data_name, 
          taxonomy_index_tid 
ORDER  BY num_records ASC 
LIMIT  24 offset 0 
{% endhighlight %}

The response time of the query in MySQL versus PostgreSQL is shown in the 
figure below.

<div>
  <img alt="First query response time results." src="/images/first_query_response_time.png"/>
</div>

As seen in the image above, PostgreSQL can execute the query in question in 300ms
or less whereas MySQL consistently takes 2800 ms to execute the query.

The MySQL execution plan looks like:

{% highlight bash %}
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: field_data_field_image
         type: ref
possible_keys: PRIMARY,entity_type,deleted,entity_id,field_image_fid
          key: PRIMARY
      key_len: 386
          ref: const
         rows: 19165
        Extra: Using where; Using temporary; Using filesort
*************************** 2. row ***************************
           id: 1
  select_type: SIMPLE
        table: node
         type: eq_ref
possible_keys: PRIMARY,node_status_type
          key: PRIMARY
      key_len: 4
          ref: drupal.field_data_field_image.entity_id
         rows: 1
        Extra: Using where
*************************** 3. row ***************************
           id: 1
  select_type: SIMPLE
        table: users_node
         type: eq_ref
possible_keys: PRIMARY
          key: PRIMARY
      key_len: 4
          ref: drupal.node.uid
         rows: 1
        Extra: Using where; Using index
*************************** 4. row ***************************
           id: 1
  select_type: SIMPLE
        table: taxonomy_index
         type: ref
possible_keys: nid
          key: nid
      key_len: 4
          ref: drupal.field_data_field_image.entity_id
         rows: 1
        Extra: NULL
*************************** 5. row ***************************
           id: 1
  select_type: SIMPLE
        table: taxonomy_term_data
         type: eq_ref
possible_keys: PRIMARY
          key: PRIMARY
      key_len: 4
          ref: drupal.taxonomy_index.tid
         rows: 1
        Extra: NULL
{% endhighlight %}

MySQL starts from the `field_date_field_image` table and since there is no
selective predicates in the query, chooses to scan the table using the 
`PRIMARY` key of the table. It then filters the rows scanned using the
`field_image_fid IS NOT NULL` predicate. Since MySQL only has 1 join algorithm,
nested loops, it is used to perform the remainder of the joins. A temporary
table is created in memory to store the results of these joins. This is then 
sorted and the result set limited to the 24 requested.

The PostgreSQL execution plan looks drastically different.

{% highlight bash %}
 Limit  (cost=11712.83..11712.89 rows=24 width=20)
   ->  Sort  (cost=11712.83..11829.24 rows=46564 width=20)
         Sort Key: (count(node.nid))
         ->  HashAggregate  (cost=9946.90..10412.54 rows=46564 width=20)
               ->  Hash Left Join  (cost=6174.69..9597.67 rows=46564 width=20)
                     Hash Cond: (taxonomy_index.tid = taxonomy_term_data.tid)
                     ->  Hash Right Join  (cost=6140.19..8922.92 rows=46564 width=12)
                           Hash Cond: (taxonomy_index.nid = node.nid)
                           ->  Seq Scan on taxonomy_index  (cost=0.00..1510.18 rows=92218 width=16)
                           ->  Hash  (cost=5657.14..5657.14 rows=38644 width=4)
                                 ->  Hash Join  (cost=2030.71..5657.14 rows=38644 width=4)
                                       Hash Cond: (node.nid = field_data_field_image.entity_id)
                                       ->  Seq Scan on node  (cost=0.00..2187.66 rows=76533 width=8)
                                             Filter: (status = 1)
                                       ->  Hash  (cost=1547.66..1547.66 rows=38644 width=8)
                                             ->  Seq Scan on field_data_field_image  (cost=0.00..1547.66 rows=38644 width=8)
                                                   Filter: ((field_image_fid IS NOT NULL) AND ((entity_type)::text = 'node'::text) AND (deleted = 0::smallint))
                     ->  Hash  (cost=22.00..22.00 rows=1000 width=12)
                           ->  Seq Scan on taxonomy_term_data  (cost=0.00..22.00 rows=1000 width=12)
{% endhighlight %}

PostgreSQL has a number of other join algorithms available for use. In 
particular, for this query, the optimizer has decided that a hash join is the
optimal choice.

PostgreSQL starts by scanning the tiny (1000 rows) `taxonomy_term_data` table and
constructing an in-memory hash table (the build phase in a hash join). It then
probes this hash table for possible matches of `taxonomy_index.tid = taxonomy_term_data.tid`
for each row that results from a hash join of `taxonomy_index` and `node`. This 
hash join was a result of the `field_data_field_image` and `node` table being
join with the `field_data_field_image` being used to build a hash table and a 
sequential scan of `node` being used to probe that hash table.
Aggregation is then performed and the result set is then sorted by the aggregated
value (in this case a count of node ids). Finally, the result set is limited to 24.

One neat thing about PostgreSQL is planner nodes can be disabled. So to make
PostgreSQL execute the query in a similar manner to MySQL, I did:

{% highlight bash %}
drupal=> set enable_hashjoin=off;
SET
drupal=> set enable_hashagg=off;
SET
drupal=> set enable_mergejoin=off;
SET
drupal=> 
{% endhighlight %}

And the execution plan PostgreSQL chose then was:

{% highlight bash %}
 Limit  (cost=52438.04..52438.10 rows=24 width=20)
   ->  Sort  (cost=52438.04..52552.82 rows=45913 width=20)
         Sort Key: (count(node.nid))
         ->  GroupAggregate  (cost=50237.67..51155.93 rows=45913 width=20)
               ->  Sort  (cost=50237.67..50352.45 rows=45913 width=20)
                     Sort Key: taxonomy_term_data.name, taxonomy_index.tid
                     ->  Nested Loop Left Join  (cost=0.00..46682.48 rows=45913 width=20)
                           ->  Nested Loop Left Join  (cost=0.00..33783.81 rows=45913 width=12)
                                 ->  Nested Loop  (cost=0.00..18575.38 rows=38644 width=4)
                                       ->  Seq Scan on field_data_field_image  (cost=0.00..1547.66 rows=38644 width=8)
                                             Filter: ((field_image_fid IS NOT NULL) AND ((entity_type)::text = 'node'::text) AND (deleted = 0::smallint))
                                       ->  Index Scan using node_pkey on node  (cost=0.00..0.43 rows=1 width=8)
                                             Index Cond: (nid = field_data_field_image.entity_id)
                                             Filter: (status = 1)
                                 ->  Index Scan using taxonomy_index_nid_idx on taxonomy_index  (cost=0.00..0.36 rows=3 width=16)
                                       Index Cond: (node.nid = nid)
                           ->  Index Scan using taxonomy_term_data_pkey on taxonomy_term_data  (cost=0.00..0.27 rows=1 width=12)
                                 Index Cond: (taxonomy_index.tid = tid)
{% endhighlight %}

The above plan takes 2 seconds to execute against PostgreSQL. You can see it is
very similar to the MySQL plan. It starts with the `field_data_field_image` table
and performs nested loop joins to join the remainder of the tables. In this case,
a sort must be performed before the aggregation that is expensive to perform. 
Using the HashAggregate operator in PostgreSQL would greatly reduce that cost.

So you can see out of the box, PostgreSQL performs much better on this query.

## Simple View

I created a simple view that filters and sorts on content criteria. A screenshot
of my view construction page can be seen [here][view_shot].

The resulting SQL query that gets executed by this view is:

{% highlight sql %}
SELECT DISTINCT node.title                            AS node_title, 
                node.nid                              AS nid, 
                node_comment_statistics.comment_count AS 
                node_comment_statistics_comment_count, 
                node.created                          AS node_created 
FROM   node node 
       INNER JOIN node_comment_statistics node_comment_statistics 
         ON node.nid = node_comment_statistics.nid 
WHERE  (( ( node.status = '1' ) 
          AND ( node.comment IN ( '2' ) ) 
          AND ( node.nid >= '111' ) 
          AND ( node_comment_statistics.comment_count >= '2' ) ))
ORDER  BY node_created ASC 
LIMIT  50 offset 0 
{% endhighlight %}

The response time of the query in MySQL versus PostgreSQL is shown in the 
figure below.

<div>
  <img alt="Second query response time results." src="/images/second_query_response_time.png"/>
</div>

As seen in the image above, PostgreSQL can execute the query in question in 200ms
or less whereas MySQL can take up to 1000 ms to execute the query.

The MySQL execution plan looks like:

{% highlight bash %}
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: node
         type: index
possible_keys: PRIMARY,node_status_type
          key: node_created
      key_len: 4
          ref: NULL
         rows: 100
        Extra: Using where; Using temporary
*************************** 2. row ***************************
           id: 1
  select_type: SIMPLE
        table: node_comment_statistics
         type: eq_ref
possible_keys: PRIMARY,comment_count
          key: PRIMARY
      key_len: 4
          ref: drupal.node.nid
         rows: 1
        Extra: Using where
{% endhighlight %}

MySQL chooses to start from the `node` table and scans an index on the created 
column. A temporary table is then created in memory to store the results of 
this index scan. The items stored in the temporary table are then processed to 
eliminate duplicates (for the `DISTINCT`). For each distinct row in the temporary
table, MySQL then performs a join to the `node_comment_statistics` table by 
performing an index lookup using its primary key.

The PostgreSQL execution plan for this query looks like:

{% highlight bash %}
 Limit  (cost=6207.15..6207.27 rows=50 width=42)
   ->  Sort  (cost=6207.15..6250.75 rows=17441 width=42)
         Sort Key: node.created
         ->  HashAggregate  (cost=5453.36..5627.77 rows=17441 width=42)
               ->  Hash Join  (cost=1985.31..5278.95 rows=17441 width=42)
                     Hash Cond: (node.nid = node_comment_statistics.nid)
                     ->  Seq Scan on node  (cost=0.00..2589.32 rows=38539 width=34)
                           Filter: ((nid >= 111) AND (status = 1) AND (comment = 2))
                     ->  Hash  (cost=1546.22..1546.22 rows=35127 width=16)
                           ->  Seq Scan on node_comment_statistics  (cost=0.00..1546.22 rows=35127 width=16)
                                 Filter: (comment_count >= 2::bigint)
{% endhighlight %}

PostgreSQL chooses to start by scanning the `node_comment_statistics` table
and building an in-memory hash table. This hash table is then probed for possible
mathces of `node.nid = node_comment_statistics.nid` for each row that results 
from a sequential scan of the `node` table. The result of this hash join is
then aggregated (for the `DISTINCT`) before being sorted and limited to 50 rows.

Its worth noting that with out of the box settings, the above query would do
a disk based sort (sort method is viewable using `EXPLAIN ANALYZE` in PostgreSQL).
When doing a disk based sort, the query takes about 450 ms to execute. I was
running all my tests with `work_mem` set to 4MB though which results in a
top-N heapsort being used.

# Conclusion

In my opinion, the only issue with using PostgreSQL as your Drupal database is
that some contributed modules will not work out of the box with that configuration.

Certainly, from a performance point of view, I see no issues with using 
PostgreSQL with Drupal. In fact, for Drupal sites using the Views module
(probably the majority), I would say PostgreSQL is probably even a better
option than MySQL due to its more advanced optimizer and execution engine.
This does assume `pgbouncer` is being used and Drupal is not connecting 
directly to PostgreSQL. Users who do not use `pgbouncer` and perform
simple benchmarks like the ones I did with `ab` are likely to see
poor performance against PostgreSQL.

I'm working a lot with Drupal on PostgreSQL these days. I'll be sure to share
any interesting experiences I have here.

[bits2_link]: http://2bits.com/articles/benchmarking-postgresql-vs-mysql-performance-using-drupal-5x.html
[bits2_home]: http://2bits.com/
[group_link]: http://groups.drupal.org/node/61793
[hpd_group]:  http://groups.drupal.org/high-performance
[drush_link]: http://drupal.org/project/drush
[dbtng_link]: http://drupal.org/project/dbtng_migrator
[dbtng_post]: http://posulliv.github.com/drupal/2012/06/26/migrate-mysql-postgres/
[ami_gist]:   https://gist.github.com/2691521
[pg_gist]:    https://gist.github.com/3012400
[pgbouncer_link]: http://pgfoundry.org/projects/pgbouncer
[pgb_gist]:   https://gist.github.com/3013089
[devel_link]: http://drupal.org/project/devel
[views_link]: http://drupal.org/project/views/
[ami_link]:   https://console.aws.amazon.com/ec2/home?region=us-east-1#launchAmi=ami-0baf7662
[view_shot]: /images/view_screen_shot.png
