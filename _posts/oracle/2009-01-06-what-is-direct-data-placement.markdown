--- 
wordpress_id: 41
layout: post
title: What is Direct Data Placement
wordpress_url: http://posulliv.com/?p=41
---
I'm currently studying Oracle's <a href="http://www.oracle.com/technology/products/bi/db/exadata/pdf/exadata-technical-whitepaper.pdf">white paper</a> on Exadata and came across the following paragraph:

"Further, Orace's interconnect protocol uses direct data placement (DMA - direct memory access) to ensure very low CPU overhead by directly moving data from the wire to database buffers with no extra data copies being made."

This got me wondering what direct data placement is. First off, the interconnect protocol which Oracle uses in Exadata is <a href="http://oss.oracle.com/projects/rds/">Reliable Datagram Sockets</a> (RDSv3). The iDB (intelligent database protocol) that a database server and Exadata Storage Server software use to communicate is built on RDSv3.

Now, I found some information on direct data placement in a number of RFCs; <a href="http://www.ietf.org/rfc/rfc4096.txt">RFC 4296</a>, <a href="http://tools.ietf.org/html/rfc4297">RFC 4297</a>, and <a href="http://www.apps.ietf.org/rfc/rfc5041.html">RFC 5041</a>. Of the 3 RFCs, I found RFC 5041 (Direct Data Placement over Reliable Transports) to be the most relevant (although they are all worth a quick look). RFC 5041 sums up direct data placement quite nicely:

"Direct Data Placement Protocol (DDP) enables an Upper Layer Protocol    (ULP) to send data to a Data Sink without requiring the Data Sink to    Place the data in an intermediate buffer - thus, when the data    arrives at the Data Sink, the network interface can place the data    directly into the ULP's buffer."

The paragraph from Oracle's white paper makes much more sense to me now after briefly reading through the RFC. Since each InfiniBand link in Exadata provides 16 Gb of bandwidth, there would be a large amount of overhead if data had to be placed in an intermediate buffer. Thus, the use of direct data placement makes perfect sense since it reduces CPU overhead associated with copying data through intermediate buffers.

Also, I believe that in the paragraph quoted from Oracle's white paper, it should be RDMA for Remote DIrect Memory Access.
