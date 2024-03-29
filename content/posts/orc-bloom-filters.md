---
title: "ORC bloom filters in Trino"
date: 2022-03-03T08:28:51-05:00
draft: false
---

> This article was written using the 371 Trino release.

Predicate pushdown is a great feature in Trino but there are times when a 
predicate is pushed down by the Hive connector that does not result in any
data being filtered. This article will discuss using bloom filters to improve
the effectiveness of predicate pushdown for equality or `IN` predicates. 

Bloom filters are a probabilistic data structure used for set membership tests.
I suggest reading the [wikipedia article](https://en.wikipedia.org/wiki/Bloom_filter)
if interested in more details on the data structure.

Bloom filters are used in ORC files to help increase the effectiveness of predicate
pushdown by allowing Trino to skip a stripe if the bloom filter indicates the stripe
does not contain any of the values in the predicate. Bloom filters are only effective
for this purpose for equality or `IN` predicates.

When you are creating your table in Trino, you must specify what columns
to create a bloom filter on. For example:

```
CREATE TABLE t1 (
    c1 VARCHAR,
    c2 VARCHAR
) WITH (
    ORC_BLOOM_FILTER_COLUMNS = ARRAY['c2']
)
```

Multiple columns can be specified to create bloom filters on. Once the bloom
filter columns are defined, then Trino will ensure to write bloom filters to
ORC files when writes occur through Trino.

The ORC reader used by the Hive connector in Trino does not take advantage of
bloom filters by default. The configuration property `hive.orc.bloom-filters.enabled`
can be set to true in the Hive catalog `properties` file to enable them globally.

A catalog ession variable, `<catalog_name>.orc_bloom_filters_enabled`, also exists
to enable the use of ORC bloom filters when reading at the session level.

Let's create a small example table to demonstrate what we have discussed. 

```
CREATE TABLE inbloom WITH (
ORC_BLOOM_FILTER_COLUMNS = ARRAY['clerk']
) AS SELECT * FROM tpch.sf10.orders;
```

The above will create a table with 15,000,000 rows and result in a single ORC
file being written (I am testing on a single node cluster):

```
$ ls -ltrh
total 722944
-rw-r--r--  1 posulliv  staff   342M Mar  2 20:47 20220303_014659_00005_tdefz_e5d88ad9-3b79-4599-a3dd-57a494adc917
$
```

We have a 342 MB ORC file. In case you are wondering what the storage overhead
of bloom filters is, I created the same table using the same source data without
bloom filters and the resulting ORC file was 337 MB. So approximately 5MB
overhead for a single string column with small values in a 15,000,000 row table.

Next, we can use [ORC tools](https://orc.apache.org/docs/java-tools.html) to
inspect the metadata for the table's ORC file:

```
orc-tools meta 20220303_014659_00005_tdefz_e5d88ad9-3b79-4599-a3dd-57a494adc917
```

This will first display metadata for the file:

```
Processing data file 20220303_014659_00005_tdefz_e5d88ad9-3b79-4599-a3dd-57a494adc917 [length: 358488054]
Structure for 20220303_014659_00005_tdefz_e5d88ad9-3b79-4599-a3dd-57a494adc917
File Version: 0.12 with TRINO_ORIGINAL by Trino
Rows: 15000000
Compression: ZLIB
Compression size: 262144
Calendar: Julian/Gregorian
Type: struct<orderkey:bigint,custkey:bigint,orderstatus:varchar(1),totalprice:double,orderdate:date,orderpriority:varchar(15),clerk:varchar(15),shippriority:int,comment:varchar(79)>
```

Next, it will display metadata for all the stripes that are contained within
the ORC file:

```
Stripe Statistics:
  Stripe 1:
    Column 0: count: 2777169 hasNull: true
    Column 1: count: 2777169 hasNull: true min: 1 max: 56992871 sum: 78657054016777
    Column 2: count: 2777169 hasNull: true min: 1 max: 1499999 sum: 2081256868144
    Column 3: count: 2777169 hasNull: true min: F max: P sum: 2777169
    Column 4: count: 2777169 hasNull: true min: 839.04 max: 541620.62 sum: 0.0
    Column 5: count: 2777169 hasNull: true min: Hybrid AD 1992-01-01 max: Hybrid AD 1998-08-02
    Column 6: count: 2777169 hasNull: true min: 1-URGENT max: 5-LOW sum: 23327096
    Column 7: count: 2777169 hasNull: true min: Clerk#000000001 max: Clerk#000010000 sum: 41657535
    Column 8: count: 2777169 hasNull: true min: 0 max: 0 sum: 0
    Column 9: count: 2777169 hasNull: true
  Stripe 2:
    Column 0: count: 2777245 hasNull: true
    Column 1: count: 2777245 hasNull: true min: 710244 max: 57671143 sum: 80234653190189
    Column 2: count: 2777245 hasNull: true min: 1 max: 1499999 sum: 2082256003803
    Column 3: count: 2777245 hasNull: true min: F max: P sum: 2777245
    Column 4: count: 2777245 hasNull: true min: 850.97 max: 558289.17 sum: 0.0
    Column 5: count: 2777245 hasNull: true min: Hybrid AD 1992-01-01 max: Hybrid AD 1998-08-02
    Column 6: count: 2777245 hasNull: true min: 1-URGENT max: 5-LOW sum: 23329165
    Column 7: count: 2777245 hasNull: true min: Clerk#000000001 max: Clerk#000010000 sum: 41658675
    Column 8: count: 2777245 hasNull: true min: 0 max: 0 sum: 0
    Column 9: count: 2777245 hasNull: true
  Stripe 3:
    Column 0: count: 2777244 hasNull: true
    Column 1: count: 2777244 hasNull: true min: 1452544 max: 58349283 sum: 81644165110623
    Column 2: count: 2777244 hasNull: true min: 1 max: 1499999 sum: 2081644105671
    Column 3: count: 2777244 hasNull: true min: F max: P sum: 2777244
    Column 4: count: 2777244 hasNull: true min: 853.54 max: 558822.56 sum: 0.0
    Column 5: count: 2777244 hasNull: true min: Hybrid AD 1992-01-01 max: Hybrid AD 1998-08-02
    Column 6: count: 2777244 hasNull: true min: 1-URGENT max: 5-LOW sum: 23328745
    Column 7: count: 2777244 hasNull: true min: Clerk#000000001 max: Clerk#000010000 sum: 41658660
    Column 8: count: 2777244 hasNull: true min: 0 max: 0 sum: 0
    Column 9: count: 2777244 hasNull: true
  Stripe 4:
    Column 0: count: 2773472 hasNull: true
    Column 1: count: 2773472 hasNull: true min: 2162627 max: 59092385 sum: 85207026906413
    Column 2: count: 2773472 hasNull: true min: 1 max: 1499999 sum: 2080071040019
    Column 3: count: 2773472 hasNull: true min: F max: P sum: 2773472
    Column 4: count: 2773472 hasNull: true min: 847.35 max: 557664.53 sum: 0.0
    Column 5: count: 2773472 hasNull: true min: Hybrid AD 1992-01-01 max: Hybrid AD 1998-08-02
    Column 6: count: 2773472 hasNull: true min: 1-URGENT max: 5-LOW sum: 23299221
    Column 7: count: 2773472 hasNull: true min: Clerk#000000001 max: Clerk#000010000 sum: 41602080
    Column 8: count: 2773472 hasNull: true min: 0 max: 0 sum: 0
    Column 9: count: 2773472 hasNull: true
  Stripe 5:
    Column 0: count: 2776760 hasNull: true
    Column 1: count: 2776760 hasNull: true min: 2872967 max: 59802338 sum: 86528639033680
    Column 2: count: 2776760 hasNull: true min: 1 max: 1499999 sum: 2083444658252
    Column 3: count: 2776760 hasNull: true min: F max: P sum: 2776760
    Column 4: count: 2776760 hasNull: true min: 838.05 max: 550142.18 sum: 0.0
    Column 5: count: 2776760 hasNull: true min: Hybrid AD 1992-01-01 max: Hybrid AD 1998-08-02
    Column 6: count: 2776760 hasNull: true min: 1-URGENT max: 5-LOW sum: 23333044
    Column 7: count: 2776760 hasNull: true min: Clerk#000000001 max: Clerk#000010000 sum: 41651400
    Column 8: count: 2776760 hasNull: true min: 0 max: 0 sum: 0
    Column 9: count: 2776760 hasNull: true
  Stripe 6:
    Column 0: count: 1118110 hasNull: true
    Column 1: count: 1118110 hasNull: true min: 3567236 max: 60000000 sum: 37728334242318
    Column 2: count: 1118110 hasNull: true min: 1 max: 1499999 sum: 837930764822
    Column 3: count: 1118110 hasNull: true min: F max: P sum: 1118110
    Column 4: count: 1118110 hasNull: true min: 843.3 max: 558702.81 sum: 0.0
    Column 5: count: 1118110 hasNull: true min: Hybrid AD 1992-01-01 max: Hybrid AD 1998-08-02
    Column 6: count: 1118110 hasNull: true min: 1-URGENT max: 5-LOW sum: 9391489
    Column 7: count: 1118110 hasNull: true min: Clerk#000000001 max: Clerk#000010000 sum: 16771650
    Column 8: count: 1118110 hasNull: true min: 0 max: 0 sum: 0
    Column 9: count: 1118110 hasNull: true
```

This shows us the file has 6 stripes of row data. For each stripe, we can see
that the `min` and `max` for each column is maintained in the stripe metadata.

We can see from this that the data is sorted by column 1 which in this table is
`orderkey`. Other column values are distributed randomly over all stripes as you
can see the `min` and `max` for all other columns is the same in all stripes. 

What this means for predicate pushdown is that any predicate which is pushed down
that is not on `orderkey` will not be able to skip any stripes and all rows will
be read and pulled back into Trino. That is, unless you have a bloom filter for
a column in a predicate.

Now if we look at some of the information for the first stripe we see:

```
Stripes:
  Stripe: offset: 3 data: 64183456 rows: 2777169 tail: 210 index: 2199248
    Stream: column 1 section ROW_INDEX start: 3 length 6115
    Stream: column 2 section ROW_INDEX start: 6118 length 4650
    Stream: column 3 section ROW_INDEX start: 10768 length 2790
    Stream: column 4 section ROW_INDEX start: 13558 length 4165
    Stream: column 5 section ROW_INDEX start: 17723 length 1852
    Stream: column 6 section ROW_INDEX start: 19575 length 2539
    Stream: column 7 section ROW_INDEX start: 22114 length 2451
    Stream: column 7 section BLOOM_FILTER_UTF8 start: 24565 length 2161731
    Stream: column 8 section ROW_INDEX start: 2186296 length 1490
    Stream: column 9 section ROW_INDEX start: 2187786 length 11465
```

Notice the bloom filter for column 7 which in this case is the `clerk` column
we create the bloom filter on.

Now let's see how this effects queries from Trino. Let's try a query with a
predicate that will be pushed down on a column which does not have bloom
filter. This is the query we will execute:

```
SELECT * FROM inbloom WHERE custkey = 10011;
```

The source stage with the table scan for this query (generated with
`EXPLAIN ANALYZE VERBOSE`) looks like:

```
 Fragment 1 [SOURCE]
     CPU: 3.77s, Scheduled: 4.74s, Input: 15000000 rows (128.75MB); per task: avg.: 15000000.00 std.dev.: 0.00, Output: 0 rows (0B)
     Output layout: [orderkey, custkey, orderstatus, totalprice, orderdate, orderpriority, clerk, shippriority, comment]
     Output partitioning: SINGLE []
     Stage Execution Strategy: UNGROUPED_EXECUTION
     ScanFilter[table = hive_315_hms:junk:inbloom, grouped = false, filterPredicate = ("custkey" = BIGINT '10011')]
         Layout: [orderkey:bigint, custkey:bigint, orderstatus:varchar(1), totalprice:double, orderdate:date, orderpriority:varchar(
         Estimates: {rows: 15000000 (1.81GB), cpu: 1.81G, memory: 0B, network: 0B}/{rows: 15 (1.88kB), cpu: 3.63G, memory: 0B, netwo
         CPU: 3.77s (100.00%), Scheduled: 4.74s (100.00%), Output: 0 rows (0B)
         connector metrics:
           'Physical input read time' = {duration=488.91ms}
         metrics:
           'Input distribution' = {count=11.00, p01=0.00, p05=0.00, p10=0.00, p25=0.00, p50=1118110.00, p75=2777169.00, p90=2777244.
         Input avg.: 1363636.36 rows, Input std.dev.: 97.23%
         clerk := clerk:varchar(15):REGULAR
         orderkey := orderkey:bigint:REGULAR
         orderstatus := orderstatus:varchar(1):REGULAR
         custkey := custkey:bigint:REGULAR
         totalprice := totalprice:double:REGULAR
         comment := comment:varchar(79):REGULAR
         orderdate := orderdate:date:REGULAR
         orderpriority := orderpriority:varchar(15):REGULAR
         shippriority := shippriority:int:REGULAR
         Input: 15000000 rows (128.75MB), Filtered: 100.00%
```

Notice that all 15,000,000 rows were input to the `ScanFilter` operator. Predicate
pushdown was ineffective.

Now, let's try a query that uses the `orderkey` column as know the data is sorted
by this column in the ORC file. This is the query we will execute:

```
SELECT * FROM inbloom WHERE orderkey in (1, 10, 100, 10000);
```

The source stage with the table scan for this query looks like:

```
 Fragment 1 [SOURCE]
     CPU: 126.12ms, Scheduled: 167.66ms, Input: 10000 rows (102.78kB); per task: avg.: 10000.00 std.dev.: 0.00, Output: 2 rows (244B
     Output layout: [orderkey, custkey, orderstatus, totalprice, orderdate, orderpriority, clerk, shippriority, comment]
     Output partitioning: SINGLE []
     Stage Execution Strategy: UNGROUPED_EXECUTION
     ScanFilter[table = hive_315_hms:junk:inbloom, grouped = false, filterPredicate = ("orderkey" IN (BIGINT '1', BIGINT '10', BIGIN
         Layout: [orderkey:bigint, custkey:bigint, orderstatus:varchar(1), totalprice:double, orderdate:date, orderpriority:varchar(
         Estimates: {rows: 15000000 (1.81GB), cpu: 1.81G, memory: 0B, network: 0B}/{rows: 4 (520B), cpu: 3.63G, memory: 0B, network:
         CPU: 125.00ms (100.00%), Scheduled: 167.00ms (100.00%), Output: 2 rows (244B)
         connector metrics:
           'Physical input read time' = {duration=51.01ms}
         metrics:
           'Input distribution' = {count=11.00, p01=0.00, p05=0.00, p10=0.00, p25=0.00, p50=0.00, p75=0.00, p90=0.00, p95=10000.00,
         Input avg.: 909.09 rows, Input std.dev.: 316.23%
         clerk := clerk:varchar(15):REGULAR
         orderkey := orderkey:bigint:REGULAR
         orderstatus := orderstatus:varchar(1):REGULAR
         custkey := custkey:bigint:REGULAR
         totalprice := totalprice:double:REGULAR
         comment := comment:varchar(79):REGULAR
         orderdate := orderdate:date:REGULAR
         orderpriority := orderpriority:varchar(15):REGULAR
         shippriority := shippriority:int:REGULAR
         Input: 10000 rows (102.78kB), Filtered: 99.98%
```

Notice that the number of input rows to the `ScanFilter` operator is now only
10000 rows. Also notice the connector metric reported for physical input read
time is almost 10 times better. Predicate pushdown was more effective in this case.

Now, let's try a query that uses a predicate on the column where we have a bloom
filter. This is the query we will execute:

```
SELECT * FROM inbloom WHERE clerk = 'Clerk#000000421';
```

We know based on the metadata for the ORC file we examined earlier that the `min`
and `max` values for this column will not be useful for predicate pushdown. So
without a bloom filter on this column, all 15,000,000 rows would be read and
passed as input to the `ScanFilter` operator. Let's see what the source stage
with the table scan looks like with the bloom filter in place:

```
 Fragment 1 [SOURCE]
     CPU: 3.71s, Scheduled: 4.12s, Input: 9706528 rows (907.42MB); per task: avg.: 9706528.00 std.dev.: 0.00, Output: 1607 rows (204
     Output layout: [orderkey, custkey, orderstatus, totalprice, orderdate, orderpriority, clerk, shippriority, comment]
     Output partitioning: SINGLE []
     Stage Execution Strategy: UNGROUPED_EXECUTION
     ScanFilter[table = hive_315_hms:junk:inbloom, grouped = false, filterPredicate = ("clerk" = 'Clerk#000000421')]
         Layout: [orderkey:bigint, custkey:bigint, orderstatus:varchar(1), totalprice:double, orderdate:date, orderpriority:varchar(
         Estimates: {rows: 15000000 (1.81GB), cpu: 1.81G, memory: 0B, network: 0B}/{rows: 1530 (194.04kB), cpu: 3.63G, memory: 0B, n
         CPU: 3.71s (100.00%), Scheduled: 4.12s (100.00%), Output: 1607 rows (204.39kB)
         connector metrics:
           'Physical input read time' = {duration=417.51ms}
         metrics:
           'Input distribution' = {count=11.00, p01=0.00, p05=0.00, p10=0.00, p25=0.00, p50=728110.00, p75=1776760.00, p90=1877245.0
         Input avg.: 882411.64 rows, Input std.dev.: 97.40%
         clerk := clerk:varchar(15):REGULAR
         orderkey := orderkey:bigint:REGULAR
         orderstatus := orderstatus:varchar(1):REGULAR
         custkey := custkey:bigint:REGULAR
         totalprice := totalprice:double:REGULAR
         comment := comment:varchar(79):REGULAR
         orderdate := orderdate:date:REGULAR
         orderpriority := orderpriority:varchar(15):REGULAR
         shippriority := shippriority:int:REGULAR
         Input: 9706528 rows (907.42MB), Filtered: 99.98%
```

Notice the number of input rows to the `ScanFilter` operator is 9706528 rows.
While not as effective as when the predicate was solely on the column which the
data is sorted by, it shows it helped increase the effectiveness of predicate
pushdown. 

Hopefully, this article showed how ORC bloom filters can be useful if you have
a column you expect to frequently filter on with equality or `IN` predicates.
