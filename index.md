---
layout: page
---
{% include JB/setup %}

Welcome to Padraig's blog. I am a software engineer currently employed at
[Akiban Technologies](http://akiban.com)

## Latest Posts

<ul class="posts">
  {% for post in site.posts %}
    <li><span>{{ post.date | date_to_string }}</span> &raquo; <a href="{{ BASE_PATH }}{{ post.url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>


