---
title: "Notes on writing with the Hive connector in Trino"
date: 2022-02-01T08:27:52-05:00
draft: false
---

File size is probably the single largest contributor to poor query performance
that I see when working with Trino. In this post, I wanted to cover the case
where we are writing data through Trino using the
[Hive connector](https://trino.io/docs/current/connector/hive.html) and how
to control the size of files created in that case.

These notes are based on the latest Trino release at the time of writing - 370.
Where appropriate, I have linked to open github issues that may change some of
the behavior discussed here.

In this post, first we'll discuss some of the pieces that affect file size
when writing through Trino and then we'll show some examples to get a feel for
how this works in practice.

# Writer Scaling

By default in Trino, the number of writer tasks is static. Trino will schedule
a writer task on every node in the cluster up to `hash_partition_count` which
defaults to 100. Writer scaling is a feature where Trino first creates a single
writer task. When evaluating whether to add additional writer tasks, Trino
uses the following metrics:

* minimum size of files to be created. This is configured by `writer_min_size`
  which defaults to 32MB
* current number of workers writer tasks are running on
* total amount of physical bytes written so far
* percentage of source tasks that have overutilized output buffers

If at least 50% of the source tasks have output buffers that are overutilized
(this is used as an indication that writing is a bottleneck) and the total
number of physical bytes written so far is greater than or equal to
`current_worker_tasks * writer_min_size` than an additional writer task
is scheduled. 

There is an [open PR](https://github.com/trinodb/trino/pull/10614) to enable
writer scaling by default.

# Preferred write partitioning

By default, Trino creates a writer per partition on each worker. So if you
are writing 10 partitions in a single write operation, there will be
`10 * num_of_workers` files created. 

With preferred write partitioning, Trino will create a single writer for each
partition. Files for a partition will be written until they reach the target
file size. The target file size defaults to 1GB and can be configured with the
`hive.target-max-file-size` property.

Preferred write partitioning is enabled by default in Trino but only kicks in
once the number of partitions to write is greater than
`preferred-write-partitioning-min-number-of-partitions`. This property defaults
to 50.

Preferred write partitioning can be problematic if you are writing many partitions
but you have some data skew. That is, a small number of the partitions you are 
writing have significantly more data than the rest. In this case, you will
see poor throughput as the write operation will be bottlenecked on the few 
partitions that have lots of data.

Unfortunately, writer scaling does not work when preferred write partitioning
is enabled. There is an [open github issue](https://github.com/trinodb/trino/issues/10791)
to address this limitation.

One option for this scenario is to write these individual partitions as a single
write operation i.e. INSERT and enable writer scaling.

# Other considerations

By default, a writer task has one writer but Trino has an option to allow you
to configure multiple writers per writer task. This is controlled by the 
`task_writer_count` session property or `task.writer-count` system property. Each
additional writer that is added to a writer task will write its own file.

Hive writers cannot open more than 100 partitions by default. This is configurable
with `hive.max-partitions-per-writers`. This is one of the reasons why preferred
write partitioning kicks in when you are writing 50 partitions by default. The
idea is to prevent query failure due to too many open writers. An 
[open github issue](https://github.com/trinodb/trino/issues/10756) exists to 
take this into account when considering whether to use preferred write
partitioning or not.

# Examples

Lets go through some examples to get a better feel for how some of this works
in practice. All these examples were run on a 20 node cluster with 1 coordinator
and 19 workers. We will use the `sf100.orders` table as input from the
[tpch](https://trino.io/docs/current/connector/tpch.html) connector.

## Unpartitioned tables

Lets start with the default values for all configuration properties writing
to an unpartitioned table and see what happens. We are going to execute
the following SQL statement to write some data:

```
CREATE TABLE hive.schema.orders AS
SELECT * from tpch.sf100.orders;
```

This will create a table with 150 million rows. Now lets see what files make
up the table along with their respective file sizes.

```
trino> SELECT DISTINCT("$path"), "$file_size"/1024/1024 "file size (MB)"
    -> FROM hive.schema.orders;
                   $path                                                   | file size (MB)
---------------------------------------------------------------------------+----------------
 s3://bucket/schema/orders/000000_1148970250376273816915470453360745006588 |             68
 s3://bucket/schema/orders/000000_1215123384347621954917352838970147489146 |            218
 s3://bucket/schema/orders/000000_94932387121933732399061307661938279715   |            223
 s3://bucket/schema/orders/000000_117806137078366536011610830131126485742  |            215
 s3://bucket/schema/orders/000000_1001153647564003259415894971498455909464 |            231
 s3://bucket/schema/orders/000000_133414678567723366599987854974243915598  |            218
 s3://bucket/schema/orders/000000_104241354575902948509585735493038720361  |            200
 s3://bucket/schema/orders/000000_9959593748156202080139674613535097330    |            212
 s3://bucket/schema/orders/000000_934969781173770046110569100158810998349  |            170
 s3://bucket/schema/orders/000000_116238996385648034174033471464866464229  |             93
 s3://bucket/schema/orders/000000_1089771682823928534210552029250628502661 |             76
 s3://bucket/schema/orders/000000_124255962216982642672834186959532804536  |            232
 s3://bucket/schema/orders/000000_11917984803501896447758314434888550646   |             95
 s3://bucket/schema/orders/000000_1257820106788810439610628825335490890891 |            223
 s3://bucket/schema/orders/000000_136162185143624326563707220924434368862  |            230
 s3://bucket/schema/orders/000000_100091554983688721474073407018834215054  |             76
 s3://bucket/schema/orders/000000_1256622394392217552415841354466181267646 |            238
 s3://bucket/schema/orders/000000_1219136186713346171415531183136280889695 |            240
 s3://bucket/schema/orders/000000_9637899140263774860499238271213719254    |            232
(19 rows)

trino>
```

Notice there is 19 files created as expected since as we mentioned earlier,
Trino will schedule a writer task on every node in the cluster up to
`hash_partition_count`. 

Lets drop the table and set some session properties now:

```
DROP TABLE hive.schema.orders;
SET SESSION scale_writers=true;
CREATE TABLE hive.schema.orders AS
SELECT * from tpch.sf100.orders;
```

If you examine the files created, you will see there is almost no difference.
There will be 19 files created pretty much the same sizes as when `scale_writers`
was `false`. The reason for this is because `writer_min_size` defaults to 32MB.
So we did start with one writer but writer scaling kicked in very quickly and
scaled to one writer on every node in the cluster.

Lets increase `writer_min_size` and see what happens:

```
DROP TABLE hive.schema.orders;
SET SESSION scale_writers = true;
SET SESSION writer_min_size = '256M';
CREATE TABLE hive.schema.orders AS
SELECT * from tpch.sf100.orders;
```

Now, the file listing for the table looks different:

```
trino> SELECT DISTINCT("$path"), "$file_size"/1024/1024 "file size (MB)"
    -> FROM hive.schema.orders;
                                                 $path                     | file size (MB)
---------------------------------------------------------------------------+----------------
 s3://bucket/schema/orders/000000_1377595777372344627116636555983565637996 |             33
 s3://bucket/schema/orders/000000_99009178714256612358893726592261639547   |             68
 s3://bucket/schema/orders/000000_13472050365964937787172296248786177422   |            106
 s3://bucket/schema/orders/000000_1235983261586334774415807092221720413995 |            247
 s3://bucket/schema/orders/000000_1290934766225256968918093139793381378849 |             44
 s3://bucket/schema/orders/000000_99666591088221896837512665438916461593   |            522
 s3://bucket/schema/orders/000000_1314592899941435688912102934398036230458 |            270
 s3://bucket/schema/orders/000000_93516165430063608919362987023330987077   |             68
 s3://bucket/schema/orders/000000_127796541167598661858541674897111794985  |            179
 s3://bucket/schema/orders/000000_97541421057189906701251290742318121084   |            366
 s3://bucket/schema/orders/000000_96638551161615777301182887331064989471   |            465
 s3://bucket/schema/orders/000000_995172082584028822516636345442201128353  |            896
 s3://bucket/schema/orders/000000_1310607426014842381610388882407432078718 |            134
 s3://bucket/schema/orders/000000_969936561665743341218015719903539776034  |             95
(14 rows)

trino>
```

Now there is 14 files for the table with varying sizes. This is because it
took longer for writer scaling to kick in. Remember writer scaling adds a new
writer when the total amount of bytes written so far is greater than or equal
to `current_worker_tasks * writer_min_size`. So with a larger `writer_min_size`
not as many writers were required.

Finally, lets see what happens if we set `task_writer_count` to 4. 

```
DROP TABLE hive.schema.orders;
SET SESSION scale_writers = false;
SET SESSION task_writer_count = 4;
CREATE TABLE hive.schema.orders AS
SELECT * from tpch.sf100.orders;
```

Examining the files in the table now:

```
trino> SELECT DISTINCT("$path"), "$file_size"/1024/1024 "file size (MB)"
    -> FROM hive.schema.orders;
               $path                                                       | file size (MB)
---------------------------------------------------------------------------+----------------
 s3://bucket/schema/orders/000000_1327778650584285583914638612389897650257 |             46
 s3://bucket/schema/orders/000000_94789734096748700767106657631149640245   |             46
 s3://bucket/schema/orders/000000_133316333924262072775421837119926648989  |             47
 s3://bucket/schema/orders/000000_103945055866900400305793036419297658186  |             46
 s3://bucket/schema/orders/000000_1352096330589007547313025749534328638021 |             47
 s3://bucket/schema/orders/000000_11741659409465051430275721966299661714   |             47
 s3://bucket/schema/orders/000000_930015843200006077215938462065578362118  |             48
 s3://bucket/schema/orders/000000_130472521844905959243143795957553317277  |             45
 s3://bucket/schema/orders/000000_1235200687630939159713725338262038529276 |             41
 s3://bucket/schema/orders/000000_94949123118577522958958140797445228575   |             48
 s3://bucket/schema/orders/000000_119717423415929640441547267762871685047  |             45
 s3://bucket/schema/orders/000000_10356034476499632116853388213431584148   |             44
 ...
 s3://bucket/schema/orders/000000_106889506735014793328862626510383760736  |             43
 s3://bucket/schema/orders/000000_127973413398668769087683224367368388632  |             46
 s3://bucket/schema/orders/000000_9479488288009668113409431449173704708    |             48
 s3://bucket/schema/orders/000000_1044722728954301272514380956339957024693 |             50
 s3://bucket/schema/orders/000000_137819937315507510504351574064435249970  |             43
(76 rows)

trino>
```

I have not shown all files in the above output but now we have 76 files. This
matches what we would expect as we have 19 workers and 4 writers per writer
task. Notice how files are also smaller now.

## Partitioned tables

We are going to create a table that is partitioned by the `orderstatus` column
in the `orders` table. First, lets see how many partitions there will be and
how many rows for each partition:

```
trino> SELECT orderstatus, count(*) FROM tpch.sf100.orders GROUP BY orderstatus;
 orderstatus |  _col1
-------------+----------
 O           | 73086053
 F           | 73072502
 P           |  3841445
(3 rows)

trino>
```

There will be 3 partitions. `O` and `F` will have the same amount of data and `P`
has significantly less.

Lets start with the default values for all configuration properties writing
to an partitioned table and see what happens. We are going to execute
the following SQL statement to write some data:

```
CREATE TABLE hive.schema.orders_part WITH (
    PARTITIONED_BY = ARRAY['orderstatus']
) AS
SELECT
  orderkey, custkey,
  totalprice, orderdate,
  orderpriority, clerk,
  shippriority, "comment", orderstatus
FROM tpch.sf100.orders;
```

Lets look at what files make up the table:

```
trino> SELECT DISTINCT("$path"), "$file_size"/1024/1024 "file size (MB)"
    -> FROM hive.schema.orders_part;
                         $path                                                                | file size (MB)
----------------------------------------------------------------------------------------------+----------------
 s3://bucket/schema/orders_part/orderstatus=O/000000_128584668682339574879802670643519570829  |             96
 s3://bucket/schema/orders_part/orderstatus=P/000000_123319395652705810246138819005516890606  |              5
 s3://bucket/schema/orders_part/orderstatus=F/000000_112406935902812657386577229574238848654  |             93
 s3://bucket/schema/orders_part/orderstatus=P/000000_127316066648024189353330844171795252872  |              3
 s3://bucket/schema/orders_part/orderstatus=P/000000_107837501527688671693884590968487690637  |              5
 s3://bucket/schema/orders_part/orderstatus=O/000000_112652705648896950256952745918657939195  |             96
 s3://bucket/schema/orders_part/orderstatus=P/000000_96401151262324353316613301189825482478   |              5
 s3://bucket/schema/orders_part/orderstatus=O/000000_1252745054876985227015755303221707622310 |             73
 s3://bucket/schema/orders_part/orderstatus=O/000000_109198811615840855187654035085899155872  |             95
 s3://bucket/schema/orders_part/orderstatus=O/000000_10982354965074499624397721986189051911   |             77
 s3://bucket/schema/orders_part/orderstatus=F/000000_117596718225736561815480560455431177255  |            101
 s3://bucket/schema/orders_part/orderstatus=O/000000_101551444329366153847054119236203530366  |            101
 s3://bucket/schema/orders_part/orderstatus=O/000000_136895592240784148214939346167992699414  |            102
 s3://bucket/schema/orders_part/orderstatus=F/000000_1021403776743514575115577786482170350623 |             66
 s3://bucket/schema/orders_part/orderstatus=P/000000_1276088785191487719511571484253424667019 |              4
...
 s3://bucket/schema/orders_part/orderstatus=O/000000_102010231565598635379308522615862477435  |             95
 s3://bucket/schema/orders_part/orderstatus=P/000000_94698171298649936721502727724916032741   |              5
(57 rows)

trino>
```

I have not shown all files in the above output but you can see that there is 57 
total files. This matches our expectations since we have 3 partitions to write
to and 19 workers to schedule writers on so 57 files.

Next lets see what happens when we use preferred write partitioning. To have 
preferred write partitioning kick in for this table, we need to set
`preferred_write_partitioning_min_number_of_partitions` to 3 or less. So lets
set it to one.

```
DROP TABLE hive.schema.orders_part;
SET SESSION preferred_write_partitioning_min_number_of_partitions = 1;
CREATE TABLE hive.schema.orders_part WITH (
    PARTITIONED_BY = ARRAY['orderstatus']
) AS
SELECT
  orderkey, custkey,
  totalprice, orderdate,
  orderpriority, clerk,
  shippriority, "comment", orderstatus
FROM tpch.sf100.orders;
```

Examing the list of files created for the table now we see:

```
trino> SELECT DISTINCT("$path"), "$file_size"/1024/1024 "file size (MB)"
    -> FROM hive.schema.orders_part;
                       $path                                                                  | file size (MB)
----------------------------------------------------------------------------------------------+----------------
 s3://bucket/schema/orders_part/orderstatus=O/000000_1254472926280513888711848091454450452149 |            692
 s3://bucket/schema/orders_part/orderstatus=F/000000_1068576034620793011018243320222690066787 |            692
 s3://bucket/schema/orders_part/orderstatus=P/000000_126485365865919680615562458566484181697  |             91

trino>
```

Now there is one file created per partition. 

# Summary

These are my individual notes that I have collected while working with Trino.
I am following development of the Iceberg connector and will write up my notes
around writing with Iceberg once I have some more experience with it in real
world deployments. 
