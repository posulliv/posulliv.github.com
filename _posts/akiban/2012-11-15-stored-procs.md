--- 
title: Stored Procedures in Akiban
layout: post
category: akiban
---

This week, we released [version 1.4.3][downloads] of
Akiban. This release has a bunch of great new features and bug fixes in
it. There is one new feature in this release in particular that I wanted
write about today. Akiban now has a preview implementation of stored
procedures!

Now that may not sound too exciting in itself so please bear with me.
What gets me excited about this feature is that in Akiban, we allow
creation of stored procedures in a multitude of languages. Stored
procedures can be implemented using:

* Java
* Javascript
* Ruby
* Python
* Groovy
* Clojure

That’s a pretty nice selection! I’m going to show some examples in Ruby
here and if people are interested in more examples, please let me know
in the comments and I’ll be sure to whip up other examples in different
languages.

First things first and we need to make sure Akiban is configured to
allow the creation of stored procedures in Ruby. We have a pretty simple
property that controls the class path for our stored procedure scripting
languages - akserver.routines.class_path. I just need to make sure that
property has an absolute path to where my [JRuby][jruby_link] jar
is installed on my system. Once that property is set in my
[server.properties][docs_link] file, I can restart Akiban and I’m ready to go. 

Lets start with a simple example. I just want to call a function that
prints out my name. 

{% highlight ruby %}
CREATE PROCEDURE my_name(out name VARCHAR(128))
  LANGUAGE ruby PARAMETER STYLE variables AS $$
    name = 'padraig'
$$;
{% endhighlight %}

Now let’s call that stored procedure from the command line:

{% highlight console %}
test=> call my_name();
  name   
---------
 padraig
(1 row)

test=> 
{% endhighlight %}

Success! Our hello world example is up and running.

We don’t just have to return simple data types like that. We can also
return ruby hashes. For example, here is a stored procedure that returns
a ruby hash:

{% highlight ruby %}
CREATE PROCEDURE ruby_hash(IN x BIGINT, IN y DOUBLE, OUT s DOUBLE, OUT p
DOUBLE)
  LANGUAGE ruby PARAMETER STYLE variables AS $$
{ "p" => $x * $y,
  "s" => $x + $y }
$$;
{% endhighlight %}

Notice this example also demonstrates how to pass parameters to a stored
procedure. Running the above stored procedure, we get:

{% highlight console %}
test=> call ruby_hash(10, 100);
   s   |   p    
-------+--------
 110.0 | 1000.0
(1 row)

test=>
{% endhighlight %}

A common example used when demonstrating a programming language is to
implement a function to compute [Fibonaaci numbers][fib_link]. Hence,
here is a stored procedure to do just that:

{% highlight ruby %}
CREATE PROCEDURE fib_r(IN x DOUBLE, OUT s DOUBLE)
  LANGUAGE ruby PARAMETER STYLE java EXTERNAL NAME 'do_fib' AS $$
    def do_fib(x, s)
      s[0] = fib(x)
    end
    def fib(n)
      n < 2 ? n : fib(n - 1) + fib(n - 2)
    end
$$;
{% endhighlight %}

In the code above, note that `PARAMETER STYLE java` means that the
function named with `EXTERNAL NAME` takes as many positional arguments as
there are parameters. And an example of running it:

{% highlight console %}
test=> call fib_r(10);
  s   
------
 55.0
(1 row)

test=>
{% endhighlight %}

A common technique used to speed up this implementation is to use
memoization. A stored procedure that uses this technique follows:

{% highlight ruby %}
CREATE PROCEDURE fib_non_r(IN x DOUBLE, OUT s DOUBLE)
  LANGUAGE ruby PARAMETER STYLE java EXTERNAL NAME 'do_fib' AS $$
    def do_fib(x, s)
      s[0] = fib(x)
    end
    $fibonacci = Hash.new{ |h,k| h[k] = k < 2 ? k : h[k-1] + h[k-2] }
    def fib(n)
      $fibonacci[n]
    end
$$;
{% endhighlight %}

Lets turn on some timing and compare the recursive version versus the
version that uses memoization.

{% highlight console %}
test=> call fib_r(30);
    s     
----------
 832040.0
(1 row)

Time: 469.492 ms
test=>

test=> call fib_non_r(30);
    s     
----------
 832040.0
(1 row)

Time: 4.649 ms
test=>
{% endhighlight %}

As expected, the version that uses memoization is much better.  Next I’m
going to write a stored procedure that returns some data from a query.
Let’s say I create a simple table and insert some data into it like so:

{% highlight console %}
test=> create table t1(id int);
CREATE TABLE
test=> insert into t1 values (1), (2), (3), (4), (5), (6);
INSERT 0 6
test=>
{% endhighlight %}

This stored procedure will return all the data from that table and order
it by ID. A simple procedure to do that is:

{% highlight ruby %}
CREATE PROCEDURE get_data()
  LANGUAGE ruby PARAMETER STYLE variables AS $$
    conn =
java.sql.DriverManager.get_connection("jdbc:default:connection")
    conn.create_statement.execute_query("SELECT id FROM t1 ORDER BY id
DESC")
$$;
{% endhighlight %}

And let’s call the stored procedure and see what kind of results we get:

{% highlight console %}
test=> call get_data();
 id 
----
  6
  5
  4
  3
  2
  1
(6 rows)

test=>
{% endhighlight %}

As a last example, I want to extend this example and have an input
parameter that filters the query results to only return ID values that
are greater than whatever the input value is. 

{% highlight ruby %}
CREATE PROCEDURE get_data(IN filter BIGINT)
  LANGUAGE ruby PARAMETER STYLE variables AS $$
    conn =
java.sql.DriverManager.get_connection("jdbc:default:connection")
    conn.create_statement.execute_query("SELECT id FROM t1 WHERE id >
#{$filter} ORDER BY id DESC")
$$;
{% endhighlight %}

Running the above procedure with a valid input value yields:

{% highlight console %}
test=> call get_data(2);
 id 
----
  6
  5
  4
  3
(4 rows)

test=>
{% endhighlight %}

The above were some simple examples of writing stored procedures in Ruby
with Akiban. I’ll likely write another post with some more advanced
examples when I get a chance. If this interested you, definitely
download the [1.4.3 release][downloads] and play around
with it to try this out for yourself. If anybody has any questions or
would like more examples and information, please ask in the comments or
on our [public mailing list][mailing_list] and I’ll be happy to answer. 

[jruby_link]: http://jruby.org/
[docs_link]: http://www.akiban.com/ak-docs/admin/server/server.properties.html
[fib_link]: http://en.wikipedia.org/wiki/Fibonacci_number
[mailing_list]: https://groups.google.com/a/akiban.com/d/forum/akiban-user)
[downloads]: http://akiban.com/downloads
