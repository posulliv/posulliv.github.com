--- 
title: Making Drupal more RESTful with Akiban
layout: post
category: drupal
---

[Last week][drupal_7_on_akiban], I published an article on how to
install Drupal 7 with Akiban as the backend database. Today, I wanted to
briefly show off our REST API using the schema that is created with a
standard install of Drupal 7 core.

First, I installed the [devel][devel_link] module and generated some
data since a bare bones install with no data would not be much fun. This
server is running on a publically available EC2 instance too so if  you
are interested in trying these examples out yourself at home, feel free
to do so! I'll leave the EC2 instance up and running for the remainder
of 2012 but if anyone wants to try the examples out and the instance
seems unavailable, please let me know and I'll fire it up again for you.

For the first few examples, I'm going to use `curl` since its available
on nearly every system (including OSX). Lets first get the version of
the Akiban we are going to be interacting with:

{% highlight console %}
$ curl -X GET -H "Content-Type: application/json" http://ec2-50-19-28-27.compute-1.amazonaws.com:8091/api/version
[
{"server_name":"Akiban Server","server_version":"1.4.4.2451"}
]
$
{% endhighlight %}

Lets continue this trend of a few simple examples to get started. I want
to know the list of schemas on this server I am interacting with:

{% highlight console %}
$ curl -X GET -H "Content-Type: application/json" http://ec2-50-19-28-27.compute-1.amazonaws.com:8091/api/information_schema.schemata
[
{"schema_name":"drupal","schema_owner":null,"default_character_set_name":null,"default_collation_name":null},
{"schema_name":"information_schema","schema_owner":null,"default_character_set_name":null,"default_collation_name":null},
{"schema_name":"sqlj","schema_owner":null,"default_character_set_name":null,"default_collation_name":null},
{"schema_name":"sys","schema_owner":null,"default_character_set_name":null,"default_collation_name":null},
{"schema_name":"test","schema_owner":null,"default_character_set_name":null,"default_collation_name":null}
]
$
{% endhighlight %}

Lets try a Drupal specific example next. Our REST API allows you to
retrieve an entire table group in 1 request. So let's say I wanted to
get all information for a certain user (I pretty-printed the JSON in the
output below so if you run this you will need to format the output):

