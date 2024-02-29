---
title: "Predicate pushdown on parquet files in Trino"
date: 2024-02-27T08:21:42-05:00
draft: false
---

> All examples in this article were run on [Starburst Galaxy](https://galaxy.starburst.io/) with clusters based on trino 432.

# Overview

Predicate pushdown is the term used in Trino to describe when a filter in a
query is “pushed” down to a connector so that it can be used to reduce
the amount of data read from the underlying data source.

Predicate pushdown is performed automatically by Trino when possible,
which is typically whenever a SARGable filter expression is used and the
connector supports predicate pushdown. Without predicate pushdown, the
filtering is performed by Trino on each row after reading all data for
a table via the connector.

For example, take this query executed in Trino against a MySQL catalog:

```
SELECT name FROM customer WHERE acctbal = 4231.45
```

The source stage in the output of `EXPLAIN ANALYZE` looks like:

```
Fragment 1 [SOURCE]
    CPU: 3.70ms, Scheduled: 6.56ms, Blocked 0.00ns (Input: 0.00ns, Output: 0.00ns), Input: 1 row (23B); per task: avg.: 1.00 std.dev.: 0.00, Output: 1 row (23B)
    Output layout: [name]
    Output partitioning: SINGLE []
    TableScan[table = mysql:tpch.customer tpch.customer constraint on [acctbal] columns=[name:varchar(255):TINYTEXT]]
        Layout: [name:varchar(255)]
        Estimates: {rows: ? (?), cpu: ?, memory: 0B, network: 0B}
        CPU: 2.00ms (100.00%), Scheduled: 5.00ms (100.00%), Blocked: 0.00ns (?%), Output: 1 row (23B)
        Input avg.: 1.00 rows, Input std.dev.: 0.00%
        name := name:varchar(255):TINYTEXT
        Input: 1 row (23B), Physical input time: 3.39ms
```

Note that the operator in the source stage is a TableScan operator meaning
there is no filtering occurring in Trino. The other item to note in this source
stage in the number of input rows.

Now lets update our simple example and construct a query on a MySQL catalog
with a predicate that cannot be pushed down:

```
SELECT name FROM customer
WHERE acctbal = 4231.45 OR name = 'Customer#000000376'
```

The source stage in the output of `EXPLAIN ANALYZE` looks like:

```
Fragment 1 [SOURCE]
    CPU: 40.07ms, Scheduled: 43.26ms, Blocked 0.00ns (Input: 0.00ns, Output: 0.00ns), Input: 1500 rows (0B); per task: avg.: 1500.00 std.dev.: 0.00, Output: 1 row (23B)
    Output layout: [name]
    Output partitioning: SINGLE []
    ScanFilterProject[table = mysql:tpch.customer tpch.customer columns=[name:varchar(255):TINYTEXT, acctbal:double:DOUBLE], filterPredicate = (("acctbal" = 4.23145E3) OR ("name" = CAST('Customer#000000376' AS varchar(255))))]
        Layout: [name:varchar(255)]
        Estimates: {rows: 1480 (79.49kB), cpu: 92.50k, memory: 0B, network: 0B}/{rows: ? (?), cpu: 92.50k, memory: 0B, network: 0B}/{rows: ? (?), cpu: ?, memory: 0B, network: 0B}
        CPU: 39.00ms (100.00%), Scheduled: 42.00ms (100.00%), Blocked: 0.00ns (?%), Output: 1 row (23B)
        Input avg.: 1500.00 rows, Input std.dev.: 0.00%
        name := name:varchar(255):TINYTEXT
        acctbal := acctbal:double:DOUBLE
        Input: 1500 rows (0B), Filtered: 99.93%, Physical input time: 2.37ms
```

Note the operator is now a `ScanFilterProject` operator which means that a
filter will occur in Trino. Also the number of input rows is now 1500 which
is how large this particular table. Thus, the connector is scanning all
data for this table and filtering is occurring in Trino.

# Predicate pushdown on parquet files

There are three operations that are performed by the parquet reader in Trino to
reduce the amount of data that is read:

* Row group pruning
* Data page filtering
* Bloom filters

All of these operations are performed automatically by Trino when possible.

Row group pruning uses the min/max statistics for all columns and dictionary
filtering for dictionary encoded columns.

The file footer in a parquet file contains metadata with min/max statistics for
each column in a row group. Using this metadata, the parquet reader in Trino can
decide to skip reading a row group if the value being searched for is not in the
min/max range for that column. This can result in entire files being skipped if
none of the row groups in that file have a value that is in the min/max range for
the column that is being searched on.

Dictionary filtering can skip reading a row group for dictionary encoded columns.
In each row group, for each dictionary encoded column, there is a dictionary page
that the Trino parquet reader looks at first. If the value being searched for does
not have a key in the dictionary, then the row group can be skipped.

For data page filtering, Parquet added support for column indexes which track
min/max statistics for each data page (the default page size for parquet is 1MB).
This can be leveraged to skip individual data pages for a column in a row group.
It is essentially the same as row group min/max filtering but just at a finer
granularity. 

Finally, bloom filters are a probabilistic data structure used for set membership
tests. Bloom filters in parquet files are typically useful when a field has too
many distinct values to use dictionary encoding. The parquet writer in Trino does
support writing bloom filters so in order to take advantage of bloom filters, the
parquet files would need to be produced by another engine such as Spark. The
option to control whether bloom filters will be created in Spark is
`parquet.bloom.filter.enabled`

Using the previous examples, we will create a version of the customer table with 
the hive connector and parquet files:

```
create table parquet_sf100_customer
with (
  type = 'hive',
  format = 'parquet'
) as select * from tpch.sf100.customer
```

To demonstrate predicate pushdown with parquet files we need to make sure we have
mulitple parquet files with each being at least 3MB in size. If a parquet file is
less than 3MB in size then by default, trino will just read the entire file.

## Row group pruning 

There are 2 techniques used by the parquet reader in Trino to perform row group
pruning: 1) filtering via min/max statistics and 2) dictionary filtering on
dictionary encoded fields.

