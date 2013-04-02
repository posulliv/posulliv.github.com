--- 
title: Akiban is Now Open Source
layout: post
category: planet drupal
---

I've written a lot about the work I do for [Akiban][akiban_home] with
Drupal in the past and many
people would ask if Akiban was open source software. Well in the last few
weeks we actually open sourced our [database server][github_mirror]. We
also have [downloads][installers_link] for various platforms such as
Windows and OSX besides binary packages for Linux variants.

I [wrote previously][prev_akiban_post] about how to install Drupal 7
completely on [Akiban][akiban_home]. You can still follow that post to
get up and running except now there is a tiny change for our public
repositories:

{% highlight console %}
sudo apt-get install -y python-software-properties
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 0AA4244A
sudo add-apt-repository "deb http://software.akiban.com/apt-public/ lucid main"
sudo apt-get update
sudo apt-get install -y akiban-server postgresql-client
{% endhighlight %}

Some of the things included in our open source database are:

* [spatial indexes][spatial_idx]
* [full text indexes][ft_idx] (implemented using Lucene)
* [REST access][rest_access]
* [nested SQL][nested_sql]

We are also working on offering on a service offering for our database
server so there will be no need to manage an installation yourself. If
you are interested in trying our service in its current beta form,
please let me know in the comments or hit me up on [twitter][my_twitter]
and I'd be happy to hook you up or just visit our [website][akiban_home]. We also have a [public mailing
list][mailing_list] for the Akiban project if you try anything out and
have any questions.

[prev_akiban_post]: http://posulliv.github.com/2012/12/14/drupal-7-install-akiban/
[akiban_home]: http://akiban.com/
[mailing_list]: https://groups.google.com/a/akiban.com/d/forum/akiban-user
[my_twitter]: https://twitter.com/intent/user?screen_name=posulliv
[akiban_drupal]: http://drupal.org/sandbox/posulliv/1835778
[installers_link]: http://software.akiban.com/releases/1.6.0/installers/
[github_mirror]: http://github.com/akiban/akiban-server
[spatial_idx]: http://docs.akiban.org/en/latest/service/spatial.html
[ft_idx]: http://docs.akiban.org/en/latest/service/fulltext.html
[rest_access]: https://akiban.readthedocs.org/en/latest/service/restapireference.html
[nested_sql]: https://akiban.readthedocs.org/en/latest/quickstart/nested.html
