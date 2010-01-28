--- 
wordpress_id: 42
layout: post
title: A Subtle Bug
wordpress_url: http://posulliv.com/?p=42
---
At university, I work in a research group where we are developing an application in C++ that runs on both Linux and Windows. Since I do most of my development on Linux, I rarely test our application on Windows (other people in the group who run Windows test on that platform). Recently, one of my colleagues was encountering a problem while running our application on Windows that I was not encountering when running it on Linux.

I was able to track the issue down a single piece of code and produce a simple test case which produced the same problem. Essentially, the problem was due to a piece of code like the following:

[]
#include &amp;lt;iostream&amp;gt;
#include &amp;lt;map&amp;gt;

using namespace std;

int main()
{
map&amp;lt;char,int&amp;gt; mymap;
map&amp;lt;char,int&amp;gt;::iterator iter;

mymap['a'] = 10;
mymap['b'] = 20;
mymap['c'] = 30;
mymap['d'] = 40;
mymap['e'] = 50;
mymap['f'] = 60;

for (iter = mymap.begin(); iter != mymap.end(); iter++) {
cout &amp;lt;&amp;lt; &quot;erasing &quot; &amp;lt;&amp;lt; iter-&amp;gt;first &amp;lt;&amp;lt; endl;
mymap.erase(iter);
}
}
[/]

Compiling the above code on Linux with gcc 4.2.3, the output is as follows (which is what is intended):

[]
$ ./stuff
erasing a
erasing b
erasing c
erasing d
erasing e
erasing f
$
[/]

Compiling and running the same code on Windows causes an issue. The following output is produced (and execution halts):

[]
$ ./stuff.exe
erasing a
erasing ^
[/]

Now when seeing the simple test case above, the actual issue may become apparent. However, it was not so apparent in the source code for our application. The issue is due to the way elements are being erased in the first for loop. Referring to the documentation for STL map, we get the following paragraph:

Map has the important property that inserting a new element into a map does not invalidate iterators that point to existing elements. Erasing an element from a map also does not invalidate any iterators, except, of course, for iterators that actually point to the element that is being erased.

Thus, one possible reason for the issue is that as soon as the element is erased, the current iterator is invalidated, and on the next trip through the loop, the next iterator is calculated on the (now) invalid current iterator. So, this could wind up pointing to an invalid area.

We think (don't know for sure) that we are seeing different behavior on the two platforms due to different implementations of the STL library or perhaps because of different implementations of the underlying OS calls such as free().

Our method for getting around this issue was to move the calculation of the next iterator (iter++) into the erase() statement so that the next iterator is calculated based on a valid iterator. Thus, the test case ends up looking as follows:
[]
#include
#include &lt;map&gt;&lt;/map&gt;

using namespace std;

int main()
{
map mymap;
map::iterator iter;

mymap['a'] = 10;
mymap['b'] = 20;
mymap['c'] = 30;
mymap['d'] = 40;
mymap['e'] = 50;
mymap['f'] = 60;

for (iter = mymap.begin(); iter != mymap.end(); ) {
cout &amp;lt;&amp;lt; &quot;erasing &quot; &amp;lt;&amp;lt; iter-&amp;gt;first &amp;lt;&amp;lt; endl;
mymap.erase(iter++);
}
}
[/]
The above code runs correctly on both Linux and Windows. This was a subtle bug that was perhaps not as apparent as it should have been to me. My excuse is that I didn't write this piece of code so it took a little while longer for me to debug it.
