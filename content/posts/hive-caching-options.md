---
title: "Caching options in Trino's Hive connector"
date: 2022-04-25T08:20:22-05:00
draft: false
---

This article is going to cover some of the caching options available in the
Hive connector in Trino. There are 4 options available that we will cover
here. We will start with the Hive metastore cache as that is the one we
most commonly enable for customers.

# Hive Metastore caching

The Hive connector reads various metadata from a Hive metastore (HMS). Communication
between Trino and the HMS occurs via a thrift protocol. A lot of requests are
made from Trino to the HMS, particularly during the planning stage of a query.

There is an option to enable metadata caching for the Hive connector. This can
speed up planning times for queries significantly. The metastore cache is only
maintained on the coordinator; there is no metastore cache on any worker.

The parameters you need to be aware of when configuring the HMS cache are:

* `hive.metastore-cache-maximum-size` - this controls how many objects are stored
  in the cache. This parameter defaults to 10,000
* `hive.metastore-refresh-interval` - if set, a background refresh of cached data
  will occur if the cached data is older than `hive.metastore-refresh-interval` but
  is not yet expired i.e. the cached data is younger than `hive.metastore-cache-ttl`
* `hive.metastore-cache-ttl` - the duration for which cached data should be
  considered valid

As an example of how this works, let's assume we have the following configuration:

```
hive.metastore-cache-ttl=10m
hive.metastore-refresh-interval=5m
```

With those settings, cached data will be valid for 10m. So if you query data, then
query again 9m later, the cached data will be returned. However, since the cached
data is older than 5m, the access will initiate a background refresh, allowing a
subsequent access to return fresher data.

The background refresh is in the background, so it doesn’t block — the query that
is accessing the data gets the data immediately from the cache. The refresh allows
the next query to see fresh data.

Now, a common scenario we get a lot of questions on is when Trino is used as a
read-only query engine for data that is written by another system such as Hive
or Spark. The values to choose for the above parameters then depends on your
tolerance for performance versus staleness since there is no way for Trino to
be notified of changes made to the HMS by external processes. If you only change
the data through Trino, you could set a very large TTL.

For example, you might set the background refresh very low, say 10s, if you want
to frequently refresh the data, at the expense of more load on Trino and the HMS.

If you cannot tolerate stale results in your use case, then you should not enable
HMS caching. In this case, you should invest time in improving the performance
of your HMS if it is slow. A common cause for a slow HMS is an overloaded 
database.

## Monitoring

There is a table for each Hive connector in the JMX catalog that can be
queried to get the request count along with the hit and miss rate for each
cache map that makes up the overall metastore cache. There will be a row for
each node in the cluster but the only row that is relevant is the row for the
coordinator since metastore caching only occurs on the coordinator. These
numbers are reset each time the cluster is restarted.

The name of the JMX table includes the catalog name:
`trino.plugin.hive.metastore.cache:name=YOUR_CATALOG_NAME,type=cachinghivemetastore`

A query to run to get all metrics for only the coordinator row is:

```
select
  *
from
  jmx.current."trino.plugin.hive.metastore.cache:name=YOUR_CATALOG,type=cachinghivemetastore"
where
  node = (select node_id from system.runtime.nodes where coordinator = true)
```

## Cache Invalidation

A procedure is available for flushing this metadata cache - 
`system.flush_metadata_cache`.

If called with no parameters, this procedure will flush everying in the HMS
cache. It can also just flush cache entries for specified partitions.

For example, imagine I have table like:

```
 CREATE TABLE hive_315_hms.junk.terrible (
    nationkey bigint,
    name varchar(25)
 )
 WITH (
    format = 'ORC',
    partitioned_by = ARRAY['name']
 )
```

To flush the metadata for just partitions with the value `GERMANY`, I would execute:

```
trino:junk> call system.flush_metadata_cache(schema_name => 'junk', table_name => 'terrible', partition_column => ARRAY['name'], partition_value => ARRAY['GERMANY']);
CALL
trino:junk>
```

If using file based system access control in Trino, you cannot restrict access
to this procedure at the moment so keep that in mind. If you are using Ranger
for system access control, users will need to have the `EXECUTE` permission
in order to call this procedure.

# File status caching

The Hive connector makes a lot of calls to list all files in a directory.
These calls can be expensive, particularly on object storage such as S3.

Trino has a few configuration parameters to enable and configure file status
caching to cache directory listings:

* `hive.file-status-cache-tables` - list of tables to cache listings for. This can
  be a regular expression like `*` to cache listings for all tables.
* `hive.file-status-cache-size` - The maximum size of the listings cache (default is 1000000 entries)
* `hive.file-status-cache-expire-time` - how long to cache listings for. This defaults to `1m`.

