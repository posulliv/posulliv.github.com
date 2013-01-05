--- 
title: Digging into Drupal's Schema
layout: post
category: planet drupal
---

I'm relatively new to Drupal internals and most of the [work][akiban_link] I do is on the 
database side. While searching for information on Drupal's schema, I found 
very little. During my research, I put together an ER diagram of the schema
installed by Drupal 7 (D8 is very similar with only 3 extra tables at time of
writing) and decided to share my work. Note that the relationships I discuss
here are based on the foreign key documentation that exists in core and 
my understanding of what I believe other relationships could be. Corrections
and comments are very much welcome.

# Overview

I'll start off by showing my complete ER diagram below. You will see I grouped
tables I found to be related in colored boxes. The image below is just meant
to give a general overview of the schema. I will be diving into different parts
of the schema in this post. I created this diagram using 
[MySQL Workbench][mysql_workbench] and the model can be downloaded from 
[here][workbench_model] if someone wishes to open this up in Workbench. This
[gist][alter_gist] also shows the `ALTER TABLE` SQL statements that would need
to be issued to actually create these foreign keys in MySQL. I would not recommend
doing this right now with Drupal as many things would break.

<div>
  <img alt="Full ER Diagram." src="/images/all_drupal_7_er.png"/>
</div>

Without delving into the relationships and details of this diagram, lets first
cover some basic details. A stock install of Drupal 7 results in 73 tables 
being created. 10 of those tables are used for caching purposes:

<table border="1">
  <tr>
    <th>Caching Table</th><th>Description</th>
  </tr>
  <tr>
    <td>cache</td><td>caches items not separated out into their own cache tables</td>
  </tr>
  <tr>
    <td>cache_block</td><td>the block modules can cache already built blocks here</td>
  </tr>
  <tr>
    <td>cache_bootstrap</td><td>data required during the bootstrap process can be cached in this table</td>
  </tr>
  <tr>
    <td>cache_field</td><td>stores cached field values</td>
  </tr>
  <tr>
    <td>cache_filter</td><td>caches already filtered pieces of text</td>
  </tr>
  <tr>
    <td>cache_form</td><td>caches recently built forms and their storage data</td>
  </tr>
  <tr>
    <td>cache_image</td><td>caches information about image manipulations that are in progress</td>
  </tr>
  <tr>
    <td>cache_menu</td><td>caches router information as well as generated link trees</td>
  </tr>
  <tr>
    <td>cache_page</td><td>caches compressed pages served to anonymous users</td>
  </tr>
  <tr>
    <td>cache_path</td><td>caches path aliases</td>
  </tr>
</table>

11 tables are created which do not relate to any other tables:

<table border="1">
  <tr>
    <th>Table Name</th><th>Description</th>
  </tr>
  <tr>
    <td>actions</td><td>stores action information</td>
  </tr>
  <tr>
    <td>batch</td><td>stores details about batches (processes that run in multiple HTTP requests)</td>
  </tr>
  <tr>
    <td>blocked_ips</td><td>stores a list of blocked IP addresses</td>
  </tr>
  <tr>
    <td>flood</td><td>controls the threshold of events, such as the number of contact attempts</td>
  </tr>
  <tr>
    <td>queue</td><td>stores items in queues</td>
  </tr>
  <tr>
    <td>rdf_mapping</td><td>stores custom RDF mappings for user-defined content types</td>
  </tr>
  <tr>
    <td>semaphore</td><td>stores semaphores, locks, and flags</td>
  </tr>
  <tr>
    <td>sequences</td><td>stores IDs</td>
  </tr>
  <tr>
    <td>system</td><td>contains a list of all modules, themes, and theme engines that are or have been installed</td>
  </tr>
  <tr>
    <td>url_alias</td><td>contains a list of URL aliases for Drupal paths</td>
  </tr>
  <tr>
    <td>variable</td><td>stores variable/value pairs created by Drupal core or any other module or theme</td>
  </tr>
</table>

The 21 tables listed above are self-explanatory and I'm not going to 
discuss them any further in this post. They also are independent in that these
tables have no relationships with other tables.

# Field Related Tables

There are 8 tables installed with core related to fields and field storage:

