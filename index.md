---
layout: page
---
{% include JB/setup %}

Welcome to my personal blog. I am a software engineer currently employed at
[Akiban Technologies](http://akiban.com). 

For a full archive of all my posts, please see the [archive](archive.html).

## Latest Posts

<ul class="posts">
  {% for post in site.posts limit:10 %}
    <li><span>{{ post.date | date_to_string }}</span> &raquo; <a href="{{ BASE_PATH }}{{ post.url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>


