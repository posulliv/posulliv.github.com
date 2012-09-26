--- 
title: Deploying Akiban on EC2 with Chef
layout: post
category: akiban
---

This post is a tutorial on how to deploy Akiban on an EC2 instance using chef
and the [Opscode Chef][hosted_chef] platform.

# The Opscode Platform

In this article, we'll use the Opscode platform since it provides an easy way
for anyone to get started with chef. If you are a new user, proceed to 
[sign up][hosted_signup] for a new account. Once you are signed up, the next
step is to create a new organization. For this article, I'm going to create
an organization named `akiban`. Once your organization is created, you should
see the organization in your list of organizations when you click on the 
`Organizations` link at the top right of the opscode console. My view looks
like:

<div>
  <img alt="Opscode console." src="/images/akiban_opscode_console.png" />
</div>
<br>

# Configure AWS

An assumption made in this article is that you have an [aws_link][AWS]
account. If you don't, signing up is relatively straightforward.

Amazon blocks all incoming traffic to EC2 instances by default and SSH is used
by chef to access and bootstrap a newly created instance. We want to allow
SSH traffic to our EC2 instances and I don't want to use the default security
group so for this article I created a new security group named `akiban` with
the appropriate rules (only SSH for now). After creating the new security group
and adding the SSH rule, the group details for `akiban` look like:

<div>
  <img alt="akiban security group." src="/images/akiban_sec_group.png" />
</div>
<br>

I also created a new key pair specifically for this article. I gave this key
pair the name `akiban`. After creating this key pair, I downloaded the private
key to my SSH folder and updated the permissions on the key:

{% highlight console %}
mv ~/Downloads/akiban.pem ~/.ssh/
chmod go-r ~/.ssh/akiban.pem
{% endhighlight %}

# Configure chef

This article assumes both chef and git are already installed on your workstation.
In my case, I ran all these commands on OSX laptop. Instructions for installing
chef can be found on [Opscode's wiki][chef_install].

The first thing to do is create a chef repository on your workstation with
`git` and get a clean history:

{% highlight console %}
git clone git://github.com/opscode/chef-repo.git ~/akiban-chef-repo
cd ~/akiban-chef-repo
rm -rf .git
git init .
git add *
git commit -a -m "Initial commit."
{% endhighlight %}

The [chef repository][chef_repos] is a version controlled directory that contains 
cookbooks and other components relevant to chef.

Next, create a `.chef` directory withing this repository. This directory 
contains all the configuration files for just this chef repository:

{% highlight console %}
mkdir -p ~/akiban-chef-repo/.chef
{% endhighlight %}

Next, we need to download keys and `knife` configuration files from the Opscode
platform that will be used for interacting with the Opscode platform. Keys are
needed for both your user and organization on the Opscode platform. To retrieve
your user key (if you did not download it when signing up), click on your
username through the console and click `View profile` on the right of that page.
Finally, click the `get private key` link on your account page as seen below:

<div>
  <img alt="User account profile." src="/images/akiban_chef_user.png" />
</div>
<br>

After downloading this new key, I placed it in the configuration directory for
the chef repository I am using for this article:

{% highlight console %}
mv ~/Downloads/posulliv.pen ~/akiban-chef-repo/.chef
{% endhighlight %}

For your organization, click on the `Regenerate validation key` link and 
`Generate knife config` link from the organizations home page. After clicking
those 2 links, you will have 2 files (dependent on your organization name
obviously): 1) `akiban-validator.pem` and 2) `knife.rb`. These 2 files must
be moved into the configuration directory for the chef repository being 
used for this article:

{% highlight bash %}
mv ~/Downloads/akiban-validator.pem ~/akiban-chef-repo/.chef
mv ~/Downloads/kinfe.rb ~/akiban-chef-repo/chef
{% endhighlight %}

Now, whenever we are in the `akiban-chef-repo` directory, the `knife` utility
will connect to the Opscode platform. To verify this, lets list out the current
clients our hosted chef server knows about:

{% highlight console %}
killarney:akiban-chef-repo posullivan$ knife client list
  akiban-validator
killarney:akiban-chef-repo posullivan$
{% endhighlight %}

Next, `knife` needs to be configured with the correct AWS credentials. This
is done by adding the following 2 lines to the `knife.rb` file in the
`~/akiban-chef-repo/.chef` directory:

{% highlight ruby %}
knife[:aws_access_key_id]     = "Your AWS Access Key"
knife[:aws_secret_access_key] = "Your AWS Secret Access Key"
{% endhighlight %}

After adding these credentials the EC2 instances associated with the AWS account
can be viewed:

{% highlight console %}
killarney:akiban-chef-repo posullivan$ knife ec2 server list
Instance ID  Public IP       Private IP      Flavor      Image         SSH Key        Security Groups  State  
i-1bcb4f77   50.16.188.89    10.112.233.119  t1.micro    ami-548c783d  akibanweb      AkibanWeb        running
i-f814fe97                                   m1.large    ami-548c783d  akibanxxx      akibanxxx        stopped
i-39474442   23.20.173.62    10.64.5.187     t1.micro    ami-aecd60c7  designpartner  designpartner    running
killarney:akiban-chef-repo posullivan$
{% endhighlight %}

# Akiban Cookbook

