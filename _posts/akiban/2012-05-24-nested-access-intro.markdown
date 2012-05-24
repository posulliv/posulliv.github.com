--- 
title: How Akiban Saves Babies
layout: post
---

I came across an interesting article from Iggy Fernandez in the NoCOUG journal
[this month][nocoug_journal] that prompted me to write a short little post
showing a little of what we are working on at Akiban. Iggy also has a 
[blog post][iggy_post] that is pretty similar to the article.

We are big fans of the relational model and one thing that I loved about
Iggy's article was the re-iteration of the fact that Codd never dictated
how data should be stored. Hence, at Akiban we are working on a new relational
database that stores data in a different manner that we refer to as
[table grouping][table_grouping_link].

In this post, I wanted to briefly show how we could group the schema Iggy used
in his article and how that data can be retrieved. Below I show the DDL
for the tables as we would create them in Akiban. You will notice the one
addition in our DDL is the specification of a grouping foreign key. The DDL
below creates a single table group with the `employees` table as the root and
all other tables as children.

{% highlight bash %}
create table employees 
(
  emp_no int primary key not null,
  name varchar(16),
  birth_date date
);

create table job_history 
(
  emp_no int not null,
 job_date date not null,
 title varchar(16),
 grouping foreign key (emp_no) references employees
);

create table salary_history 
(
  emp_no int not null,
  job_date date not null,
  salary_date date not null,
  salary decimal,
  grouping foreign key (emp_no) references employees
);

create table children 
(
  emp_no int not null,
  child_name varchar(16) not null,
  birth_date date,
  grouping foreign key (emp_no) references employees
);

insert into employees values (1, 'IGNATIES', '1970-01-01');

insert into children values (1, 'INIGA', '2001-01-01');
insert into children values (1, 'INIGO', '2001-01-01');

insert into job_history values (1, '1991-01-01', 'PROGRAMMER');
insert into job_history values (1, '1992-01-01', 'DATABASE ADMIN');

insert into salary_history values (1, '1991-01-01', '1991-01-02', 1000);
insert into salary_history values (1, '1991-01-01', '1991-01-03', 1000);
insert into salary_history values (1, '1992-01-01', '1992-01-02', 2000);
insert into salary_history values (1, '1992-01-01', '1992-01-03', 2000);

test=> select * from employees;
 emp_no |   name   | birth_date 
--------+----------+------------
      1 | IGNATIES | 1970-01-01
(1 row)

Time: 3.529 ms
test=> select * from children;
 emp_no | child_name | birth_date 
--------+------------+------------
      1 | INIGA      | 2001-01-01
      1 | INIGO      | 2001-01-01
(2 rows)

Time: 4.058 ms
test=> select * from job_history;
 emp_no |  job_date  |     title      
--------+------------+----------------
      1 | 1991-01-01 | PROGRAMMER
      1 | 1992-01-01 | DATABASE ADMIN
(2 rows)

Time: 3.954 ms
test=> select * from salary_history;
 emp_no |  job_date  | salary_date | salary 
--------+------------+-------------+--------
      1 | 1991-01-01 | 1991-01-02  |   1000
      1 | 1991-01-01 | 1991-01-03  |   1000
      1 | 1992-01-01 | 1992-01-02  |   2000
      1 | 1992-01-01 | 1992-01-03  |   2000
(4 rows)

Time: 3.868 ms
test=>
{% endhighlight %}

Ok, now we have a simple dataset with 1 employee. In Akiban, all data for
that 1 employee is essentially stored pre-joined. I explained previously how
we accomplish this in a [post][hkey_post] on the company blog so I won't go
into detail here. 

Now what if I wanted to get all employee information for this person in 1 go?
In Iggy's article, Oracle's multi-table clustering functionality is used to make
sure doing that is efficient and then SQL/XML is used to query it and construct
a single XML document with all the employees information.

Well, in Akiban, we've implemented support for [nested SQL][nested_link]. This 
allows us to return data as objects instead of returning data in tabular form.
We decided to format the objects we return in JSON for our first implementation
of this functionality. Now if I want to get all information for employee 1 
in a single query with a nested result in JSON format, I simply need to enable
that mode in Akiban and issue a query like the one shown below.

{% highlight bash %}
select 
  employees.*,
  (select children.* from children where employees.emp_no = children.emp_no),                       
  (select job_history.* from job_history where employees.emp_no = job_history.emp_no),                
  (select salary_history.* from salary_history where employees.emp_no = salary_history.emp_no) 
from 
  employees
{% endhighlight %}

Ok, now to enable nested result sets and fire the query off. This is exactly
what the interaction with our system will look like.

