--- 
title: PostgreSQL Protocol in Akiban Server
layout: post
category: postgres
---

Last week I was at [OSCON][oscon_link] with [Akiban][akiban_link] where I did a
demo during [Ori's][ori_link] [talk][oscon_slides].
We announced our [early developer release][download_link] at OSCON and it was
a lot of fun to be able to show people our product at our booth. It was also 
satisfying to see users download and try out the product we've been working on.
I'm hoping our [source code][code_link] will also be made publically available 
in the near future.

One of the common questions we got during the conference was why we implemented
the PostgreSQL protocol. Some people were also confused thinking that we were a
fork of PostgreSQL due to this. Akiban Server is a completely independent database
server we've built from the ground up and when it came time to decide on a 
communication protocol, we decided that the PostgreSQL protocol was the best
choice.

The main reasons we chose the PostgreSQL protocol are:

 * the protocol is pretty simple and well [documented][proto_link]
 * many clients exist for PostgreSQL and can be re-used with Akiban (this means
   we do not have to spend a lot of time on client drivers)
 * the PostgreSQL command line tool and client library ships with OSX by default now
   (making playing with our server much easier)
 * it supports asynchronous operations

We (really when I say we, I mean [Mike][mike_link]) also implemented support
for a number of PostgreSQL system tables in order to support many of the `\d`
commands in `psql` by creating views internally.

If you are interested in trying it out, I encourage you to download our 
server and start playing with it. Try using your favorite PostgreSQL tools with
it and see if they break. We are very interested in any and all feedback!

[oscon_link]:    http://www.oscon.com/oscon2012
[akiban_link]:   http://www.akiban.com/
[ori_link]:      http://renormalize.org/
[oscon_slides]:  http://www.oscon.com/oscon2012/public/schedule/detail/26439
[download_link]: http://www.akiban.com/download-akiban-server
[code_link]:     http://launchpad.net/akiban
[proto_link]:    http://www.postgresql.org/docs/9.1/static/protocol.html
[mike_link]:     http://www.akiban.com/profile/mike-mcmahon