### Filtering via min/max statistics

The previous query we used for our simple example with MySQL does not have effective
predicate pushdown with Parquet files. Lets look at the source stage when the query
is run against the `parquet_sf100_customer` table we created:

```
Fragment 1 [SOURCE]
    CPU: 822.62ms, Scheduled: 5.37s, Blocked 0.00ns (Input: 0.00ns, Output: 0.00ns), Input: 15000000 rows (131.51MB); per task: avg.: 7500000.00 std.dev.: 2023362.00, Output: 17 rows (391B)
    Output layout: [name]
    Output partitioning: SINGLE []
    ScanFilterProject[table = datalake:hive:parquet_sf100_customer, filterPredicate = ("acctbal" = 4.23145E3)]
        Layout: [name:varchar(25)]
        Estimates: {rows: 15000000 (329.02MB), cpu: 457.76M, memory: 0B, network: 0B}/{rows: 14 (312B), cpu: 457.76M, memory: 0B, network: 0B}/{rows: 14 (312B), cpu: 312, memory: 0B, network: 0B}
        CPU: 820.00ms (100.00%), Scheduled: 5.36s (100.00%), Blocked: 0.00ns (?%), Output: 17 rows (391B)
        Input avg.: 416666.67 rows, Input std.dev.: 137.17%
        name := name:varchar(25):REGULAR
        acctbal := acctbal:double:REGULAR
        Input: 15000000 rows (131.51MB), Filtered: 100.00%, Physical input: 83.09MB, Physical input time: 4.50s
```

Notice the number of input rows is `15000000` indicating that predicate pushdown
was not effective in this case.