{% highlight console %}
$ curl -X GET -H "Content-Type: application/json" http://ec2-50-19-28-27.compute-1.amazonaws.com:8091/api/drupal.users/1
[
    {
        "uid": 1,
        "name": "posulliv",
        "pass": "$S$DPV31LZyFWJmJ.Fcj6IRyjb/RFMyQQtE87gsad7cavgnH3fw0GHA",
        "mail": "posullivan@akiban.com",
        "theme": "",
        "signature": "",
        "signature_format": null,
        "created": 1355345142,
        "access": 1355762571,
        "login": 1355345211,
        "status": 1,
        "timezone": "America/New_York",
        "language": "",
        "picture": 0,
        "init": "posullivan@akiban.com",
        "data": "YjowOw==",
        "drupal.authmap": [],
        "drupal.sessions": [
            {
                "uid": 1,
                "sid": "jq57PowPwDK1CuKBpC56oqt_PsbwWNF4av97BuQqr6I",
                "ssid": "",
                "hostname": "75.147.9.1",
                "timestamp": 1355762574,
                "cache": 0,
                "session": "YmF0Y2hlc3xhOjE6e2k6MTtiOjE7fWF1dGhvcml6ZV9maWxldHJhbnNmZXJfaW5mb3xhOjE6e3M6MzoiZnRwIjthOjU6e3M6NToidGl0bGUiO3M6MzoiRlRQIjtzOjU6ImNsYXNzIjtzOjE1OiJGaWxlVHJhbnNmZXJGVFAiO3M6NDoiZmlsZSI7czo3OiJmdHAuaW5jIjtzOjk6ImZpbGUgcGF0aCI7czoyMToiaW5jbHVkZXMvZmlsZXRyYW5zZmVyIjtzOjY6IndlaWdodCI7aTowO319YXV0aG9yaXplX29wZXJhdGlvbnxhOjQ6e3M6ODoiY2FsbGJhY2siO3M6Mjg6InVwZGF0ZV9hdXRob3JpemVfcnVuX2luc3RhbGwiO3M6NDoiZmlsZSI7czozNToibW9kdWxlcy91cGRhdGUvdXBkYXRlLmF1dGhvcml6ZS5pbmMiO3M6OToiYXJndW1lbnRzIjthOjM6e3M6NzoicHJvamVjdCI7czo1OiJkZXZlbCI7czoxMjoidXBkYXRlcl9uYW1lIjtzOjEzOiJNb2R1bGVVcGRhdGVyIjtzOjk6ImxvY2FsX3VybCI7czozNzoiL3RtcC91cGRhdGUtZXh0cmFjdGlvbi1kOWU4MTUzOS9kZXZlbCI7fXM6MTA6InBhZ2VfdGl0bGUiO3M6MTQ6IlVwZGF0ZSBtYW5hZ2VyIjt9bWVzc2FnZXN8YToxOntzOjU6ImVycm9yIjthOjI6e2k6MDtzOjI3NToiPGVtIGNsYXNzPSJwbGFjZWhvbGRlciI+V2FybmluZzwvZW0+OiBhcnJheV9rZXlfZXhpc3RzKCkgZXhwZWN0cyBwYXJhbWV0ZXIgMiB0byBiZSBhcnJheSwgbnVsbCBnaXZlbiBpbiA8ZW0gY2xhc3M9InBsYWNlaG9sZGVyIj50aGVtZV9pbWFnZV9mb3JtYXR0ZXIoKTwvZW0+IChsaW5lIDxlbSBjbGFzcz0icGxhY2Vob2xkZXIiPjYwNTwvZW0+IG9mIDxlbSBjbGFzcz0icGxhY2Vob2xkZXIiPi92YXIvd3d3L2RydXBhbC9tb2R1bGVzL2ltYWdlL2ltYWdlLmZpZWxkLmluYzwvZW0+KS4iO2k6MTtzOjI3NToiPGVtIGNsYXNzPSJwbGFjZWhvbGRlciI+V2FybmluZzwvZW0+OiBhcnJheV9rZXlfZXhpc3RzKCkgZXhwZWN0cyBwYXJhbWV0ZXIgMiB0byBiZSBhcnJheSwgbnVsbCBnaXZlbiBpbiA8ZW0gY2xhc3M9InBsYWNlaG9sZGVyIj50aGVtZV9pbWFnZV9mb3JtYXR0ZXIoKTwvZW0+IChsaW5lIDxlbSBjbGFzcz0icGxhY2Vob2xkZXIiPjYwNTwvZW0+IG9mIDxlbSBjbGFzcz0icGxhY2Vob2xkZXIiPi92YXIvd3d3L2RydXBhbC9tb2R1bGVzL2ltYWdlL2ltYWdlLmZpZWxkLmluYzwvZW0+KS4iO319"
            }
        ],
        "drupal.shortcut_set_users": [],
        "drupal.users_roles": [
            {
                "uid": 1,
                "rid": 3
            }
        ],
        "drupal.watchdog": [
            {
                "wid": 160662,
                "uid": 1,
                "type": "php",
                "message": "JXR5cGU6ICFtZXNzYWdlIGluICVmdW5jdGlvbiAobGluZSAlbGluZSBvZiAlZmlsZSku",
                "variables": "YTo2OntzOjU6IiV0eXBlIjtzOjc6Ildhcm5pbmciO3M6ODoiIW1lc3NhZ2UiO3M6NjI6ImFycmF5X2tleV9leGlzdHMoKSBleHBlY3RzIHBhcmFtZXRlciAyIHRvIGJlIGFycmF5LCBudWxsIGdpdmVuIjtzOjk6IiVmdW5jdGlvbiI7czoyMzoidGhlbWVfaW1hZ2VfZm9ybWF0dGVyKCkiO3M6NToiJWZpbGUiO3M6NDU6Ii92YXIvd3d3L2RydXBhbC9tb2R1bGVzL2ltYWdlL2ltYWdlLmZpZWxkLmluYyI7czo1OiIlbGluZSI7aTo2MDU7czoxNDoic2V2ZXJpdHlfbGV2ZWwiO2k6NDt9",
                "severity": 4,
                "link": "0",
                "location": "aHR0cDovL2VjMi01MC0xOS0yOC0yNy5jb21wdXRlLTEuYW1hem9uYXdzLmNvbS9kcnVwYWwv",
                "referer": "aHR0cDovL2VjMi01MC0xOS0yOC0yNy5jb21wdXRlLTEuYW1hem9uYXdzLmNvbS9kcnVwYWwv",
                "hostname": "24.61.45.238",
                "timestamp": 1355406786
            }
        ]
    }
]
$
{% endhighlight %}