<table border="1">
  <tr>
    <th>Table Name</th><th>Description</th>
  </tr>
  <tr>
    <td>field_data_body</td><td>stores details about the body field of an entity</td>
  </tr>
  <tr>
    <td>field_revision_body</td><td>stores information about revisions to body fields</td>
  </tr>
  <tr>
    <td>field_data_comment_body</td><td>stores information about comments associated with an entity</td>
  </tr>
  <tr>
    <td>field_revision_comment_body</td><td>stores information about revisions to comments</td>
  </tr>
  <tr>
    <td>field_data_field_image</td><td>stores information about images associated with an entity</td>
  </tr>
  <tr>
    <td>field_revision_field_image</td><td>stores information about revisions to images</td>
  </tr>
  <tr>
    <td>field_data_field_tags</td><td>stores information about tags associated with an entity</td>
  </tr>
  <tr>
    <td>field_revision_field_tags</td><td>stores information about revisions to taxonomy terms/tags associated with an entity</td>
  </tr>
</table>

While I was initially tempted to have these tables related to `node`, that would not 
really be correct since these tables are related to an entity. In
D7, entities can be other objects besides nodes, such as users or comments.
The `entity_type` column in these tables reflects that reality. These tables
can be stored in other storage systems such as [MongoDB][mongo_module] due to
the [field storage API][field_storage_api] introduced in Drupal 7.

There are 2 other tables related to fields: `field_config` and 
`field_config_instance`. These tables store field configuration information.
I believe a row in `field_config_instance` cannot (well at least *should* not)
exist without the correspondong `field_id` in the `field_config` table. Hence,
the one-to-many relationship from `field_config` to `field_config_instance` is
an identifying relationship.

# Small Groups of Tables

There are a number of groups you will notice in the full ER diagram that are
made up of 2 to 3 tables. Zooming in on 4 of those groups, we can see those
tables more clearly:

<div>
  <img alt="Zooming in on small groups." src="/images/small_groups_zoom.png"/>
</div>

One thing you will notice is that some relationships are shown with a solid
line whereas others use a dotted line. MySQL Workbench represents identifying
relationships with a solid line and non-identifying relationships with a 
dotted line. If you are unfamiliar with those terms, the standard defintions 
are:

 * identifying relationship - the foreign key attribute is part of the child's
   primary key attribute.
 * non-identifying relationship - the primary key attributes of the parent 
   must not become primary key attributes of the child.

This [stack overflow answer][bk_so_ans] from [Bill Karwin][bk_link] contains a
good discussion on these topics.

Now lets discuss those groups in more detail.

## Registry Group

I grouped the `registry` and `registry_file` tables together. These tables 
are used for implementing the code registry in Drupal. A one-to-many
relationship exists from `registry_file` to `registry` and this relationship
is an identifying relationship. A `filename` should not appear in the `registry`
table that is not present in the `registry_file` table.

## Image Group

I grouped the `image_styles` and `image_effects` tables together. These tables
store configuration options for image styles and effects. A one-to-many 
relationship exists from `image_styles` to `image_effects` and this relationship
is a non-identifying relationship.

## date_format Group

There are three tables about date formats in Drupal. `date_format_type` is a lookup
table that stores configured date format types. After a stock install of Drupal
7, three date format types exist:

 * long
 * medium
 * short

A one-to-many relationship exists from this lookup table to both `date_formats`
and `date_format_locale`. 

In practice, this would be problematic. For example, a new date format can be
created by an adminstrator. In D7, this results in the `system_date_format_save`
function being called. This function will insert a row in the `date_formats`
table that will not have a corresponding type (type will be listed as custom).

You will also notice the `locked` column is redundant in the `date_formats`
table. I submitted a [patch][format_issue_link] to change this.

## File Group

I grouped the `file_managed` and `file_usage` tables into 1 group. These tables
store information about uploaded files and information for tracking where a
file is used.

I believe a 1-to-1 relationship exists from `file_managed` to `file_usage` and
that this is an identifying relationship.

# User Related Tables

There are quite a few tables that store user related information. Below is
a figure where I zoom in on those tables.

<div>
  <img alt="User tables." src="/images/all_user_tables.png"/>
</div>

As you can see, the tables directly associated with users are `watchdog`, `sessions`,
 and `authmap`. These tables are in a one-to-many relationship from `users`.
