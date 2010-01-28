--- 
wordpress_id: 86
layout: post
title: Semester Project
wordpress_url: http://posulliv.com/?p=86
---
This semester I'm taking a <a href="http://www.cs.umd.edu/class/spring2009/cmsc724/" target="_blank">course</a> in database management systems. For this course, we have to work on a mini-research project in groups. I'm in a group with 2 other students and the project we decided on was to perform an experimental evaluation of the <a href="http://www.vldb.org/conf/2003/papers/S10P01.pdf" target="_blank">mJoin</a> operator. This will involve surveying the prior work on the mJoin operator and performing an implementation of the operator in an open-source DBMS.

The mJoin operator is essentially an n-ary symmetric hash join operator. For each relation to be joined, a hash table is built on each join attribute. Then for each new tuple, it is inserted into the appropriate hash table(s) and a probe is performed into the hash tables on the other relations. Intermediate tuples are never stored anywhere. One of the issues we will be investigating in this experimental evaluation is whether an operator like the mJoin is more or less efficient than a tree of binary joins. Conventional wisdom says that a tree of binary joins is typically more efficient.

The first thing we will be doing in the next week or two is looking at various open-source databases and seeing which one would be most suited for us to work with for this project. Basically, the main criteria will be how easy the runtime engine is to work with and how easy it will be to add a new operator. We'll have a look at a lot of databases but at the moment, its looking like Postgresql is the one we will work with for the semester. We'll also be looking into any related work. The <a href="http://www.cs.umd.edu/~amol/papers/fnt-aqp.pdf" target="_blank">survey</a> on adaptive query processing looks like a good starting point for this.

Some other interesting aspects of the mJoin operator which we hope to investigate are:
<ul>
	<li>query optimization with the mJoin operator</li>
	<li>what applications would benefit from an operator such as this</li>
	<li>what kind of scenarios is the operator suited for (and not suited for)</li>
	<li>how difficult it is to add the operator to an existing DBMS</li>
</ul>
I'll try to post regularly throughout the semester on what we are up to and provide updates on what kind of progress we are making. In the meantime, besides working on this project, I'm trying to contribute to <a href="https://launchpad.net/drizzle" target="_blank">Drizzle</a> in as many ways as I possibly can. I'm mostly working on small bugs and performing some code cleanup tasks.
