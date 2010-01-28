--- 
wordpress_id: 113
layout: post
title: Debugging Drizzle with GDB
wordpress_url: http://posulliv.com/?p=113
---
While working with Drizzle this week for my <a href="http://drizzle.org/wiki/GSOC_Information_Schema">GSoC project,</a> I've been going through the source code to understand how INFORMATION_SCHEMA is currently implemented. Reading through the source code is obviously the best way to understand the logic behind the current I_S implementation but using a debugger to step through the execution of this code can be extremely helpful in speeding up this process. <a href="http://torum.net/">Toru</a> previously published a <a href="http://torum.net/2009/03/drizzle-gdb-osx/">related post</a> on debugging Drizzle with gdb which may also be useful.

As Toru mentioned in his post, attaching gdb to Drizzle can be quite simple:

[gist id=115664]

The above commands will open a xterm window with a gdb session started that is attached to the Drizzle server process. While this works fine, sometimes I am working on a remote machine and don't want to go to the hassle of setting up something like X11 forwarding or VNC to attach gdb to the server process. Also, while going through the I_S related code, I wanted to step through the code which occurs on server startup i.e. the things which happen before the xterm window with gdb opens as outlined above.

Thus, I wrote the following simple script that I use to debug Drizzle with gdb.

[gist id=115654]

This script takes as an argument the path to the root of a Drizzle build directory. It then simply checks to see if Drizzle is running already or not. If it is already running, it will attach gdb to the Drizzle process in the current terminal window, for example:

[gist id=115668]

If Drizzle is not already running, the script starts gdb so we can then kick Drizzle off ourselves within gdb and debug the server startup, for example:

[gist id=115671]

That's about all I have for this post. As you can see, attaching gdb to Drizzle is a pretty straightforward process. I like to use my script mainly on remote servers but I also find it useful when I want to debug server startup on my local box too.