File status caching can be monitored via JMX by querying the `trino.plugin.hive:name=CATALOG_NAME,type=cachingdirectorylister`
table.

A query to run to get all metrics for only the coordinator row is:

```
select
  *
from
  jmx.current."trino.plugin.hive:name=YOUR_CATALOG,type=cachingdirectorylister"
where
  node = (select node_id from system.runtime.nodes where coordinator = true)
```

# Storage caching

The hive connector has [built-in support](https://trino.io/docs/current/connector/hive-caching.html) 
for caching using [RubiX](https://github.com/trinodb/trino-rubix). The
documentation details how to enable and configure storage caching but 
enabling it is quite simple. In your Hive connector catalog properties file,
you need:

```
hive.cache.enabled=true
hive.cache.location=/opt/hive-cache
```

This means that each worker will use the `/opt/hive-cache` folder for
storing and reading cached data. Using any type of disk except a SSD
for storing this cached data will likely result in performance degradation. You
will be limited by the speed of the disk on which the cache is stored.

When enabling storage caching, I typically like to run a filesystem benchmark
tool like [IOZone](http://www.iozone.org) just to get a baseline for what 
kind of performance to expect from the disks to be used for the storage cache.

Given the Trino documentation covers the basics and outlines how the object
storage cache works, I wanted to cover some issues that may be encountered in
practice.

It is worth noting that caching will only improve query performance for queries
that are IO-bound. If a query is not IO-bound, enabling caching will likely not
affect the performance of the query. Caching can reduce network traffic between
the storage layer and the Trino cluster. If the storage layer is cloud storage,
this can result in cost savings since fewer requests will be made to the cloud
storage layer.

If the size of the allocated cache is too small to contain all data needed
for the workload, cache churn will occur and this can incur significant
overheads. If you notice performance degradation after enabling storage caching
and you are using SSDs, churn is a very probable cause.

The cache hit ratio for each worker can be seen by querying the
`jmx.current.”rubix:catalog=CATALOG_NAME,name=stats”` table. The average cache
hit ratio for the entire cluster can be seen with the following query:

```
SELECT avg(cache_hit)
FROM jmx.current."rubix:catalog=CATALOG_NAME,name=stats"
WHERE NOT is_nan(cache_hit)
```

You can also inspect the disk usage on the drives configured as the cache storage
drives. If these drives are 80% full, then no more data can fit on them. By default,
Trino will use up to 80% of the capacity of the disk for caching. This can be
changed by modifying the `hive.cache.disk-usage-percentage parameter`.

To determine what the size of the storage cache should be, you will need to look
at the workload that is typically run on your Trino cluster. The size of the
tables and the frequency they are queried is good to know. Ideally, the portions
of tables that are queried can be computed e.g. the size of all the partitions
and how often each partition is queried.

An event logger can be enabled for a period of time to help in identifying this
information.

This lets you determine the overall size of data that your workload operates on.
Once the overall size of the data for your workload has been computed, I typically
recommend that the total storage (overall disks on all workers) allocated for the
cache be approximately 1.2 times the overall data size.

As an example, assume you have a cluster with 10 worker nodes and the computed
data size for your workload is 1TB. In this case, the cache should be approximately
1.2TB with a disk of at least 120GB on each individual worker node.

One limitation when using storage caching with HDFS storage is that it does not support
user impersonation and cannot be used with HDFS secured by Kerberos. Starburst does 
[provide an implementation](https://docs.starburst.io/latest/connector/starburst-hive.html#storage-caching)
which does not have these limitations.

# Filesystem object caching

The creation of Hadoop `Filesystem` objects can be expensive. Trino caches
these objects and by default caches up to 1000 objects. This cache is
enabled by default. 

The keys for this cache depend on whether you have HDFS impersonation enabled
or not. If you do not have HDFS impersonation enabled, there will be a cache
entry per filesystem scheme i.e. `s3`, `hdfs`. If you do have HDFS impersonation
enabled however, there will be a cache entry per scheme per user. Thus, if
you have a lot of distinct users executing queries against Trino with HDFS
impersonation enabled, it is possible you could reach the maximum size of 
this cache.

If you hit the maximum size of this cache, you will encounter an error like:

```
io.trino.spi.TrinoException: FileSystem max cache size has been reached: 1000
```

This indicates this filesystem cache has filled up. The configuration
parameter that can be modified to increase the size of this cache is `hive.fs.cache.max-size`.

Again, this property defaults to 1000 and it is rare you will need to modify it.

# Conclusion

This article was a high level overview of the various caching options
available in the Hive connector. If you have any questions please reach
out and let me know!
