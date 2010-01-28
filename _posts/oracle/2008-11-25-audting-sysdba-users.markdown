--- 
wordpress_id: 24
layout: post
title: Audting SYSDBA Users
wordpress_url: http://posulliv.com/?p=24
---
I recently came accross this feature in Oracle introduced in 9i where all operations performed by a user connecting as SYSDBA are logged to an OS file. I'm sure most DBA's are familiar with this
feature already but I have only just been enlightened!!

To enable this feature auditing must be enabled and the <span style="font-size: 85%; font-family: courier new;">AUDIT_SYS_OPERATIONS</span> parameter must be set to <span style="font-size:85%;"><span style="font-family: courier new;">TRUE</span></span>. For example:

<span style="font-size:85%;"><span style="font-family: courier new;">sys@ORCLINS1&gt; ALTER SYSTEM SET AUDIT_SYS_OPERATIONS = TRUE SCOPE=SPFILE;</span></span>

FALSE is the default value for this parameter. Pretty obvious from the above statement but the database must be restarted for the parameter to take affect.

All the audit records are then written to an operating system. The location of this file is determined by the <span style="font-size:85%;"><span style="font-family: courier new;">AUDIT_FILE_DEST</span></span> parameter.

<span style="font-size: 85%; font-family: courier new;">sys@ORCLINS1&gt; show parameter AUDIT_FILE_DEST</span>
<p class="MsoNormal" style="margin-bottom: 0.0001pt;"><span style="font-family: &quot;; font-size: 10;">NAME<span> </span>TYPE<span> </span>VALUE</span></p>
<p class="MsoNormal" style="margin-bottom: 0.0001pt;"><span style="font-family: &quot;; font-size: 10;">--------------  ------------------------------------------</span></p>
<p class="MsoNormal" style="margin-bottom: 0.0001pt;"><span style="font-family: &quot;; font-size: 10;">audit_file_dest<span> </span>string<span> </span>/oracle/oracle/admin/orclpad/adump</span></p>

<span style="font-family: &quot;; font-size: 10;">sys@ORCLINS1&gt;</span> <span style="font-family: &quot;; font-size: 10;">
</span>

An audit file will be created for each session started by a user logging in as SYSDBA. The audit file will contain the process ID of the server session that Oracle started for the user in its file name.

Most people are probably already familiar with this handy feature but I like to have it documented for myself somewhere so I put it here!