chef is now configured to work with the appropriate AWS account. Now we want
to bootstrap an EC2 instance with the latest early developer release of 
Akiban. I covered that we developed a cookbook for Akiban in my
[previous post][akiban_cookbook] and we place that in our chef repository 
as so:

{% highlight console %}
knife cookbook site install akibanserver
{% endhighlight %}

This downloads the latest release of the [akibanserver cookbook][ak_opscode]
from the opscode community site. Next, we want to upload this cookbook
to our hosted chef server:

{% highlight console %}
cd ~/akiban-chef-repo
knife cookbook upload akibanserver --include-dependencies
{% endhighlight %}

We can verify this cookbook (and its dependencies) are now available:

{% highlight console %}
killarney:akiban-chef-repo posullivan$ knife cookbook list
  akibanserver   0.1.0
  apt            1.4.8
  openssl        1.0.0
  postgresql     1.0.0
killarney:akiban-chef-repo posullivan$
{% endhighlight %}

# Create and Verify EC2 Instance

We are now ready to create an EC2 instance and have it bootstrap itself and 
install the Akiban developer edition! Feel free to pick any CentOS or Ubuntu
AMI you wish for the command below:

{% highlight console %}
knife ec2 server create \
--run-list akibanserver \
--image ami-2d4aa444 \
--flavor m1.small \
--groups akiban \
--ssh-key akiban \
--identity-file ~/.ssh/akiban.pem \
--ssh-user ubuntu \
--node-name akibantest \
--availability-zone us-east-1a
{% endhighlight %}

After kicking the above, you will see lots of output! Assuming the command
finishes successfully, to verify the server is created, first we check that it 
appears in the server list output from EC2:

{% highlight console %}
killarney:akiban-chef-repo posullivan$ knife ec2 server list
Instance ID  Public IP       Private IP      Flavor      Image         SSH Key        Security Groups  State  
i-1bcb4f77   50.16.188.89    10.112.233.119  t1.micro    ami-548c783d  akibanweb      AkibanWeb        running
i-f814fe97                                   m1.large    ami-548c783d  akibanxxx      akibanxxx        stopped
i-39474442   23.20.173.62    10.64.5.187     t1.micro    ami-aecd60c7  designpartner  designpartner    running
i-fd17d380   184.72.187.226  10.34.106.161   m1.small    ami-2d4aa444  akiban         akiban           running
killarney:akiban-chef-repo posullivan$
{% endhighlight %}

The chef server should also list this instance as a node now:

{% highlight console %}
killarney:akiban-chef-repo posullivan$ knife node list
akibantest
killarney:akiban-chef-repo posullivan$
{% endhighlight %}

The instance is now available and we can log on and start using the akiban 
server:

{% highlight console %}
killarney:akiban-chef-repo posullivan$ ssh -i ~/.ssh/akiban.pem ubuntu@184.72.187.226
Linux ip-10-34-106-161 2.6.32-305-ec2 #9-Ubuntu SMP Thu Apr 15 04:14:01 UTC 2010 i686 GNU/Linux
Ubuntu 10.04 LTS

Welcome to Ubuntu!
 * Documentation:  https://help.ubuntu.com/

  System information as of Wed Sep 26 20:28:34 UTC 2012

  System load: 0.54             Memory usage: 16%   Processes:       54
  Usage of /:  9.3% of 9.92GB   Swap usage:   0%    Users logged in: 0

  Graph this data and manage this system at https://landscape.canonical.com/
---------------------------------------------------------------------
At the moment, only the core of the system is installed. To tune the 
system to your needs, you can choose to install one or more          
predefined collections of software by running the following          
command:                                                             
                                                                     
   sudo tasksel --section server                                     
---------------------------------------------------------------------

New release 'precise' available.
Run 'do-release-upgrade' to upgrade to it.

A newer build of the Ubuntu lucid server image is available.
It is named 'release' and has build serial '20120913'.
*** System restart required ***
Last login: Wed Sep 26 20:23:13 2012 from 75-147-9-1-newengland.hfc.comcastbusiness.net
ubuntu@ip-10-212-87-144:~$ psql -h localhost -p 15432 information_schema
psql (8.4.13, server 8.4.7)
Type "help" for help.

information_schema=> select * from server_instance_summary;
  server_name  | server_version | instance_status |     start_time      
---------------+----------------+-----------------+---------------------
 Akiban Server | 1.4.1.2151     | RUNNING         | 2012-09-26 20:30:04
(1 row)

information_schema=> 
{% endhighlight %}

# Conclusion

Following the steps in this article, it should be pretty easy to spin up an
EC2 instance with Akiban installed on it with chef. We are currently starting
work on a cookbook for the Akiban Adapter for MySQL. When that is available,
a post detailing how to use that will be posted.

[hosted_chef]: http://www.opscode.com/hosted-chef/
[hosted_signup]: https://community.opscode.com/users/new
[aws_link]: http://aws.amazon.com/
[chef_install]: http://wiki.opscode.com/display/chef/Installation
[chef_repos]: http://wiki.opscode.com/display/chef/Chef+Repository
[akiban_cookbook]: http://posulliv.github.com/akiban/2012/08/22/akiban-chef/
[ak_opscode]: http://community.opscode.com/cookbooks/akibanserver