The functionality these tables provide is:

<table border="1">
  <tr>
    <th>Table Name</th><th>Description</th>
  </tr>
  <tr>
    <td>authmap</td><td>stores distributed authentication mapping</td>
  </tr>
  <tr>
    <td>sessions</td><td>stores information about a users session</td>
  </tr>
  <tr>
    <td>watchdog</td><td>contains logs of all system events</td>
  </tr>
</table>

There are then two tables that are in a many-to-many relationship with `users`
that link this table with other groups. One of these is the `users_roles`
table. This table links `users` with `role`. The `role` table is then in a
one-to-many relationship with the `role_permission` table. The other 
many-to-many table is `shortcut_set_users`. This table links `users` with
`shortcut_set`. 

The tables for the menu system are not really related to users but I 
placed the group close by since the `menu_links` table maintains a one-to-many
relationship with the `shortcut_set` table. While the tables for the menu system
do not appear to be related, I do believe a relationship exists there. In
particular, I think that the `menu_link` table has relationships to both the
`menu_router` and `menu_custom` tables. The `router_path` column in `menu_links`
could reference the `router` column in `menu_router` and the `menu_name` column
in `menu_links` could reference the `menu_name` in the `menu_custom` table. Right
now however, after a stock install of D7, a row with a menu name that is not
present in `menu_custom` will be created in `menu_links`.

The menu system tables and a description of what they do is below.

<table border="1">
  <tr>
    <th>Table Name</th><th>Description</th>
  </tr>
  <tr>
    <td>menu_custom</td><td>holds definitions for top-level custom menus</td>
  </tr>
  <tr>
    <td>menu_links</td><td>contains the individual links within a menu</td>
  </tr>
  <tr>
    <td>menu_router</td><td>maps paths to various callbacks</td>
  </tr>
</table>
<br>

# Node Related Tables

Node is one of the most central concepts in Drupal so as you can imagine, many
tables are related to that concept. First off, a high level overview of the
tables related to the `node` table are shown below.

<div>
  <img alt="Node tables." src="/images/all_node_tables.png"/>
</div>

Tables that are directly related to `node` are `node_revision`, `node_access`, and
`node_type`. The `node_type` table is in many-to-many relationship with `node` 
and `block_node_type`. `node_revision` is in a many-to-one relationship with
`node` as is `node_access`. The `node_access` table has only 1 row upon initial
installation and references a non-existent node. An [issue][lm_issue_1] has been
created to address this.

The tables directly related to `node` and a description of what they do is below.

<table border="1">
  <tr>
    <th>Table Name</th><th>Description</th>
  </tr>
  <tr>
    <td>node_access</td><td>identifies which realm/grant pairs a user must possess in order to view, update, or delete specific nodes</td>
  </tr>
  <tr>
    <td>node_revision</td><td>stores information about each saved version of a node</td>
  </tr>
  <tr>
    <td>node_type</td><td>stores information about all defined node types</td>
  </tr>
</table>
<br>

## Taxonomy Tables

Four tables in the stock schema are related to taxonomy. These tables are shown
in the figure below.

<div>
  <img alt="Taxonomy tables." src="/images/taxonomy_tables.png"/>
</div>

First of all, the `taxonomy_index` table is in a many-to-many relationship with 
the `node` and `taxonomy_term_data` tables. The `taxonomy_vocabulary` table
has a one-to-many relationship with the `taxonomy_term_data` table. The 
`taxonomy_term_data` table in turn has 2 1-to-many relationships with the
`taxonomy_term_hierarchy` table.

A description of the taxonomy tables is given below.

<table border="1">
  <tr>
    <th>Table Name</th><th>Description</th>
  </tr>
  <tr>
    <td>taxonomy_index</td><td>maintains de-normalized information about node/term relationships</td>
  </tr>
  <tr>
    <td>taxonomy_term_data</td><td>stores term information</td>
  </tr>
  <tr>
    <td>taxonomy_term_hierarchy</td><td>stores the hierarchical relationship between terms</td>
  </tr>
  <tr>
    <td>taxonomy_vocabulary</td><td>stores vocabulary information</td>
  </tr>
</table>
<br>

## Block Tables

The main table in this group is `block`. It has three directly related tables
in one-to-many relationships: `block_node_type`, `block_role`, and 
`block_custom`.

