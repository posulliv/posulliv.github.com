--- 
wordpress_id: 29
layout: post
title: Temporary Tablespace Groups
wordpress_url: http://posulliv.com/?p=29
---
Temporary tablespace groups are a new feature introduced in Oracle10g. A temporary tablespace group is a list of tablespaces and is implicitly created when the first temporary tablespace is created. Its members can only be temporary tablespaces.

You can specify a tablespace group name wherever a tablespace name would appear when you assign a default temporary tablespace for the database or a temporary tablespace for a user. Using a tablespace group, rather than a single temporary tablespace, can alleviate problems caused where one tablespace is inadequate to hold the results of a sort, particularly on a table that has many partitions. A tablespace group enables parallel execution servers in a single parallel operation to use multiple temporary tablespaces.

<span style="font-weight: bold;">Group Creation</span>

You do not explicitly create a tablespace group. Rather, it is created implicitly when you assign the first temporary tablespace to the group. The group is deleted when the last temporary tablespace it contains is removed from it.

<span style="font-size:85%;"><span style="font-family: courier new;">SQL&gt; CREATE TEMPORARY TABLESPACE temp_test_1</span>
<span style="font-family: courier new;"> 2 TEMPFILE '/oracle/oracle/oradata/orclpad/temp_test_1.tmp'</span>
<span style="font-family: courier new;"> 3 SIZE 100 M</span>
<span style="font-family: courier new;"> 4 TABLESPACE GROUP temp_group_1;</span></span>

<span style="font-family: courier new;">Tablespace created.</span>

<span style="font-family: courier new;">SQL&gt;</span>

If the group <span style="font-size:85%;"><span style="font-family: courier new;">temp_group_1</span></span> did not already exist, it would be created at this time. Now we will create a temporary tablespace but will not add it to the group.

<span style="font-size:85%;"><span style="font-family: courier new;">SQL&gt; CREATE TEMPORARY TABLESPACE temp_test_2</span>
<span style="font-family: courier new;"> 2 TEMPFILE '/oracle/oracle/oradata/orclpad/temp_test_2.tmp'</span>
<span style="font-family: courier new;"> 3 SIZE 100 M</span>
<span style="font-family: courier new;"> 4 TABLESPACE GROUP '';</span></span>

<span style="font-family: courier new;">Tablespace created.</span>

<span style="font-family: courier new;">SQL&gt;</span>

Now we will alter this tablespace and add it to a group.

<span style="font-size:85%;"><span style="font-family: courier new;">SQL&gt; ALTER TABLESPACE temp_test_2</span>
<span style="font-family: courier new;"> 2 TABLESPACE GROUP temp_group_1;</span></span>

<span style="font-family: courier new;">Tablespace altered.</span>

<span style="font-family: courier new;">SQL&gt;</span>

To de-assign a temporary tablespace from a group, we issue an <span style="font-size:85%;"><span style="font-family: courier new;">ALTER TABLESPACE</span></span> command as so:

<span style="font-size:85%;"><span style="font-family: courier new;">SQL&gt; ALTER TABLESPACE temp_test_2</span>
<span style="font-family: courier new;"> 2 TABLESPACE GROUP '';</span></span>

<span style="font-family: courier new;">Tablespace altered.</span>

<span style="font-family: courier new;">SQL&gt;</span>

<span style="font-weight: bold;">Assign Users to Temporary Tablespace Groups</span>

In this example, we will assign the user <span style="font-size:85%;"><span style="font-family: courier new;">SCOTT</span></span> to the temporary tablespace group <span style="font-size:85%;"><span style="font-family: courier new;">temp_group_1</span></span>.

<span style="font-size:85%;"><span style="font-family: courier new;">SQL&gt; ALTER USER scott</span>
<span style="font-family: courier new;"> 2 TEMPORARY TABLESPACE temp_group_1;</span></span>

<span style="font-family: courier new;">User altered.</span>

<span style="font-family: courier new;">SQL&gt;</span>

Now when we query the <span style="font-size:85%;"><span style="font-family: courier new;">DBA_USERS</span></span> view to see <span style="font-size:85%;"><span style="font-family: courier new;">SCOTT</span></span>'s default temporary tablespace, we will see that the group is his temporary tablespace now.
<span style="font-size:85%;">
<span style="font-family: courier new;">SQL&gt; SELECT username, temporary_tablespace</span>
<span style="font-family: courier new;"> 2 FROM DBA_USERS</span>
<span style="font-family: courier new;"> 3 WHERE username = 'SCOTT';</span></span>

<span style="font-family: courier new;">USERNAME TEMPORARY_TABLESPACE</span>
<span style="font-family: courier new;">-------- ------------------------------</span>
<span style="font-family: courier new;">SCOTT    TEMP_GROUP_1</span>

<span style="font-family: courier new;">SQL&gt;</span>

<span style="font-weight: bold;">Data Dictionary Views</span>

To view a temporary tablespace group and it smembers we can view the <span style="font-size:85%;"><span style="font-family: courier new;">DBA_TABLESPACE_GROUPS</span></span> data dictionary view.

<span style="font-size:85%;"><span style="font-family: courier new;">SQL&gt; SELECT * FROM DBA_TABLESPACE_GROUPS;</span></span>

<span style="font-family: courier new;">GROUP_NAME   TABLESPACE_NAME</span>
<span style="font-family: courier new;">------------ ------------------------------</span>
<span style="font-family: courier new;">TEMP_GROUP_1 TEMP_TEST_1</span>
<span style="font-family: courier new;">TEMP_GROUP_1 TEMP_TEST_2</span>

<span style="font-family: courier new;">SQL&gt;</span>

<span style="font-weight: bold;">Advantages of Temporary Tablespace Groups</span>
<ul>
	<li>Allows multiple default temporary tablespaces</li>
	<li>A single SQL operation can use muultiple temporary tablespaces for sorting</li>
	<li>Rather than have all temporary I/O go against a single temporary tablespace, the database can distribute that I/O load among all the temporary tablespaces in the group.</li>
	<li>If you perform an operation in parallel, child sessions in that parallel operation are able to use multiple tablespaces.</li>
</ul>