This is because the acctbal predicate value is within the min and max values for
this field in all row groups across all parquet files. So it is not possible for
the parquet reader to skip reading any row groups based on this predicate. We can
view the min/max statistics stored in parquet files using the parquet CLI (see
[this post](https://posulliv.github.io/posts/parquet-cli/) for an in-depth overview
of using the parquet CLI). For example, here is what the parquet CLI shows us for a
row group for one of the parquet files that make up the `parquet_sf100_customer` table:

```
Row group 0:  count: 1793097  53.60 B records  start: 4  total(compressed): 91.659 MB total(uncompressed):279.601 MB
--------------------------------------------------------------------------------
            type      encodings count     avg size   nulls   min / max
custkey     INT64     G   _     1793097   1.52 B     0       "24604" / "14879964"
name        BINARY    G   _     1793097   2.60 B     0       "Customer#000024604" / "Customer#014879964"
address     BINARY    G   _     1793097   21.16 B    0       "   ,qJqVsHDVWLs6mv6S7Hwh9H" / "zzzmVsI9jUl6Wqk6oSl"
nationkey   INT64     G _ R     1793097   0.62 B     0       "0" / "24"
phone       BINARY    G   _     1793097   7.31 B     0       "10-100-124-6236" / "34-999-990-8682"
acctbal     DOUBLE    G   _     1793097   3.79 B     0       "-999.99" / "9999.99"
mktsegment  BINARY    G _ R     1793097   0.34 B     0       "AUTOMOBILE" / "MACHINERY"
comment     BINARY    G   _     1793097   16.27 B    0       " Tiresias about the furio..." / "zzle. slyly regular depos..."
```

Notice the min/max values for the acctbal field in this row group are -999.99/9999.99.

Let's try a query on the custkey field that we would expect to be able to do some
row group pruning. This is the query we will execute:

```
SELECT custkey FROM parquet_sf100_customer WHERE custkey = 1
```

The source stage from `EXPLAIN ANALYZE` looks like:

```
Fragment 1 [SOURCE]
    CPU: 243.27ms, Scheduled: 2.67s, Blocked 0.00ns (Input: 0.00ns, Output: 0.00ns), Input: 2434552 rows (20.90MB); per task: avg.: 1217276.00 std.dev.: 1217276.00, Output: 1 row (9B)
    Amount of input data processed by the workers for this stage might be skewed
    Output layout: [custkey]
    Output partitioning: SINGLE []
    ScanFilter[table = datalake:hive:parquet_sf100_customer, filterPredicate = ("custkey" = BIGINT '1')]
        Layout: [custkey:bigint]
        Estimates: {rows: 15000000 (128.75MB), cpu: 128.75M, memory: 0B, network: 0B}/{rows: 1 (9B), cpu: 128.75M, memory: 0B, network: 0B}
        CPU: 241.00ms (100.00%), Scheduled: 2.67s (100.00%), Blocked: 0.00ns (?%), Output: 1 row (9B)
        Input avg.: 67626.44 rows, Input std.dev.: 591.61%
        custkey := custkey:bigint:REGULAR
        Input: 2434552 rows (20.90MB), Filtered: 100.00%, Physical input: 3.57MB, Physical input time: 268.29ms
```

Notice that input rows is `2434552`. This indicates some row groups were skipped by the
parquet reader. This makes sense because using the min/max stats from the row group we
showed previously the min/max values for custkey in that row group were 24604/14879964.
In this case, the predicate value of 1 is less than the min value for the custkey field
in this row group. Thus, the parquet reader does not need to read this row group from
this parquet file. 

Now if we look at the row group that does match this predicate:

```
Row group 0:  count: 2434552  53.60 B records  start: 4  total(compressed): 124.449 MB total(uncompressed):379.587 MB
--------------------------------------------------------------------------------
            type      encodings count     avg size   nulls   min / max
custkey     INT64     G   _     2434552   1.52 B     0       "1" / "14981289"
name        BINARY    G   _     2434552   2.59 B     0       "Customer#000000001" / "Customer#014981289"
address     BINARY    G   _     2434552   21.16 B    0       "   ,CpQVsCA2ou" / "zzzrRIDbmZKVG9O,JaHPU7"
nationkey   INT64     G _ R     2434552   0.62 B     0       "0" / "24"
phone       BINARY    G   _     2434552   7.31 B     0       "10-100-114-7214" / "34-999-998-5763"
acctbal     DOUBLE    G   _     2434552   3.79 B     0       "-999.99" / "9999.99"
mktsegment  BINARY    G _ R     2434552   0.34 B     0       "AUTOMOBILE" / "MACHINERY"
comment     BINARY    G   _     2434552   16.27 B    0       " Tiresias above the foxes..." / "zzle? furiously regular p..."
```

Notice the min value for custkey in this row group is 1 and also notice that the number of
rows in this row group is 2434552 which is the same number of rows read by Trino:

```
Input: 2434552 rows (20.90MB), Filtered: 100.00%, Physical input: 3.57MB, Physical input time: 268.29ms
```

### Dictionary filtering

This filtering method is based on dictionary encoding. We can leverage dictionary filtering
if a column is encoded as a dictionary. Parquet has a default dictionary size limit of [1 MB](https://github.com/apache/parquet-mr/blob/master/parquet-hadoop/README.md).
If the size of a column for a row group exceeds 1 MB, it will fall back to plain encoding.

For this example, we will use the customer table again. From the previous examples, we know
that the nationkey field is a dictionary encoded field. We will insert some data to create
new parquet files that do not contain a few of nation keys that will be between the min and
max nation keys. This is to ensure that min/max filtering will not be effective for queries
on `nationkey`.

```
insert into parquet_sf10_customer
select * from parquet_sf10_customer
where nationkey <> 10 and nationkey <> 20
```

Now if we execute a query like the following:

```
select custkey
from parquet_sf10_customer
where nationkey = 10
```

We would expect dictionary filtering to skip reading row groups that do not contain any data
where `nationkey` is 10. Min/max filtering cannot be used since the min and max for `nationkey`
is 0 and 24 respectively for all row groups in all parquet files.

The source stage for our query looks like:

```
Fragment 1 [SOURCE]
    CPU: 125.89ms, Scheduled: 1.11s, Blocked 0.00ns (Input: 0.00ns, Output: 0.00ns), Input: 1500000 rows (25.75MB); per task: avg.: 375000.00 std.dev.: 406705.40, Output: 60101 rows (528.23kB)
    Amount of input data processed by the workers for this stage might be skewed
    Output layout: [custkey]
    Output partitioning: SINGLE []
    ScanFilterProject[table = datalake:hive:parquet_sf10_customer, filterPredicate = ("nationkey" = BIGINT '10')]
        Layout: [custkey:bigint]
        Estimates: {rows: 2880096 (24.72MB), cpu: 49.44M, memory: 0B, network: 0B}/{rows: 115204 (1012.53kB), cpu: 49.44M, memory: 0B, network: 0B}/{rows: 115204 (1012.53kB), cpu: 1012.53k, memory: 0B, network: 0B}
        CPU: 126.00ms (100.00%), Scheduled: 1.11s (100.00%), Blocked: 0.00ns (?%), Output: 60101 rows (528.23kB)
        Input avg.: 187500.00 rows, Input std.dev.: 183.10%
        nationkey := nationkey:bigint:REGULAR
        custkey := custkey:bigint:REGULAR
        Input: 1500000 rows (25.75MB), Filtered: 95.99%, Physical input: 3.20MB, Physical input time: 542.87ms
```

Notice the the number of inputs rows is 1500000. The total rows in the table is 2880096.
This indicates we did not read all data. We can verify the data is in the dictionary page
for the `nationkey` field by using the [parquet CLI](https://posulliv.github.io/posts/parquet-cli/)
to view dictionary information for this field.

```
Row group 0 dictionary for "nationkey":
     0: 1
     1: 14
     2: 7
     3: 2
     4: 8
     5: 6
     6: 24
     7: 18
     8: 19
     9: 3
    10: 12
    11: 23
    12: 5
    13: 21
    14: 9
    15: 13
    16: 0
    17: 17
    18: 4
    19: 15
    20: 16
    21: 11
    22: 22
```

The `nationkey` values are the value in this dictionary. Notice that there is no
10 value in this dictionary. This allows the parquet reader to skip reading this
row group entirely.

## Data page filtering

> Note that using parquet column indexes is currently only supported in the hive connector. There is an [open PR](https://github.com/trinodb/trino/pull/13584) to add support for this to Iceberg.

Data page filtering requires column indexes to be present in the parquet files
being queried. The native parquet writer in newer versions of Trino (> 422)
does not support writing column indexes. Older versions of Trino that used a
different parquet writer support writing column indexes. Thus, I am going to
query a table in this example created using an older version of Trino.

For this example, we will use this query:

```
SELECT orderkey
FROM "datalake"."hive"."old_writer_lineitem"
WHERE partkey = 1
```

This query uses both row group pruning and data page filtering. The source stage
from the output of `EXPLAIN ANALYZE` looks like:

```
Fragment 1 [SOURCE]
    CPU: 1.12s, Scheduled: 8.16s, Blocked 0.00ns (Input: 0.00ns, Output: 0.00ns), Input: 460000 rows (4.98MB); per task: avg.: 460000.00 std.dev.: 0.00, Output: 23 rows (207B)
    Output layout: [orderkey]
    Output partitioning: SINGLE []
    ScanFilterProject[table = datalake:hive.old_writer_lineitem, filterPredicate = ("partkey" = BIGINT '1')]
        Layout: [orderkey:bigint]
        Estimates: {rows: 342300666 (2.87GB), cpu: 5.74G, memory: 0B, network: 0B}/{rows: ? (?), cpu: 5.74G, memory: 0B, network: 0B}/{rows: ? (?), cpu: ?, memory: 0B, network: 0B}
        CPU: 1.11s (100.00%), Scheduled: 8.15s (100.00%), Blocked: 0.00ns (?%), Output: 23 rows (207B)
        Input avg.: 1825.40 rows, Input std.dev.: 315.54%
        partkey := partkey:bigint:REGULAR
        orderkey := orderkey:bigint:REGULAR
        Input: 460000 rows (4.98MB), Filtered: 100.00%, Physical input: 9.00MB, Physical input time: 2.58s
```

Notice the number of input rows is 460000. The total number of rows in this table
is 6000000000. This means we are filtering a lot of rows in the parquet reader. To
understand why, lets look at the row group information in one of the parquet files
for the table we are querying:

```
Row group 0:  count: 4730100  28.25 B records  start: 4  total(compressed): 127.436 MB total(uncompressed):314.723 MB
--------------------------------------------------------------------------------
               type      encodings count     avg size   nulls   min / max
orderkey       INT64     G _ R_ F  4730100   0.62 B     0       "1526974944" / "2174365665"
partkey        INT64     G   _     4730100   4.44 B     0       "75" / "199999958"
suppkey        INT64     G   _     4730100   3.89 B     0       "5" / "9999993"
linenumber     INT32     G _ R     4730100   0.17 B     0       "1" / "7"
quantity       DOUBLE    G _ R     4730100   0.75 B     0       "1.0" / "50.0"
extendedprice  DOUBLE    G   _     4730100   4.10 B     0       "903.88" / "104860.0"
discount       DOUBLE    G _ R     4730100   0.44 B     0       "-0.0" / "0.1"
tax            DOUBLE    G _ R     4730100   0.41 B     0       "-0.0" / "0.08"
returnflag     BINARY    G _ R     4730100   0.18 B     0       "A" / "R"
linestatus     BINARY    G _ R     4730100   0.11 B     0       "F" / "O"
shipdate       INT32     G _ R     4730100   1.50 B     0       "1992-01-02" / "1998-12-01"
commitdate     INT32     G _ R     4730100   1.49 B     0       "1992-01-31" / "1998-10-31"
receiptdate    INT32     G _ R     4730100   1.50 B     0       "1992-01-03" / "1998-12-30"
shipinstruct   BINARY    G _ R     4730100   0.25 B     0       "COLLECT COD" / "TAKE BACK RETURN"
shipmode       BINARY    G _ R     4730100   0.37 B     0       "AIR" / "TRUCK"
comment        BINARY    G   _     4730100   8.04 B     0       " Tiresias " / "zzle? express, final sauter"

Row group 1:  count: 4730100  28.25 B records  start: 133626543  total(compressed): 127.448 MB total(uncompressed):314.719 MB
--------------------------------------------------------------------------------
               type      encodings count     avg size   nulls   min / max
orderkey       INT64     G _ R_ F  4730100   0.62 B     0       "1529611680" / "2176597922"
partkey        INT64     G   _     4730100   4.44 B     0       "1" / "199999974"
suppkey        INT64     G   _     4730100   3.89 B     0       "2" / "10000000"
linenumber     INT32     G _ R     4730100   0.17 B     0       "1" / "7"
quantity       DOUBLE    G _ R     4730100   0.75 B     0       "1.0" / "50.0"
extendedprice  DOUBLE    G   _     4730100   4.10 B     0       "900.61" / "104928.0"
discount       DOUBLE    G _ R     4730100   0.44 B     0       "-0.0" / "0.1"
tax            DOUBLE    G _ R     4730100   0.41 B     0       "-0.0" / "0.08"
returnflag     BINARY    G _ R     4730100   0.18 B     0       "A" / "R"
linestatus     BINARY    G _ R     4730100   0.11 B     0       "F" / "O"
shipdate       INT32     G _ R     4730100   1.50 B     0       "1992-01-02" / "1998-12-01"
commitdate     INT32     G _ R     4730100   1.49 B     0       "1992-01-31" / "1998-10-31"
receiptdate    INT32     G _ R     4730100   1.50 B     0       "1992-01-03" / "1998-12-30"
shipinstruct   BINARY    G _ R     4730100   0.25 B     0       "COLLECT COD" / "TAKE BACK RETURN"
shipmode       BINARY    G _ R     4730100   0.37 B     0       "AIR" / "TRUCK"
comment        BINARY    G   _     4730100   8.04 B     0       " Tiresias " / "zzle? blithel"

Row group 2:  count: 4730100  28.25 B records  start: 267265365  total(compressed): 127.426 MB total(uncompressed):314.708 MB
--------------------------------------------------------------------------------
               type      encodings count     avg size   nulls   min / max
orderkey       INT64     G _ R_ F  4730100   0.61 B     0       "1532289632" / "2177798306"
partkey        INT64     G   _     4730100   4.44 B     0       "25" / "199999967"
suppkey        INT64     G   _     4730100   3.89 B     0       "1" / "10000000"
linenumber     INT32     G _ R     4730100   0.17 B     0       "1" / "7"
quantity       DOUBLE    G _ R     4730100   0.75 B     0       "1.0" / "50.0"
extendedprice  DOUBLE    G   _     4730100   4.10 B     0       "902.06" / "104898.5"
discount       DOUBLE    G _ R     4730100   0.44 B     0       "-0.0" / "0.1"
tax            DOUBLE    G _ R     4730100   0.41 B     0       "-0.0" / "0.08"
returnflag     BINARY    G _ R     4730100   0.18 B     0       "A" / "R"
linestatus     BINARY    G _ R     4730100   0.11 B     0       "F" / "O"
shipdate       INT32     G _ R     4730100   1.50 B     0       "1992-01-02" / "1998-12-01"
commitdate     INT32     G _ R     4730100   1.49 B     0       "1992-01-31" / "1998-10-31"
receiptdate    INT32     G _ R     4730100   1.50 B     0       "1992-01-04" / "1998-12-30"
shipinstruct   BINARY    G _ R     4730100   0.25 B     0       "COLLECT COD" / "TAKE BACK RETURN"
shipmode       BINARY    G _ R     4730100   0.37 B     0       "AIR" / "TRUCK"
comment        BINARY    G   _     4730100   8.03 B     0       " Tiresias " / "zzle? slyly unusual depos..."

Row group 3:  count: 1520210  28.54 B records  start: 400880731  total(compressed): 41.384 MB total(uncompressed):99.829 MB
--------------------------------------------------------------------------------
               type      encodings count     avg size   nulls   min / max
orderkey       INT64     G _ R_ F  1520210   0.90 B     0       "1535122564" / "2178671012"
partkey        INT64     G   _     1520210   4.44 B     0       "58" / "199999997"
suppkey        INT64     G   _     1520210   3.89 B     0       "6" / "10000000"
linenumber     INT32     G _ R     1520210   0.17 B     0       "1" / "7"
quantity       DOUBLE    G _ R     1520210   0.75 B     0       "1.0" / "50.0"
extendedprice  DOUBLE    G   _     1520210   4.10 B     0       "905.68" / "104825.0"
discount       DOUBLE    G _ R     1520210   0.44 B     0       "-0.0" / "0.1"
tax            DOUBLE    G _ R     1520210   0.41 B     0       "-0.0" / "0.08"
returnflag     BINARY    G _ R     1520210   0.18 B     0       "A" / "R"
linestatus     BINARY    G _ R     1520210   0.11 B     0       "F" / "O"
shipdate       INT32     G _ R     1520210   1.50 B     0       "1992-01-02" / "1998-12-01"
commitdate     INT32     G _ R     1520210   1.50 B     0       "1992-01-31" / "1998-10-31"
receiptdate    INT32     G _ R     1520210   1.50 B     0       "1992-01-04" / "1998-12-30"
shipinstruct   BINARY    G _ R     1520210   0.26 B     0       "COLLECT COD" / "TAKE BACK RETURN"
shipmode       BINARY    G _ R     1520210   0.37 B     0       "AIR" / "TRUCK"
comment        BINARY    G   _     1520210   8.04 B     0       " Tiresias " / "zzle; final packages"
```

This parquet file has 4 row groups. Notice that only row group 1 will be read
because it is the only row group with min/max values for the partkey field that
match the predicate value. So with row group pruning, we would read at least
4730100 rows.

Next, we will look at the column indexes for the `partkey` field in row group
1 using the parquet CLI:

```
column index for column partkey:
Boundary order: UNORDERED
                      null count  min                                       max
page-0                         0  3946                                      199999039
page-1                         0  17965                                     199998705
page-2                         0  3594                                      199991556
page-3                         0  26870                                     199996833
page-4                         0  1649                                      199981961
...
page-88                        0  1                                         199991447
...
```

Notice that page-88 is the only page with a minimum value that matches the value
of the `partkey` field in the predicate. Thus, all other data pages in this row
group will be skipped by the parquet reader. Page 88 contains 460000 rows and
that matches the input count in the source stage for our query:

```
Input: 460000 rows (4.98MB), Filtered: 100.00%, Physical input: 9.00MB, Physical input time: 2.58s
```

To compare, let's look at the same query against a table that was created with
no column indexes in the underlying parquet files. The source stage for the same
query against such a table looks like:

```
Fragment 1 [SOURCE]
    CPU: 2.38s, Scheduled: 8.27s, Blocked 0.00ns (Input: 0.00ns, Output: 0.00ns), Input: 36636395 rows (316.07MB); per task: avg.: 36636395.00 std.dev.: 0.00, Output: 23 rows (207B)
    Output layout: [orderkey]
    Output partitioning: SINGLE []
    ScanFilterProject[table = datalake:parquetteststpch.no_col_indexes, filterPredicate = ("partkey" = BIGINT '1')]
        Layout: [orderkey:bigint]
        Estimates: {rows: 36636395 (314.45MB), cpu: 628.91M, memory: 0B, network: 0B}/{rows: 1 (9B), cpu: 628.91M, memory: 0B, network: 0B}/{rows: 1 (9B), cpu: 9, memory: 0B, network: 0B}
        CPU: 2.39s (100.00%), Scheduled: 8.27s (100.00%), Blocked: 0.00ns (?%), Output: 23 rows (207B)
        Input avg.: 872295.12 rows, Input std.dev.: 119.07%
        partkey := partkey:bigint:REGULAR
        orderkey := orderkey:bigint:REGULAR
        Input: 36636395 rows (316.07MB), Filtered: 100.00%, Physical input: 183.67MB, Physical input time: 4.61s
```

Notice the number of input rows is larger now due to the absence of column indexes.

While this artificial example shows some benefit to column indexes, in practice it's
not clear that there is much of a performance improvement from column indexes. These
page level min/max column indexes don’t tend to be very selective unless the data is
sorted by the field we are searching on. However, if the data is sorted then row group
pruning tends to provide the majority of the benefit. All this to say I wouldn’t worry
too much about whether or not the parquet files being queried contain column indexes.

## Bloom filters

I do not have any parquet files with bloom filters at the moment to test with. However,
the idea is same as dictionary filtering. In order for bloom filters to be used by the
parquet reader in trino you will need to use version 406 or newer as that is when
support for these [was added](https://github.com/trinodb/trino/pull/14428).

