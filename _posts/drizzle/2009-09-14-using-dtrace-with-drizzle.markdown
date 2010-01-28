--- 
wordpress_id: 175
layout: post
title: Using DTrace with Drizzle
wordpress_url: http://posulliv.com/?p=175
---
<p>Over the weekend, I was reading about the DTrace support in MySQL and realized that the DTrace support in drizzle needed to be updated. Thus, I created a branch and went to work on porting the latest probes from MySQL 6.0 to drizzle. I proposed a branch for merging into trunk which contains most of the relevant static probes along with some small build fixes to ensure that the probes are correctly enabled. Hopefully, this branch will get merged in the next week or two. In this post, I'm going to give some really simple examples of using the static probes in drizzle along with pointers to various places where lots more information can be obtained on using dtrace (mostly with MySQL but it all applies to drizzle too really).</p>
<h2>Building Drizzle with DTrace Support</h2>
<p>First of all, the drizzle binary built on a platform with dtrace is not configured with dtrace support by default. Thus, we need to configure drizzle by passing it the --enable-dtrace option. The rest of the build and installation process is the same as normal. Note that I have not tested dtrace support on OSX and I believe it probably does not work correctly at the moment. This is something I'll aim to fix (with help from Monty) in the next few weeks.</p>
<p>To verify that the probes were built correctly, you should get similar output when listing the probes available in dtrace:</p>
<br>

<code>
$ pfexec dtrace -l | grep drizzle | c++filt 
62444 drizzle11722          drizzled bool dispatch_command(enum_server_command,Session*,char*,unsigned) command-done
62445 drizzle11722          drizzled bool dispatch_command(enum_server_command,Session*,char*,unsigned) command-start
62446 drizzle11722          drizzled void Session::awake(Session::killed_state) connection-done
62447 drizzle11722          drizzled                 end_thread_signal connection-done
62448 drizzle11722          drizzled       void close_connections() connection-done
62449 drizzle11722          drizzled        bool Session::schedule() connection-start
62450 drizzle11722          drizzled bool mysql_delete(Session*,TableList*,Item*,st_sql_list*,unsigned long,unsigned long,bool) delete-done
62451 drizzle11722          drizzled bool drizzled::statement::Delete::execute() delete-start
62452 drizzle11722          drizzled unsigned long filesort(Session*,Table*,st_sort_field*,unsigned,SQL_SELECT*,unsigned long,bool,unsigned long*) filesort-done
62453 drizzle11722          drizzled unsigned long filesort(Session*,Table*,st_sort_field*,unsigned,SQL_SELECT*,unsigned long,bool,unsigned long*) filesort-start
62454 drizzle11722          drizzled bool mysql_insert(Session*,TableList*,List&amp;,List&lt;List &gt;&amp;,List&amp;,List&amp;,enum_duplicates,bool) insert-done
62455 drizzle11722          drizzled     void select_insert::abort() insert-select-done
62456 drizzle11722          drizzled  bool select_insert::send_eof() insert-select-done
62457 drizzle11722          drizzled bool drizzled::statement::InsertSelect::execute() insert-select-start
62458 drizzle11722          drizzled bool drizzled::statement::Insert::execute() insert-start
62459 drizzle11722          drizzled bool dispatch_command(enum_server_command,Session*,char*,unsigned) query-done
62460 drizzle11722          drizzled void mysql_parse(Session*,const char*,unsigned,const char**) query-exec-done
62461 drizzle11722          drizzled void mysql_parse(Session*,const char*,unsigned,const char**) query-exec-start
62462 drizzle11722          drizzled bool parse_sql(Session*,Lex_input_stream*) query-parse-done
62463 drizzle11722          drizzled bool parse_sql(Session*,Lex_input_stream*) query-parse-start
62465 drizzle11722          drizzled bool dispatch_command(enum_server_command,Session*,char*,unsigned) query-start
62466 drizzle11722          drizzled bool handle_select(Session*,LEX*,select_result*,unsigned long) select-done
62467 drizzle11722          drizzled bool handle_select(Session*,LEX*,select_result*,unsigned long) select-start
62468 drizzle11722          drizzled int mysql_update(Session*,TableList*,List&amp;,List&amp;,Item*,unsigned,order_st*,unsigned long,enum_duplicates,bool) update-done
62469 drizzle11722          drizzled int mysql_update(Session*,TableList*,List&amp;,List&amp;,Item*,unsigned,order_st*,unsigned long,enum_duplicates,bool) update-start
$
</code>

<h2>Example Usage</h2>
<p>I'm just going to show some sample scripts that I obtained from various other sources (these sources are listed later) related to DTrace with MySQL. The first simple script we will try measures query execution time (this does not include time for parsing):</p>
<pre>#!/usr/sbin/dtrace -s

#pragma ident   "%Z%%M% %I%     %E% SMI"

#pragma D option quiet
#pragma D option switchrate=10

dtrace:::BEGIN
{
        printf(" %-16s %5s %3s %s\n", "DATABASE", "ms",
            "RET", "QUERY");
}

drizzle*:::query-exec-start
{
        self-&gt;start = timestamp;
        this-&gt;query = copyinstr(arg0);
        this-&gt;db = arg2 ? copyinstr(arg2) : ".";
}

