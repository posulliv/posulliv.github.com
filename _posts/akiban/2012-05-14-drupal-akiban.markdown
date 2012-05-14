--- 
title: Akiban Server Progress with Drupal 7
layout: post
---

The call for papers for [DrupalCon Munich][drupalcon] closed on Friday and I
[submitted][my_submission] a session related to the work I'm doing on 
developing a database module for the Akiban Server with Drupal 7. That work
has not been open sourced yet but will be before August. We also plan on 
open sourcing and releasing the Akiban Server for public download by August
as well. The end result of this work will be a database driver for the Akiban
Server that will allow Drupal 7 to run on Akiban.

In this post, I wanted to briefly show the type of results I've been seeing
from running Drupal on Akiban. To do this, I constructed a simple view using
the Views module and benchmarked the query that resulted from this view.

# Environment Setup

All results were gathered on EC2 instances. The base AMI used for these
results is an official AMI of Ubuntu 10.04 provided by [Canonical][images].
The particular AMI used as the base image for the results gathered in this post
was [ami-0baf7662][ami_link].

Images used were all launched in the US-EAST-1A availability zone and were
large instance types. After launching this base image I installed MySQL 5.6
and Drupal 7.12. The steps I took to install these components along with the
`my.cnf` file I used for MySQL are outlined in this [gist][ami_gist].

I also created an AMI from the running instance after all the steps outlined
were performed. This [AMI][full_ami] has MySQL 5.6 installed along with Drupal
7.12 and data generated with drush.

The Akiban AMI cannot be made available for general download yet since we have
not open-sourced our stack as of this time. Once our stack has been open-sourced
I will update this post with a link to an AMI that can be downloaded. However, if
you are interested in seeing the results here for yourself, feel free to contact 
me and I should be able to grant access to an EC2 instance for testing.

## Data Generation

I used [drush][drush_link] and the [devel][devel_link] modules to generate data
so the view would be operating on some data. I generated the following data:

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

# View and SQL Query

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

# Performance Comparison

The response time of the query in Akiban versus MySQL is shown below.

<div>
  <img alt="Reponse time comparison." src="/images/drupal_view_response_time.png"/>
</div>

As seen in the image above, Akiban can execute the query in question in 5 ms or 
less whereas MySQL consistently takes 1200 ms to execute the query. In the next
section I'll go into details of how Akiban executes this query.

Secondly, numbers were obtained using the mysqlslap benchmark tool from MySQL 
to demonstrate how Akiban performs versus MySQL with varying degrees of concurrency.

<div>
  <img alt="Throughput comparison." src="/images/drupal_view_throughput.png"/>
</div>

# MySQL Execution Plan

Using Maatkit to visualize the MySQL execution plan, we get:

{% highlight bash %}
JOIN
+- Filter with WHERE
|  +- Bookmark lookup
|     +- Table
|     |  table          node_comment_statistics
|     |  possible_keys  PRIMARY,comment_count
|     +- Unique index lookup
|        key            node_comment_statistics->PRIMARY
|        possible_keys  PRIMARY,comment_count
|        key_len        4
|        ref            drupal.node.nid
|        rows           1
+- Table scan
   +- TEMPORARY
      table          temporary(node)
      +- Filter with WHERE
         +- Bookmark lookup
            +- Table
            |  table          node
            |  possible_keys  PRIMARY,node_status_type
            +- Index scan
               key            node->node_created
               possible_keys  PRIMARY,node_status_type
               key_len        4
               rows           100
{% endhighlight %}

MySQL chooses to start from the node table and scans an index on the created 
column. A temporary table is then created in memory to store the results of 
this index scan. The items stored in the temporary table are then processed to 
eliminate duplicates (for the DISTINCT). For each distinct row in the temporary
table, MySQL then performs a join to the `node_comment_statistics` table by 
performing an index lookup using its primary key.

# Akiban Execution Plan

The tables involved in the query fall into a single table group in Akiban - 
the node group. Grouping is explained by our CTO in this [post][grouping_post]
and that post includes a grouping for Drupal where you can see the node group.
For this query, it means all joins within the node group are executed with 
essentially zero cost. It also allows for the creation of Akiban group indexes. 
A group index is an index that can span multiple tables along a single branch 
within a table group.

A covering group index for this query is:

{% highlight bash %}
CREATE INDEX cvr_gi ON node
(
  node.status,
  node.comment,
  node.created,
  node.nid,
  node_comment_statistics.comment_count,
  node_comment_statistics.nid,
  node.title
) USING LEFT JOIN
{% endhighlight %}

Notice that the `node.created` column is included in this index so a sort could 
be avoided.

The other large advantage Akiban brings when executing this query is the query
optimizer is intelligent enough to determine that the DISTINCT is not required
in the query due to the 1-to-1 mapping between `node` and `node_comment_statistics`
and the fact that an INNER JOIN is being performed between these 2 tables.

{% highlight bash %}
Limit_Default(limit=50: project([Field(6), Field(3), Field(4), Field(2)]))
  project([Field(6), Field(3), Field(4), Field(2)])
    Select_HKeyOrdered(Index(cvr_gi(BoolLogic(AND -> Field(3) >= Literal(111), Field(4) >= Literal(2) -> BOOL))
      IndexScan_Default(Index(cvr_gi(>=UnboundExpressions[Literal(1), Literal(2)],<=UnboundExpressions[Literal(1), Literal(2)]))
{% endhighlight %}

The above execution plan is in the Akiban format. In this format, you read
the plan like a tree so we start from the leaf nodes. The above plan starts
with a scan of the `cvr_gi` index using the `node.status` and `node.comment`
predicates. It then filters rows from this scan (the `Select_HKeyOrdered`
operator performs this filtering) before limiting the results to the size
of the result set requested.

# Conclusion

To wrap up, I briefly showed some of the performance benefits we are seeing
when running Drupal 7 on the Akiban Server. In the not too distant future,
we will be open sourcing our stack here at Akiban and providing downloads of
the Akiban Server. I will also be making the database driver for the Akiban 
Server for Drupal 7 available for download on drupal.org once its complete.

If you are interested in trying this out yourself or want to verify the results
before this work becomes publically available, feel free to contact me and I
should be able to set you up with access to an EC2 instance so you try if for 
yourself.

[drupalcon]: http://munich2012.drupal.org/
[my_submission]: http://munich2012.drupal.org/program/sessions/building-new-database-driver-drupal-7
[images]: http://cloud-images.ubuntu.com/releases/10.04/release
[ami_link]: https://console.aws.amazon.com/ec2/home?region=us-east-1#launchAmi=ami-0baf7662
[full_ami]: https://console.aws.amazon.com/ec2/home?region=us-east-1#launchAmi=ami-2eef4a47
[drush_link]: http://drupal.org/project/drush
[devel_link]: http://drupal.org/project/devel
[ami_gist]: https://gist.github.com/2691521
[view_shot]: /images/view_screen_shot.png
[grouping_post]: http://www.akiban.com/blog/2011/04/18/grouping_explained