<div>
  <img alt="Blocks tables." src="/images/blocks_tables.png"/>
</div>

A description of the blocks tables is given below.

<table border="1">
  <tr>
    <th>Table Name</th><th>Description</th>
  </tr>
  <tr>
    <td>blocks</td><td>stores block settings</td>
  </tr>
  <tr>
    <td>block_custom</td><td>stores the contents of custom-made blocks</td>
  </tr>
  <tr>
    <td>block_node_type</td><td>stores information that sets up display criteria for blocks based on content type</td>
  </tr>
  <tr>
    <td>block_role</td><td>stores access permissions for blocks based on user roles</td>
  </tr>
</table>
<br>

## Search Tables

The relationships for the search tables I am a little unsure of. I believe
they are as shown in the figure below.

<div>
  <img alt="Search tables." src="/images/search_tables.png"/>
</div>

The relationship I'm most unsure of here are between `search_total` and
`search_index`. I don't think the one-to-many relationship I have in place
from `search_total` to `search_index` is correct.

A description of the search tables is given below.

<table border="1">
  <tr>
    <th>Table Name</th><th>Description</th>
  </tr>
  <tr>
    <td>search_dataset</td><td>stores items that will be searched</td>
  </tr>
  <tr>
    <td>search_index</td><td>stores the search index and associates words, items, and scores</td>
  </tr>
  <tr>
    <td>search_node_links</td><td>stores items that link to other nodes</td>
  </tr>
  <tr>
    <td>search_total</td><td>stores search totals for words</td>
  </tr>
</table>
<br>

# Tables That Relate Nodes to Users

There are three tables in many-to-many relationships between `node` and
`users`:

<table border="1">
  <tr>
    <th>Table Name</th><th>Description</th>
  </tr>
  <tr>
    <td>comment</td><td>stores comments and associated data</td>
  </tr>
  <tr>
    <td>history</td><td>stores a record of which users have read which nodes</td>
  </tr>
  <tr>
    <td>node_comment_statistics</td><td>maintains statistics of nodes and comments posts to show <b>new</b> and <b>updated</b> flags</td>
  </tr>
</table>

The `comment` table could be in its own group. I decided against doing that in
this ER diagram since I felt like it would have been a table by itself. Logically,
I think of it as either being in the `users` or `node` group.

`node_comment_statistics` does also maintain a relationship with `comment`.
This is a non-identifying relationship since a node can exist without any
comments.

# Conclusion

During this work, I noticed that the column definitions for many foreign key relationships
are in-correct which would result in MySQL not allowing these constraints to
actually be created. I created an [issue][my_issue_link] and patch for this
but it turns out Liam Morland is working on [using foreign keys][real_fk_link]
in core and also came across this around the same time as me.

Other issues I encountered have also been logged by Liam:

 * the `node_access` table references a non-existent node ([relevant issue][lm_issue_1])
 * a set name exists in `shortcut_set` that does not exist in `menu_links` ([relevant issue][lm_issue_2])

I would vote for foreign keys being used in Drupal core for a number of reasons,
not least of which foreign keys aid a newcomer when trying to understand the schema 
installed by Drupal.

As I mentioned at the beginning of this post, any comments or corrections are
very much welcome. I hope this information can prove useful to someone else
besides me!

[my_issue_link]:     http://drupal.org/node/1701822
[real_fk_link]:      http://drupal.org/node/911352
[lm_issue_1]:        http://drupal.org/node/1703222
[lm_issue_2]:        http://drupal.org/node/1703208
[mongo_module]:      http://drupal.org/project/mongodb
[field_storage_api]: http://api.drupal.org/api/drupal/modules%21field%21field.attach.inc/group/field_storage/7
[mysql_workbench]:   http://www.mysql.com/products/workbench/
[workbench_model]:   http://posulliv.github.com/misc/latest_drupal_7.mwb
[bk_so_ans]:         http://stackoverflow.com/questions/762937/whats-the-difference-between-identifying-and-non-identifying-relationships
[bk_link]:           http://karwin.blogspot.com/
[format_issue_link]: http://drupal.org/node/1708464
[alter_gist]:        https://gist.github.com/3231183
[akiban_link]:       http://akiban.com/
