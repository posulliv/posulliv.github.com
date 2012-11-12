--- 
title: Why Build a New SQL Database?
layout: post
category: akiban
---

When I’m at conferences or meetups and people discover I work for a company
building a new database, there are usually a few puzzled looks. Explaining the
technology behind Akiban to people is easy but the usual reason for the
puzzlement is that many people wonder why on earth a company would want to
develop a new database from scratch when so many alternatives already exist.

There are good reasons, but I’ve struggled with articulating them especially
when someone wants a 90 second explanation at a conference.   In the interest
of having an answer that I can easily refer people to, here’s what I think
we’re trying to do.   These are the problems that Akiban is aiming to solve.

# Problems Akiban Solves

*1) The object-relational impedance mismatch*

Frequently referred to as the “vietnam of computer science” by some people,
this problem is defined by Wikipedia as:

“a set of conceptual and technical difficulties that are often encountered
when a relational database is being used by a program written in an OOO
programming language or style”

Typically, each class in an application is mapped to a table in the backend
database with the fields of that class being columns of the table and each
instance of that class is a row in the corresponding table. In Akiban,
application objects map to what we call table groups. Table groups are
fundamentally a way of storing data - we store data as interleaved rows in a
B+ Tree. Or more simply put, Akiban stores data hierarchically. 

This makes integration of Akiban with existing ORM’s an interesting proposition
since we expose methods of retrieving table groups directly through SQL. For
example, Mike Bayer recently implemented support for Akiban in the SQLAlchemy
[ORM for Python][bayer]. We are also working on support for Doctrine in the PHP
world and [ActiveRecord][akiban_ar] in the Ruby world. 

Dr. Eric Brewer also touched on this in his [closing talk][brewer_talk] at
[RICON 2012][ricon] (which seems to have been an excellent conference based on
the posted videos). One quote from Dr. Brewer that really stuck out in
my mind was - “instead of clean database where tables are joined at last
minute. I actually want to have pre-joined them. I don't really want to do
more than 1 query”. That ties in nicely with what we allow by exposing
methods to retrieve table groups or part of a table group with nested SQL i.e.
in 1 query, an entire table group or part of a table group can be retrieved.

*2) SQL (performance) doesn’t have to suck*

SQL gets a bad rap. I’m not 100% sure if that’s because people don’t like the
language or if it’s that people think that the performance of SQL queries are
terrible due to poor experiences. Perhaps its a little bit of both. What’s
great about SQL is that so-called ‘neck-tie’ programmers can easily use this
declarative language to interact with a database system. To quote again from
Dr. Brewer’s [RICON][ricon] talk - “having a language for them is a good idea.
nosql does not really talk to these people”.

SQL can be used to solve many problem types. I once heard someone quip, “there’s
a SQL query for that”, meaning it’s likely there are not many problems out there
SQL cannot solve. 

SQL performance in Akiban is greatly improved due to table grouping and the fact
that our entire system (in particular our query optimizer and execution engine)
is built from the ground up with this storage architecture in mind. First off,
queries that join tables within a single table group can execute without the
need for a [join operation][joinforfree]. This is due to how we store related
data in table groups hierarchically. Second, [group_indexes][group_indexes] can
be created on top of a table group. This means that indexes can be created on
columns from more than 1 table. Third, our optimizer can choose a number of
different query execution plans that use multiple indexes such as index
intersection and index merging thereby reducing the amount of data that needs
to be processed during various stages of query execution. 

*3) Do We Always Need ETL?*

Why is [ETL][etl_link] brought up as a solution when someone talks about running
complex reports? Obviously in some environments, an ETL process is absolutely
needed. But wouldn’t we ideally like to perform queries typically performed in
data warehouse environments in real-time without the requirement for a
separate process to be performed? This process is typically needed because
operational systems cannot handle the load that would be generated if complex
reports were run against them . Running these types of queries against an
operational system would likely cripple it (this is obviously a simplification
of a complex process). We’ve had many customers come to us running reports
against their operational database and they don’t feel like they should need to
construct a data warehouse for the relatively simple reports they wish to run on
their data. We tend to agree in some cases. 

Depending on who I am talking to, I either get someone really excited when I talk
about this (marketing/sales people get all excited due to buzz words like ETL and
real time) or am met with a groan and slight roll of the eyes (technical person who
thinks I am full of shit). I can see why it comes across sounding like something a
sales person would say without actually knowing what they are talking about. I do
feel our message here needs to be worked on but with the release of projects like
[Impala][impala] from Cloudera and [Spire][spire] from Drawn to Scale, I feel its
clear there is huge interest for a solution in this area. Akiban can help people
fighting these types of problems.