We also support multi-get so you can retrieve a number of table groups
in a single REST API call. For example, lets say I want to get
information on 2 users:

{% highlight console %}
$ curl -X GET -H "Content-Type: application/json" "http://ec2-50-19-28-27.compute-1.amazonaws.com:8091/api/drupal.users/11467;10503"
[
    {
        "uid": 11467,
        "name": "clibriprofr",
        "pass": "",
        "mail": "clibriprofr@default",
        "theme": "",
        "signature": "",
        "signature_format": null,
        "created": 1355360324,
        "access": 0,
        "login": 0,
        "status": 1,
        "timezone": null,
        "language": "und",
        "picture": 11463,
        "init": "",
        "data": null,
        "drupal.authmap": [],
        "drupal.sessions": [],
        "drupal.shortcut_set_users": [],
        "drupal.users_roles": [],
        "drupal.watchdog": []
    },
    {
        "uid": 10503,
        "name": "uuslosuwr",
        "pass": "",
        "mail": "uuslosuwr@default",
        "theme": "",
        "signature": "",
        "signature_format": null,
        "created": 1355360324,
        "access": 0,
        "login": 0,
        "status": 1,
        "timezone": null,
        "language": "und",
        "picture": 10499,
        "init": "",
        "data": null,
        "drupal.authmap": [],
        "drupal.sessions": [],
        "drupal.shortcut_set_users": [],
        "drupal.users_roles": [],
        "drupal.watchdog": []
    }
]
$
{% endhighlight %}

Our REST API also supports aribtrary SQL queries being executed and
results being returned as JSON. Lets try a simple example first:

{% highlight console %}
$ curl -X GET -H "Content-Type: application/json" "http://ec2-50-19-28-27.compute-1.amazonaws.com:8091/api/query?q=select%20count(*)%20from%20drupal.comment"
[
{"_SQL_COL_1":252462}
]
$
{% endhighlight %}

Another example of executing arbitrary SQL queries through our REST API
with a more complex query follows. The query we will use for this
example is:

{% highlight sql %}
SELECT c.* 
FROM   drupal.comment c 
       INNER JOIN drupal.node n 
               ON n.nid = c.nid 
WHERE  ( c.status = 1 ) 
       AND ( n.status = 1 ) 
ORDER  BY c.created DESC, 
          c.cid DESC 
LIMIT  10 offset 0 
{% endhighlight %}

Running this query through our REST API and the result (again, nicely
formatted) looks like:

