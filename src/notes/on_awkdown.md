# Awkdown

This website currently does not have many direct dependencies it relies
on. It consists mostly of a single Bash script with some Awk snippets
embedded into it. 

The one thing that stands out, is the use of
[Pandoc](https://pandoc.org/) to convert the Markdown files this
website's blog articles are written in, to valid HTML documents. The
reliance on tools as complicated and powerful as Pandoc for this
seemingly simple task bothers me quite a lot. I deeply admire
[Hundredrabbits](https://100r.co/site/about_us.html) approach to
creating software and their strive for independence and autarky in the
context of technology in general. I aim for this website to embody the
same principles.

For this reason, I thought it might be a good idea to try and write my
own solution to convert my writing from Markdown to HTML. I had not much
experience writing compilers before and felt it to be a good occasion to
wet my feet getting more familiar with this domain.

While there are already a [couple](https://github.com/wime12/commonmark)
of people who worked on something similar, to the best of my knowledge
there is currently only
[one](https://github.com/bert-github/gf-markdown-awk) implementation
that partly strives to conform to the
[CommonMark](https://github.com/commonmark/) specification. I won't go
into too much detail about CommonMark itself except for the following:
Markdown emerged without a formal specification. Instead, its rules were
outlined by an [accompanying
blog](https://daringfireball.net/projects/markdown/) post. Actual
implementation details needed to be looked for in a script
(`markdown.pl`) whose purpose was - you guessed it - to transform
Markdown to HTML. Due to the lack of a formal specification numerous
versions - so-called flavors - of Markdown exist. This ambiguity offers
lots of flexibility to it's creators, at the [cost of
reliability](https://twitter.com/arjenroodselaar/status/1788573953784770858). 

## Why Awk

One might reasonably ask why I chose the Awk programming language in
particular for this task given its limited scope as a domain-specific
scripting language. 

First, one has to keep in mind that Markdowns' overwhelming popularity
today, mostly stems from the ease it provides for writing and
distributing said writing to the web. For the latter task, there exist a
sheer endless number of tools and scripts, whose sole purpose is the
conversion of Markdown to HTML - one of these is the above-mentioned
Pandoc. Keeping this in mind, the choice of Awk is almost self-evident
given it can be found in some form or another almost everywhere. 

Second, seeing what other people accomplished using Awk, it would have
been wrong to not at least give Awk a try. Above all David Given's work
on the [Mercat](http://cowlark.com/mercat/README.txt) programming system
and his choice of Awk to write a full
[recursive-descent](https://en.wikipedia.org/wiki/Recursive_descent_parser)
bootstrap compiler particular, was my primary inspiration to use Awk.
Besides, I just like the language a lot and encourage everyone to at
least read its man page and take a look at some rudimentary
[examples](https://web.archive.org/web/20220328223853/https://catonmat.net/awk-one-liners-explained-part-one).
But enough has already been written on that.

## Result 

I tested 338 of the 652 test cases included in the CommonMark [test
suite](https://spec.commonmark.org/0.31.2/spec.json). As of writing 25
of these fail, which is pretty decent.

As the main task of Awkdown is to translate from one markup language to
another, I followed the same steps as
[md4c](https://github.com/mity/md4c) and implemented what most resembles
a [SAX parser](http://www.saxproject.org/event.html). As soon as we
encounter a valid Markdown node, we immediately proceed to convert it to
HTML. This approach stands in contrast to the to the [reference
implementations](https://github.com/commonmark/cmark) of CommonMark,
which first constructs a full abstract syntax tree before generating
HTML.

The actual parsing order of node types can be illustrated by the below
diagram:

```
+-----------+     +--------+     +-------+
|           |     |        |     |       |
| Container |     |  Leaf  |     | Lines |
|  Blocks   | --> | Blocks | --> |       |
|           |     |        |     |       |
+-----------+     +--------+     +-------+
```

When starting to work on the project, I used a couple of other - rather
simplistic - Markdown to HTML compilers written in Awk as a
[reference](https://git.sr.ht/~knazarov/markdown.awk). In retrospect
this was probably a mistake as it set wrong expectations regarding -
especially - the parsing of inline elements, which proved more
challenging than initially thought. 

At first, I tried to leverage

        /pattern/ { action }

pairs, that build the core of Awk, as much as possible. First, we look
for a specific pattern of characters in the current line and if we found
a match, execute an action. This worked sufficiently well for parsing
[leaf-block elements](https://spec.commonmark.org/0.31.2/#leaf-blocks)
and felt quite intuitive if you have written some Awk before.

Take the parsing of [ATX
headings](https://spec.commonmark.org/0.31.2/#atx-headings) for example,
a simple glance at the code should give a good impression what exactly
we what we are doing here (the `$0` is a special variable in Awk
referring to the current line):

```
# atx headings
/^ {0,3}#{1,6}([[:blank:]]+|$)/{
  if (text) pop_block()
  parse_atx($0)
  next
}
```

As I started to tackle inline parsing though, this approach quickly
broke down due to the recursive nature of inline elements, as we need to
keep track of previously parsed text nodes belonging to the same block.
To give a rather simple example, the following: 

```
**foo **bar baz**
```

should equal:

```
<p>**foo <strong>bar baz</strong></p>
```

and _NOT_:

```
<p><strong>foo </strong>bar baz**</p>
```

We cannot simply insert an opening tag for a specific inline node
without knowing the context of the whole line or blog it belongs to.

The routine handling the parsing of inline elements 

```
function parse_line(s, b, \
                    res, i, t, p, em) {

  # Reuse already parsed input if available
  if (b) {
    i = b - 1
    res = substr(s, 1, i)
  } else {
    i = 0
    res = ""
  }

  t = substr(s, i)    # part of s from c on

  while (++i <= length(res t)) {

    c = substr(s, i, 1) # current char
    t = substr(s, i)    # part of s from c on

    # account for escaped characters
    if (c == "\\") {
      res = res substr(t, i + 1, 1)
    # parse inline code span
    } else if (c == "`") {
      res = res parse_code_span(t)
      i = length(res)
    # parse emphasis
    } else if (c == "*" || c == "_") {
      res = parse_emphasis(res t, i)
      i = length(res)
    } else {
      res = res c
    }
  }

  return res
}
```

felt kinda hacky in the sense that we call `parse_line` recursively on
the return values of all the different parser routines that handle
parsing of individual inline nodes, even though we eventually return
this intermediate result to `parse_line`. 

I took care to only parse each character once and resume parsing from
where we left off utilizing the `b` function parameter, which indicates
from which point onward inline shall be resumed. Parsing of the (few)
inline elements, that I worked on were so cumbersome that they kept me
busy for two or three weeks. The rules to parse emphasis feel bogus and
far detached from the goal of simple readability that Markdown's
creators had originally in mind during its creation. Thus, it is quite
ensuring that one of the fathers of CommonMark, John MacFarlane, [seems
to feel](https://johnmacfarlane.net/beyond-markdown.html) the same
(emphasis mine):

> There are very good reasons for being conservative in this way. But
> this respect for the past has made the CommonMark spec a __very
> complicated beast__. There are 17 principles governing emphasis, for
> example, and these rules still leave cases __undecided__.

## What Now

Spending more than two weeks just on getting emphasis parsing right
humbled me quite a lot. And while I still think the project itself is a
worthwhile pursuit, I am old enough to know when to take a step back.

Reevaluating Awk as my programming language of choice, I still do not
think it is a bad choice per se for the reasons explained above. But as
I have to grudgingly admit, I no doubt felt the same pain points, that
plagued David Given when working on his Awk compiler and fully agree
with him that Awk's lack of native arrays and the error-prone rules to
declare locally scoped variables are [its biggest
problems](http://lua-users.org/lists/lua-l/2008-02/msg00477.html). I
intend to continue working on Awkdown at some time in the future after
gaining more fundamental knowledge about compilers. Anything else would
be unserious. The full code including all test cases can be found
[online](https://github.com/mxngls/awkdown).

As a closing note, working with and researching Markdown made me
question the way we use it today.
[Citing](https://daringfireball.net/projects/markdown/) John Gruber the
creator of Markdown:

> The overriding design goal for Markdown’s formatting syntax is to make
> it as readable as possible.

Considering this, one cannot but ask himself why we do not use Markdown
as it was intended. Pointing to the introduction of Mercat, its README
is written in plain text, formatted in a similar spirit as if it
would have been written in Markdown. Its readability is outstanding and
requires no external dependencies.

_Thanks to Phil Eaton and Haile Lagi for helpful comments and
suggestions._
