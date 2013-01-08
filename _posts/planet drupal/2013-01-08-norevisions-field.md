--- 
title: Testing an Alternate Field SQL Storage Module
layout: post
category: planet drupal
---

After my [post yesterday][field_storage_tests] testing the field storage
layer, a commentator pointed out an alternate [SQL storage
module][norevision_module] that does not create a revision table for
each field. Naturally, I had to try this out to see how what kind of
performance was possible with this approach.

The average throughput numbers I observed using this module are shown in
the table below.

<table border="1">
  <tr>
    <th>Environment</th>
    <th>Average Throughput</th>
  </tr>
  <tr>
    <td>Default MySQL</td>
    <td>2892 nodes / minute</td>
  </tr>
  <tr>
    <td>Default PostgreSQL</td>
    <td>2313 nodes / minute</td>
  </tr>
  <tr>
    <td>Tuned MySQL</td>
    <td>4730 nodes / minute</td>
  </tr>
  <tr>
    <td>Tuned PostgreSQL</td>
    <td>2464 nodes / minute</td>
  </tr>
</table>

The image below shows the results graphically for different environments
I tested. The Y axis is throughput (node per minute) with the X axis specifying the CSV
file (corresponding to a MLB year) being imported.

<div>
  <img alt="Throughput numbers."
src="/images/field_norevision_throughput.png"/>
</div>
<br>

That's a pretty big improvement over the numbers I got in my original
test. We still are not approaching the 8000 nodes per minute that is
possible with a tuned MySQL instance and MongoDB for field storage but
at about 5000 nodes per minute, we are getting somewhat close. It does beg the
question of whether the performance benefits of MongoDB for field
storage are worth it when we can get somewhat close using this module
and a site's original database system?

I would be interested in suggestions for read benchmarks from the
community for different field storage backends so I can attempt to
gain more insight into this question for myself.

[field_storage_tests]: http://bit.ly/Wo9BeF
[norevision_module]: http://drupal.org/project/field_sql_norevisions