{% highlight console %}
curl -X GET -H "Content-Type: application/json" "http://ec2-50-19-28-27.compute-1.amazonaws.com:8091/api/query?q=SELECT%20c.*%20FROM%20drupal.comment%20c%20INNER%20JOIN%20drupal.node%20n%20ON%20n.nid%20=%20c.nid%20WHERE%20(c.status%20=%201)%20AND%20(n.status%20=%201)%20ORDER%20BY%20c.created%20DESC,%20c.cid%20DESC%20LIMIT%2010%20OFFSET%200"
[
    {
        "cid": 304562,
        "pid": 0,
        "nid": 93450,
        "uid": 1,
        "subject": "this is a test comment",
        "hostname": "75.147.9.1",
        "created": 1355418376,
        "changed": 1355418376,
        "status": 1,
        "thread": "01/",
        "name": "posulliv",
        "mail": "",
        "homepage": "",
        "language": "und"
    },
    {
        "cid": 304561,
        "pid": 304558,
        "nid": 93451,
        "uid": 3636,
        "subject": "Defui Enim Gemino Luctus Occuro Paulatim",
        "hostname": "127.0.0.1",
        "created": 1355369527,
        "changed": 1355369527,
        "status": 1,
        "thread": "01.00/",
        "name": "devel generate",
        "mail": "devel_generate@example.com",
        "homepage": "",
        "language": "und"
    },
    {
        "cid": 304560,
        "pid": 0,
        "nid": 93451,
        "uid": 3633,
        "subject": "Abdo Ea Sudo Veniam Vulputate",
        "hostname": "127.0.0.1",
        "created": 1355369527,
        "changed": 1355369527,
        "status": 1,
        "thread": "03/",
        "name": "devel generate",
        "mail": "devel_generate@example.com",
        "homepage": "",
        "language": "und"
    },
    {
        "cid": 304559,
        "pid": 0,
        "nid": 93451,
        "uid": 3651,
        "subject": "Defui Euismod Letalis Nisl Utinam Vicis",
        "hostname": "127.0.0.1",
        "created": 1355369527,
        "changed": 1355369527,
        "status": 1,
        "thread": "02/",
        "name": "devel generate",
        "mail": "devel_generate@example.com",
        "homepage": "",
        "language": "und"
    },
    {
        "cid": 304558,
        "pid": 0,
        "nid": 93451,
        "uid": 3657,
        "subject": "Similis Te",
        "hostname": "127.0.0.1",
        "created": 1355369527,
        "changed": 1355369527,
        "status": 1,
        "thread": "01/",
        "name": "devel generate",
        "mail": "devel_generate@example.com",
        "homepage": "",
        "language": "und"
    },
    {
        "cid": 304557,
        "pid": 0,
        "nid": 93448,
        "uid": 3630,
        "subject": "Loquor Modo Ut",
        "hostname": "127.0.0.1",
        "created": 1355369527,
        "changed": 1355369527,
        "status": 1,
        "thread": "02/",
        "name": "devel generate",
        "mail": "devel_generate@example.com",
        "homepage": "",
        "language": "und"
    },
    {
        "cid": 304556,
        "pid": 0,
        "nid": 93448,
        "uid": 3648,
        "subject": "Abico Conventio Elit Quis",
        "hostname": "127.0.0.1",
        "created": 1355369527,
        "changed": 1355369527,
        "status": 1,
        "thread": "01/",
        "name": "devel generate",
        "mail": "devel_generate@example.com",
        "homepage": "",
        "language": "und"
    },
    {
        "cid": 304555,
        "pid": 0,
        "nid": 93447,
        "uid": 3646,
        "subject": "Dolor Immitto Metuo Veniam",
        "hostname": "127.0.0.1",
        "created": 1355369527,
        "changed": 1355369527,
        "status": 1,
        "thread": "04/",
        "name": "devel generate",
        "mail": "devel_generate@example.com",
        "homepage": "",
        "language": "und"
    },
    {
        "cid": 304554,
        "pid": 304553,
        "nid": 93447,
        "uid": 3633,
        "subject": "Defui Et Pertineo Premo Usitas",
        "hostname": "127.0.0.1",
        "created": 1355369527,
        "changed": 1355369527,
        "status": 1,
        "thread": "01.00.00/",
        "name": "devel generate",
        "mail": "devel_generate@example.com",
        "homepage": "",
        "language": "und"
    },
    {
        "cid": 304553,
        "pid": 304550,
        "nid": 93447,
        "uid": 3655,
        "subject": "Amet Gravis Inhibeo Roto Torqueo",
        "hostname": "127.0.0.1",
        "created": 1355369527,
        "changed": 1355369527,
        "status": 1,
        "thread": "01.00/",
        "name": "devel generate",
        "mail": "devel_generate@example.com",
        "homepage": "",
        "language": "und"
    }
]
$
{% endhighlight %}

