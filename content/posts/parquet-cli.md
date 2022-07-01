---
title: "Using the Parquet CLI"
date: 2022-06-30T08:22:51-04:00
draft: false
---

The [parquet CLI](https://github.com/apache/parquet-mr/tree/master/parquet-cli) is
a powerful tool for inspecting parquet files. I use it a lot for work at
[Starburst](https://www.starburst.io) but I have not found much documentation that
explains how to understand all the output that the tool provides.

Typically, the information I am interested in gleaning from a parquet file is:

* how many row groups are in the file and what is the size of the row groups
* what encodings are used for each column
* column statistics
* if dictionary encoding was used for a column, whether or not fallback to plain 
  encoding occurred
* column indexes

In this post, I will cover the commands I commonly use and how to read the output
that these commands provide to get the information I am interested in.

I am only going to cover the output that would be seen when inspecting parquet 
files that were created by version 1.12 or great of the `parquet-mr` library.

# File metadata

To view the metadata for a parquet file with the parquet CLI, we execute:

```
parquet-cli meta <path-to-parquet-file>
```

The output for this will first show you a header with information on the file:

```
File path:  128_row_group.parquet
Created by: parquet-mr version 1.12.2 (build 77e30c8093386ec52c3cfa6c34b7ef3321322c94)
Properties:
  writer.time.zone: GMT
```

Next, it will show you the schema for the data contained in the parquet file:

```
Schema:
message hive_schema {
  optional int64 orderkey;
  optional int64 partkey;
  optional int64 suppkey;
  optional int32 linenumber;
  optional double quantity;
  optional double extendedprice;
  optional double discount;
  optional double tax;
  optional binary returnflag (STRING);
  optional binary linestatus (STRING);
  optional int32 shipdate (DATE);
  optional int32 commitdate (DATE);
  optional int32 receiptdate (DATE);
  optional binary shipinstruct (STRING);
  optional binary shipmode (STRING);
  optional binary comment (STRING);
}
```

Then there will be information for each row group in the file:

```
Row group 0:  count: 4710100  28.38 B records  start: 4  total(compressed): 127.497 MB total(uncompressed):313.387 MB
--------------------------------------------------------------------------------
               type      encodings count     avg size   nulls   min / max
orderkey       INT64     Z _ R_ F  4710100   0.48 B     0       "4500010215" / "5167807264"
partkey        INT64     Z   _     4710100   4.30 B     0       "50" / "199999871"
```

The header for each row group has the following metadata:

* *Row group*: tells you which row group this is in the file (row group indices start at 0)
* *count*: the number of rows in the row group and the size in bytes of each row
* *total(compressed)*: compressed size of the data in the row group
* *total(uncompressed)*: uncompressed size of the data in the row group

In this example, the parquet file was generated with a row group size of 128MB.
This matches the compressed size of this row group - 127.497MB.

After the row group header, there will be a row for each column in the row group.
What we are typically most interested in these rows is the `encodings` field and 
the `min / max` field.

The `encodings` field will contain a collection of characters. The `encodings` field
is to be read by looking at each character in the string individually.

The possible characters you may see are:

* first and second - compression codec (possible options)
* third and fourth - dictionary encoding or not
* fifth, sixth, seventh - encoding of column (can be up to 3? characters)
* eigth - whether or not fallback occurred

For the first character that represents the compression codec, the characters
you may see are:

* `_` - uncompressed
* `S` - snappy
* `G` - gzip
* `L` - LZ0
* `B` - brotli
* `4` - LZ4
* `Z` - ZSTD
* `?` - unknown

For the dictionary encoding you will either see an empty space or a `_`
character.

For the column encoding, you may see 3 characters:

* `R` - RLE or plain dictionary encoding
* `_` - plain encoding
* `D` - delta encoding

As an example of how to read the `encodings` field, we will look at the `orderkey` column
first. The encoding for this column is: `Z _ R_ F`. Each character in this string
has a specific meaning:

* `Z` - the compression codec; in this case ZSTD
* `_` - a leading `_` character in this field indicates the column has a 
  dictionary encoding
* `R` - RLE is used for the dictionary encoding
* `_` - some of the data pages for this column are plain encoded
* `F` - this dictionary encoded column fell back to plain encoding
  because the size of the dictionary became large than the dictionary
  page size

Next, we will look at the `partkey` column encodings: `Z   _   `

We know this means the compression codec is ZSTD and this column only has a
plain encoding because of the placement of the `_` character.

After the encoding information, it tells us for each column: the number of
records, average size, and number of nulls.

Then finally, it tells us one of the most useful pieces of information for
each column in the row group: the min/max values for the column in that
row group.

This min/max information is very important for letting us know if min/max
filtering of row groups will be effective for predicates on a particular
column.

In this example, we see that the min/max range for the `orderkey` column is
small but the range for the `partkey` column is quite large. This tells us
that we can expect min/max filtering to be effective for the `orderkey` column
but not as effective for the `partkey` column.

# Dictionary metadata

For a dictionary encoded column, the `parquet-cli` tool has an option to view
the dictionary for that column:

```
parquet-cli dictionary <path-to-parquet-file> -c <column-name>
```

This command will output all keys/values for the dictionary in each row
group for the specified column.

Using the same file as in our previous example, we can view information
for the dictionaries for the `orderkey` column with:

```
parquet-cli dictionary <path-to-parquet-file> -c orderkey
```

This will have output like:

```
Row group 0 dictionary for "orderkey":
     0: 4951167618
     1: 4951167619
     2: 4951167620
     3: 4951167621
...
Row group 1 dictionary for "orderkey":
     0: 4930598149
     1: 4930598150
     2: 4930598151
     3: 4930598176
     4: 4930598177
...
Row group 2 dictionary for "orderkey":
     0: 4524740420
     1: 4524740421
     2: 4524740422
     3: 4524740423
     4: 4524740448
...
Row group 3 dictionary for "orderkey":
     0: 4847377187
     1: 4847377188
     2: 4847377189
     3: 4847377190
     4: 4847377191
```

This parquet file has 4 row groups in it so we can see information for 4
dictionaries. The values for each dictionary are the actual values for the column.
In this case, the column is `orderkey` so they values are integers.

But you will see the same with other types. For example, if we look at the
dictionaries for the `shipmode` column in this table:

```
Row group 0 dictionary for "shipmode":
     0: "SHIP"
     1: "MAIL"
     2: "AIR"
     3: "REG AIR"
     4: "TRUCK"
     5: "RAIL"
     6: "FOB"

Row group 1 dictionary for "shipmode":
     0: "SHIP"
...
```

You can see the values for the dictionary are the column values. Since this
is a very low cardinality column, there are only 7 distinct values.

# Individual pages

We can also use the `parquet-cli` to view metadata for pages in a 
parquet file:

```
parquet-cli pages <path-to-parquet-file>
```

This command will show metadata for every page on a per column basis. Each page
identifier has a particular format:

```
<row_group_number>-<page_number>
```

For a dictionary page, the `<page_number>` will be `D`.

For example, here is some of the output of the command for the `orderkey` column
we have looked at before:

```
Column: orderkey
--------------------------------------------------------------------------------
  page   type  enc  count   avg size   size       rows     nulls   min / max
  0-D    dict  Z _  129990  8.00 B     1015.547 kB
  0-1    data  Z R  20000   1.63 B     31.786 kB
  0-2    data  Z R  20000   1.75 B     34.228 kB
...
  1-D    dict  Z _  130108  8.00 B     1016.469 kB
  1-1    data  Z R  20000   1.63 B     31.786 kB
  1-2    data  Z R  20000   1.75 B     34.228 kB
...
  2-D    dict  Z _  130244  8.00 B     1017.531 kB
  2-1    data  Z R  20000   1.63 B     31.786 kB
  2-2    data  Z R  20000   1.75 B     34.228 kB
...
  3-D    dict  Z _  129755  8.00 B     1013.711 kB
  3-1    data  Z R  20000   1.63 B     31.786 kB
  3-2    data  Z R  20000   1.75 B     34.228 kB
...
```

So the majority of the pages are data pages. 1 page in each row group for
this column is a dictionary page as indicated by the `type` field and the
prefix in the page identifier.

Next, there is information on the encoding for each page. This can be read in
a similar way to the encoding for the row group metadata.

The first character is always the compression codec and the second character is
then the encoding of the actual page.

So for example `Z _` is a ZSTD compressed page with a plain encoding and `Z R` is
a ZSTD compressed page with a RLE dictionary encoding.

Next, for each page it shows you the record count in that page following by the
average size of each record. Then it tells you the total size of the page.

Notice that the dictionary pages will always be correspond to the parquet dictionary
size which is controlled when writing by the `parquet.dictionary.page.size` property.
The default dictionary page size is 1MB which was used when generating these parquet
files.

# Column indexes

Another part of a parquet file that is of interest is the [column indexes](https://github.com/apache/parquet-format/blob/master/PageIndex.md).

Column indexes track min/max statistics for each data page. This can be
leveraged to skip individual data pages for a column in a row group. It is
essentially the same as row group min/max filtering but just at a finer
granularity. 

To view information on column indexes, we issue:

```
parquet-cli column-index <path-to-parquet-file>
```

This will output the column indexes for each column per row group. It will
show you the min/max and null count for each column index.

Here is some example output for our `orderkey` column:

```
row-group 0:
column index for column orderkey:
Boundary order: UNORDERED
                      null count  min                                       max
page-0                         0  4500010215                                5142863968
page-1                         0  4500013217                                5035735234
page-2                         0  4502151685                                4930893862
...
row-group 1:
column index for column orderkey:
Boundary order: UNORDERED
                      null count  min                                       max
page-0                         0  4501938144                                5144928130
page-1                         0  4501945031                                5144938595
page-2                         0  4716204005                                5144942022
...
row-group 2:
column index for column orderkey:
Boundary order: UNORDERED
                      null count  min                                       max
page-0                         0  4524740420                                5166273987
page-1                         0  4523117509                                5059623457
page-2                         0  4630680775                                5166280994
...
row-group 3:
column index for column orderkey:
Boundary order: UNORDERED
                      null count  min                                       max
page-0                         0  4633395622                                5169011457
page-1                         0  4525823204                                5169018245
page-2                         0  4525829984                                5062322054
```

This can be useful to know whether or not column indexes will be useful for min/max
skipping. In this example, we can see each index has a small range of min/max values
so we would expect column indexes to be useful for predicates on this column.

For an example where this is not the case:

```
column index for column partkey:
Boundary order: UNORDERED
                      null count  min                                       max
page-0                         0  8850                                      199995958
page-1                         0  37233                                     199996089
page-2                         0  2830                                      199982784
page-3                         0  19052                                     199995316
```

Notice the min/max range for each column index here is quite large so we would 
not expect column indexes to be very useful for predicates on this column.

# Summary

This post was mostly for myself to reference in the future when I need to
parse output of the parquet CLI. Hopefully it may prove useful to someone!