drizzle*:::query-exec-done
/self-&gt;start/
{
        this-&gt;elapsed = (timestamp - self-&gt;start) / 1000000;
        printf(" %-16.16s %5d %3d %-32.32s\n",
            this-&gt;db, this-&gt;elapsed, (int)arg0, this-&gt;query);
        self-&gt;start = 0;
}
</pre>
<p>The output from running that script on a toy instance of drizzle (unfortunately, I'm still a student so don't get to administer or play with any real databases) where I was running small queries is:</p>
<p><code><br />
$ pfexec dtrace -qp `pgrep drizzled` -s ./qestat.d<br />
 DATABASE            ms RET QUERY<br />
                      0   0 select @@version_comment limit 1<br />
                      0   0 show databases<br />
                      0   0 SELECT DATABASE()<br />
 test                 0   0 show databases<br />
 test                 0   0 show tables<br />
 test                 0   0 show tables<br />
 test                 0   0 select * from t1<br />
 test                 5   0 create table t1(a int)<br />
 test                 0   0 insert into t1 values (5), (6),<br />
 test                 0   0 select * from t1<br />
 test                 0   0 select a from t1 where a = 7<br />
^C<br />
$<br />
</code></p>
<p>Next, lets write a simple script that uses the filesort probe:</p>
<pre>#!/usr/sbin/dtrace -s

#pragma ident   "%Z%%M% %I%     %E% SMI"

#pragma D option quiet
#pragma D option switchrate=10

drizzle$target:::query-start
{
  self-&gt;query = copyinstr (arg0);
  self-&gt;query_start = timestamp ;
}

drizzle$target:::filesort-start
{
  self-&gt;filesort_start = timestamp;
}

drizzle$target:::filesort-done
{
  self-&gt;filesort = timestamp - self-&gt;filesort_start;
}

drizzle$target:::query-done
/ self-&gt;query != 0 /
{
  printf("%s\n", self-&gt;query);
  printf("Total: %dus Filesort: %dus\n",
            (timestamp - self-&gt;query_start) / 1000,
            self-&gt;filesort / 1000);
  self-&gt;query = 0;
}
</pre>
<p>The output from running that is (again, I have no data to play with here):</p>
<p><code><br />
$ pfexec dtrace -qp `pgrep drizzled` -s ./filesort.d<br />
select @@version_comment limit 1<br />
Total: 148us Filesort: 0us<br />
show databases<br />
Total: 595us Filesort: 0us<br />
SELECT DATABASE()<br />
Total: 114us Filesort: 0us<br />
show databases<br />
Total: 348us Filesort: 0us<br />
show tables<br />
Total: 274us Filesort: 0us<br />
show fields in 't1'<br />
Total: 112us Filesort: 0us<br />
show tables<br />
Total: 402us Filesort: 0us<br />
select * from t1<br />
Total: 292us Filesort: 0us<br />
select * from t1 order by a<br />
Total: 384us Filesort: 116us<br />
^C<br />
$<br />
</code></p>
<p>There is lots more that can be done. Have a look at the resources below for many more examples that can be tried out on drizzle. I'm just beginning to play with DTrace in my spare time really so I'm not aware of all its capabilities and use cases. It would be cool to see something similar to the <a href="http://opensolaris.org/os/community/dtrace/dtracetoolkit/">DTrace Toolkit</a> for drizzle though (like the Drizzle DTrace Toolkit...DDT).</p>
<h2>More Information</h2>
<p>A lot of articles and presentations have been produced on using DTrace with MySQL. Since the current probes in drizzle are just copied from MySQL, those are articles and presentations are still pretty useful to read if you want to play around with the dtrace probes in drizzle. Here are some good ones that I have come across:</p>
<ul>
<li><a href="http://assets.en.oreilly.com/1/event/21/DTrace%20Support%20in%20MySQL_%20Guide%20to%20Solving%20Real-life%20Performance%20Problems%20Presentation.pdf">DTrace Support in MySQL: Guide to Solving Real-life Performance Problems </a></li>
<li><a href="http://assets.en.oreilly.com/1/event/21/Deep-inspecting%20MySQL%20with%20DTrace%20Presentation.pdf">Deep-inspecting MySQL with DTrace</a></li>
<li><a href="http://forge.mysql.com/w/images/e/ec/MySQLUDTrace0901.pdf">Using DTrace with MySQL</a></li>
<li><a href="http://dev.mysql.com/tech-resources/articles/getting_started_dtrace_saha.html">Getting Started with DTracing MySQL</a></li>
<li><a href="http://www.solarisinternals.com/wiki/index.php/DTrace_Topics_Databases">DTrace Database Topics</a> (from the Solaris Internals wiki)</li>
</ul>
<h2>Future Work</h2>
<p>This is really just the beginning of adding dtrace support to drizzle. The largest issues right now are build related and ensuring that everything works correctly on both Solaris and OSX. The static probes that I defined were all copied from MySQL with some tiny modifications in places. I'd like to know what kind of probes other people would like to see? Does anyone have any suggestions or ideas? I'd really like to hear from people who actually administer databases on what they would like to see.</p>
<p>From a drizzle developer's perspective, one thing I hope to see in the future is the ability for plugins to add static probes if they wish. I also need to add the probes in the handler. The only reason those are not present at the moment is due to some build related issues that I hope to resolve in the next few weeks.</p>