Finally, I'd like to mention we have a [client][rest_client] for `node.js` that can be
used with our REST interface. To get information on the schemas in this
server and the grouping in the drupal schema, some code using this
client would look as follows:

{% highlight js %}
#!/usr/bin/env coffee

ak = require('./lib/akiban_rest.js')
_  = require('underscore')

log = (msg) ->
  () ->
    console.log("========")
    console.log(msg)
    console.log("--------")
    unless arguments[0].error
      _(arguments[0].body).forEach (x) ->
        console.log(x)
    console.log(arguments) if arguments[0].error
    console.log("--------")

x = new ak.AkibanClient()

x.version(log('the server version is'))
x.schemata(log('and these are all the schemata'))
x.groups('drupal', log('all groups in the drupal schema'))
{% endhighlight %}

The above can be run with the `coffee` command like so: `coffee
drupal.coffee`.

To retrieve a certain node with this client, the code would look like:

{% highlight js %}
#!/usr/bin/env coffee

ak = require('./lib/akiban_rest.js')
_  = require('underscore')

log = (msg) ->
  () ->
    console.log("========")
    console.log(msg)
    console.log("--------")
    unless arguments[0].error
      _(arguments[0].body).forEach (x) ->
        console.log(x)
    console.log(arguments) if arguments[0].error
    console.log("--------")

x = new ak.AkibanClient()
x.get 'drupal', 'node', 2054, (res) -> log('retrieving nid 2054')(res)
{% endhighlight %}

Running the above example results in output like:

{% highlight console %}
$ coffee drupal.coffee 
========
retrieving nid 2054
--------
{ nid: 2054,
  vid: 2054,
  type: 'page',
  language: 'und',
  title: 'Eros Iriure Pertineo Refoveo Roto Utrum',
  uid: 3661,
  status: 1,
  created: 1355369527,
  changed: 1355369527,
  comment: 0,
  promote: 1,
  sticky: 0,
  tnid: 0,
  translate: 0,
  'drupal.comment': [],
  'drupal.history': [],
  'drupal.node_access': [],
  'drupal.node_comment_statistics': 
   [ { nid: 2054,
       cid: 0,
       last_comment_timestamp: 1355369527,
       last_comment_name: null,
       last_comment_uid: 3656,
       comment_count: 0 } ],
  'drupal.node_revision': 
   [ { nid: 2054,
       vid: 2056,
       uid: 1,
       title: 'Ad Si Suscipere',
       log: '',
       timestamp: 1355369527,
       status: 1,
       comment: 0,
       promote: 1,
       sticky: 0 } ],
  'drupal.search_node_links': [] }
--------
{% endhighlight %}

Thats about it for this post showing off our REST access. As usual,
comments are very much welcome and feel free to ping me on
[twitter][my_twitter] if you would like to learn more about Akiban.

[mailing_list]: https://groups.google.com/a/akiban.com/d/forum/akiban-user)
[downloads]: http://akiban.com/downloads
[dries_post]: http://buytaert.net/using-the-akiban-database-with-drupal
[my_twitter]: https://twitter.com/intent/user?screen_name=posulliv
[docs_link]: http://www.akiban.com/ak-docs/admin/server/server.config.html
[akiban_drupal]: http://drupal.org/sandbox/posulliv/1835778
[drupal_7_on_akiban]: http://posulliv.github.com/drupal/2012/12/14/drupal-7-install-akiban/
[devel_link]: http://drupal.org/project/devel
[rest_client]: https://github.com/akiban/akiban-rest-js
