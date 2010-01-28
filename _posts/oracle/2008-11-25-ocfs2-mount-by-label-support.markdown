--- 
wordpress_id: 27
layout: post
title: OCFS2 Mount by Label Support
wordpress_url: http://posulliv.com/?p=27
---
While messing around with OCFS2 on my RHEL4 install, I discovered that if I created an OCFS2 filesystem with a label, I was unable to mount it by that label. I would encounter the following:

<span style="font-family: courier new;"># mount -L "oradata" /ocfs2</span>
<strong style="font-family: courier new;">mount: no such partition found
</strong><span style="font-family: courier new;">#</span>

I found this quite strange and did some investigation. The version of util-linux that was present on my system after a fresh RHEL 4 install was <em>-</em><em> util-linux-2.12a-16.EL4.6.</em>

<em></em>After doing some research online, I discovered that in the latest versions of util-linux, Oracle has included a patch for mounting an OCFS2 filesystem by label.

So I grabbed the latest version of util-linux from Red Hat and viola, I am now able to mount an OCFS2 filesystem by its label.

The current version of util-linux on my system is - <em> util-linux-2.12a-16.EL4.20.</em>