*4) Augmenting Existing Deployments*

Our long-term goal is to become the main database for a customer and the database
of choice when a developer starts a new project, but we understand its difficult
for someone who has developed an entire application with an existing database like
MySQL or PostgreSQL. What we have developed to deal with this reality is so called
adapters for existing systems. Our first publically available adapter is for 
[MySQL][akiban_mysql] and this allows a user to spin up a regular MySQL slave and
convert whatever tables they are interested in being part of a table group to Akiban.

# What Akiban is Not Good For (right now)

Now if you’ve read this far, you might be expecting me to list another problem that
we solve as world hunger or something like that. We of course have some uses cases
where we are not suitable and some drawbacks. So let’s balance the 4 problems I feel
Akiban solves with 4 reasons why you might be reluctant to use Akiban at
this present time.

*1) Scale out is coming, but not here yet.*

Today Akiban is focused on single node performance but with an eye to developing
scale out functionality in the near future. Our scale out capability is under
development but it is not expected to be production ready until next year.

This assumes you want to deploy Akiban as your main database. If you are
deploying Akiban as a MySQL replica in an existing MySQL environment, there
is no reason multiple MySQL slaves with Akiban cannot be spun up.

*2) Simple Queries or No Problems*

If your application really only issues simple queries and does not use an ORM,
then Akiban is not really a fit. I would be surprised if someone with such a
workload would be experiencing problems.

If your existing solution is working just fine for you, why change? You would
be surprised at the number of customers we talk to who really have no need for
our solution since they have no problems or are unlikely to have any
need for Akiban in the near future. We are of course happy to work with these
customers but we tell them straight up that they probably don’t need Akiban.

*3) Maturity*

Obviously many of the existing relational databases on the market today have a
head start on us here (PostgreSQL by almost 30 years). If you are looking for a
database solution that has been around for a long time and deployed countless
times, Akiban may not be what you are looking for. I will add though that we
have a few customers where we have been deployed for almost a year (public
customer testimonials coming in the next few weeks all going well).

However, I will say that this is another reason why we are working on adapters
for other database systems. If you are not comfortable trying out a new
database like Akiban, spinning it up as a slave in your staging/development
environment for testing purposes is a pretty low risk and will not affect any
existing infrastructure.

*4) Existing knowledge*

This leads on from point (4) above. If you have built a large infrastructure
on another database, its likely your staff is highly skilled in that database
platform. While Akiban is quite easy to use and administer, as with other
database systems, some knowledge of Akiban needs to be gained in order to use
the system in the best manner possible. Also since Akiban is a new solution,
not as much troubleshooting information is available publicly. For example,
when encountering an issue in MySQL, a simple Google search is likely to result
in being led to a page where someone else has documented a resolution for the
issue.

# Conclusion

This post was an honest attempt at stating what I personally think Akiban is a
great solution for and what we are currently not a good fit for. My personal
opinion (obviously biased since I work for Akiban) is that the problems we are
solving far outweigh the drawbacks of our solution. We will have a scale out
strategy in less than a year which is obviously important and you can be sure
I will be blogging about that as we develop it. I’d also like to mention that
points (3) and (4) that are dis-advantages of Akiban apply to any database
solution that is relatively new and so is not unique to Akiban.

Input on what we are doing at Akiban is very important to us. If you have any
comments that you would like to add, please leave them here or ask on our public
[mailing list][mailing_list]. Also, if you are curious to try the product out,
it can be downloaded for free [here][downloads].

[bayer]: http://techspot.zzzeek.org/2012/10/25/supporting-a-very-interesting-new-database/
[akiban_ar]: http://github.com/akiban/activerecord-akiban-adapter
[brewer_talk]: http://vimeo.com/52446728
[ricon]: http://basho.com/community/ricon2012/
[joinforfree]: http://www.akiban.com/blog/2011/08/24/join-for-free-explained/
[group_indexes]: http://www.akiban.com/blog/2011/08/24/group-indexes-in-action
[etl_link]: http://en.wikipedia.org/wiki/Extract,_transform,_load
[impala]: https://github.com/cloudera/impala
[spire]: http://drawntoscale.com/why-spire/
[akiban_mysql]: http://launchpad.net/akiban-adapter-mysql
[mailing_list]: https://groups.google.com/a/akiban.com/d/forum/akiban-user)
[downloads]: http://akiban.com/downloads