{% highlight bash %}
test=> set OutputFormat = 'json';
SET OutputFormat
Time: 1.290 ms
test=> select 
test->   employees.*,
test->   (select children.* from children where employees.emp_no = children.emp_no),                       
test->   (select job_history.* from job_history where employees.emp_no = job_history.emp_no),                
test->   (select salary_history.* from salary_history where employees.emp_no = salary_history.emp_no) 
test-> from 
test->   employees;
                                                                                                                                                                                                                                                                                                                                         JSON                                                                                                                                                                                                                                                                                                                                          
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"emp_no":1,"name":"IGNATIES","birth_date":"1970-01-01","_SQL_COL_1":[{"emp_no":1,"child_name":"INIGA","birth_date":"2001-01-01"},{"emp_no":1,"child_name":"INIGO","birth_date":"2001-01-01"}],"_SQL_COL_2":[{"emp_no":1,"job_date":"1991-01-01","title":"PROGRAMMER"},{"emp_no":1,"job_date":"1992-01-01","title":"DATABASE ADMIN"}],"_SQL_COL_3":[{"emp_no":1,"job_date":"1991-01-01","salary_date":"1991-01-02","salary":"1000"},{"emp_no":1,"job_date":"1991-01-01","salary_date":"1991-01-03","salary":"1000"},{"emp_no":1,"job_date":"1992-01-01","salary_date":"1992-01-02","salary":"2000"},{"emp_no":1,"job_date":"1992-01-01","salary_date":"1992-01-03","salary":"2000"}]}
(1 row)

Time: 12.230 ms
test=>
{% endhighlight %}

If you scroll to the right above, you will see the nested result set with all
of the information for employee 1. Also notice that we have an easy way to
enable/disable nested result set functionality. Setting this format to 'table'
results in tabular output. The result set above nicely formatted is shown next.

{% highlight bash %}

{
    "emp_no": 1,
    "name": "IGNATIES",
    "birth_date": "1970-01-01",
    "_SQL_COL_1": [
        {
            "emp_no": 1,
            "child_name": "INIGA",
            "birth_date": "2001-01-01"
        },
        {
            "emp_no": 1,
            "child_name": "INIGO",
            "birth_date": "2001-01-01"
        }
    ],
    "_SQL_COL_2": [
        {
            "emp_no": 1,
            "job_date": "1991-01-01",
            "title": "PROGRAMMER"
        },
        {
            "emp_no": 1,
            "job_date": "1992-01-01",
            "title": "DATABASE ADMIN"
        }
    ],
    "_SQL_COL_3": [
        {
            "emp_no": 1,
            "job_date": "1991-01-01",
            "salary_date": "1991-01-02",
            "salary": "1000"
        },
        {
            "emp_no": 1,
            "job_date": "1991-01-01",
            "salary_date": "1991-01-03",
            "salary": "1000"
        },
        {
            "emp_no": 1,
            "job_date": "1992-01-01",
            "salary_date": "1992-01-02",
            "salary": "2000"
        },
        {
            "emp_no": 1,
            "job_date": "1992-01-01",
            "salary_date": "1992-01-03",
            "salary": "2000"
        }
    ]
}
{% endhighlight %}

Now there is no reason we could not decide to write an XML outputter in the
future. JSON is what we have gone with at the moment because we all like JSON
here and we have a few people who are not such big fans of XML.

Since this is nested SQL, I can just select what I want and filter the result 
set using predicates. Lets say I only want birth dates of children named
'INIGA' and salary history and job information for 'DATABASE ADMIN' role.
I can also give aliases to anything in my `SELECT` clause. 

I could write a query like the following:

{% highlight bash %}
select 
  employees.*,
  (select children.birth_date from children where employees.emp_no = children.emp_no and child_name = 'INIGA') as children, 
  (select job_history.job_date from job_history where employees.emp_no = job_history.emp_no and title = 'DATABASE ADMIN') as job, 
  (select salary_history.salary from salary_history where employees.emp_no = salary_history.emp_no and job_date = '1992-01-01') as salary
from 
  employees
{% endhighlight %}

The above query would return a result set like (after formatting):
 
{% highlight bash %}
{
    "emp_no": 1,
    "name": "IGNATIES",
    "birth_date": "1970-01-01",
    "children": [
        {
            "birth_date": "2001-01-01"
        }
    ],
    "job": [
        {
            "job_date": "1992-01-01"
        }
    ],
    "salary": [
        {
            "salary": "2000"
        },
        {
            "salary": "2000"
        }
    ]
}
{% endhighlight %}

Thats all I wanted to touch on in this post but  I aim to write a different post 
comparing table-grouping with Oracle multi-table clusters in the future. 
However, we do have a short piece of text discussing the 
[difference][zendesk_article] on our Zendesk portal.

Our nested SQL [quickstart guide][nested_quick_start] also has examples of
this functionality if you are interested in seeing more. In that quick-start,
we use the employees sample database from MySQL.

[nocoug_journal]: http://www.nocoug.org/Journal/NoCOUG_Journal_201205.pdf
[iggy_post]: http://iggyfernandez.wordpress.com/2012/04/07/relational-joins-are-expensive-by-definition-not/
[zendesk_article]: http://akiban.zendesk.com/entries/20779441-how-does-table-grouping-compare-to-oracle-cluster-tables
[table_grouping_link]: http://www.akiban.com/table-grouping
[nested_quick_start]: http://www.akiban.com/ak-docs/nested.html
[hkey_post]: http://www.akiban.com/blog/2011/09/22/introducing-hkey
[nested_link]: http://www.cs.utexas.edu/ftp/techreports/tr85-19.pdf
