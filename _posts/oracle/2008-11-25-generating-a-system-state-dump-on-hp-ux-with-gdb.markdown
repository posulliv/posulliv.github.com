--- 
wordpress_id: 30
layout: post
title: Generating a System State Dump on HP-UX with gdb
wordpress_url: http://posulliv.com/?p=30
---
I have previously used the gdb (GNU Debugger) to generate oracle system state dumps on Linux systems by attaching to an Oracle process. The ability to do this has been well documented by Oracle on <a href="http://metalink.oracle.com/">Metalink</a> (Note 121779.1) and in <a href="http://el-caro.blogspot.com/search/label/systemstate%20dump">other locations</a>.

The problem with this is that it does not work on the HP-UX platform. I found this out at the wrong time when trying to generate a system state dump during a database hang!

Apparently, the Oracle executable needs to be re-linked on the HP-UX platform to enable the gdb debugger to generate system state dumps by attaching to an Oracle process.

You can see all the gory details in Metalink Note 273324.1. I posted it here as I thought it might prove useful for me to have this information somewhere should I forget it in the future...
