--- 
title: Akiban Server Cookbook for Chef
layout: post
category: akiban
---

Last week I spent some time putting together a cookbook for Akiban that
allows the Akiban Server to be easily deployed in environments where 
[chef](http://www.opscode.com/chef/) is used. This cookbook is currently 
available on [github](https://github.com/akiban/akiban-server-cookbook).

This cookbook uses the awesome new tool opscode announced last week - 
[Test Kitchen](http://www.opscode.com/blog/2012/08/17/announcing-test-kitchen/).
This makes testing of our cookbook extremely easy for us. Right now, the tests for
the Akiban Server cookbook are very similar to the tests developed
for the MySQL cookbook. On a system with `kitchen` installed, the cookbook
can be downloaded and tests run easily by simply running:

{% highlight console %}
kitchen test
{% endhighlight %}

Running the above results in a virtual machine being downloaded and 
started using `vagrant`. The virtual machine is then provisioned using
`chef` and the cookbook under test is set up. The Akiban Server cookbook
installs the PostgreSQL client (since the Akiban Server speaks the PostgreSQL
protocol) and the Akiban Server. The tests run to verify everything is working
ok are pretty simple at the moment: some data is loaded in to a single table 
and a few simple queries are run to make sure the database server is functioning
correctly.

One other item we implemented that was pretty neat was we use the Travis build
system to make sure our cookbook adheres to best practices by running 
[foodcritic](http://acrmp.github.com/foodcritic/) on every new push to master.

Test Kitchen and foodcritic together help us to ensure our cookbooks are high
quality. Our main goal is to make sure our customers enjoy the easiest deployment
process and since we see many people using `chef`, we wanted to make sure we integrate
well with environments where `chef` is in place.

I plan on doing a webinar in the near future on deploying Akiban Server with 
chef. In that webinar, I will be able to do some demos of deploying Akiban
in EC2 with `chef`.

