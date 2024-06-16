# Awkdown

Tinkering on the build system of this website, I was bothered how I
relied on tools as complicated as Pandoc for the seemingly simple task
of converting a couple of Markdown files to HTML. I deeply admire
[Hundredrabbits](https://100r.co/site/about_us.html) approach to
creating software and their strive for independence and autarky in the
context of technology in general. I aim for this website to embody the
same principles.

Thus, I thought it might be a good idea to try and write my own software to
convert my writing from Markdown to HTML. I had not yet much experience
writing compilers and felt it to be a good occasion to wet my feet
getting more familiar in this domain.

While there are already a [couple](https://github.com/wime12/commonmark)
of people who worked on something similar, to the best of my knowledge
there is currently only one implementation that strives to conform fully
to the CommonMark specification.

## Why Awk

One might reasonably ask why I chose the Awk programming language in
particular for this task given its limited scope as a domain specific
scripting language. 

First, one has to keep in mind that Markdowns overwhelming popularity
today, mostly stems from the ease it provides for writing and
distributing said writing to the web. For the latter task, there exist a
sheer endless number of tools and scripts whose sole purpose is the
conversion of Markdown to HTML. Keeping this in mind, the choice of Awk
is almost self-evident given it can be found in some form or another
almost everywhere. 

Second, seeing what other people accomplished using Awk it would have
been wrong to not at least give Awk a chance. Above all David Given's
work on the [Mercat](http://cowlark.com/mercat/README.txt) programming
system and his choice of Awk to write a full [recursive-descent
bootstrap compiler](https://cowlark.com/mercat/com.awk.txt) in
particular, were my primary inspiration to use Awk. 

Besides, I just really like the language and encourage everyone to at
least read its man page and take a look at some rudimentary
[examples](https://web.archive.org/web/20220328223853/https://catonmat.net/awk-one-liners-explained-part-one).
But enough has already been written on that.

## Result 

I tested 338 from the 652 test cases included in the CommonMark
[test suite](https://spec.commonmark.org/0.31.2/spec.json). As of
writing 25 of these fail, which is not too bad.

When starting to work on the project, I used a couple of other rather
simple Markdown to HTML compilers written in Awk as a
[reference](https://git.sr.ht/~knazarov/markdown.awk). In retrospect
this was probably a mistake as it set wrong expectations regarding -
especially - the parsing of inline elements, which proved more
challenging than initially thought. 

As the sole purpose of Awkdown is to translate from one markup language
to another, I followed into the same steps as
[md4c](https://github.com/mity/md4c) and implemented what most resembles
a [SAX parser](http://www.saxproject.org/event.html). Instead of first
constructing a full abstract syntax tree as the [reference
implementations](https://github.com/commonmark/cmark) of CommonMark,

I tried to leverage

        /pattern/ { action }

pairs that builds the core of Awk. This worked sufficiently well for
parsing [leaf-block
elements](https://spec.commonmark.org/0.31.2/#leaf-blocks) and felt
quite intuitive for the very same reason. As I started to tackle inline
parsing though this approach quickly broke down due to their recursive
nature. The routine handling the parsing of inline elements 

        parse_line(s, b)

felt kinda hacky in the sense that we call `parse_line` recursively on
the return values of all the different parser routines that handle
parsing of individual inline marks, even though we eventually return
this intermediary result to `parse_line`. I took care though to only
parse each character once and resume parsing from where we left off
utilizing the `b` function parameter. It indicates from which point onward
inline elements need to be parsed for the rest current line.

Parsing of the (few) inline elements, specifically emphasis, that I
worked on were so cumbersome that they kept me busy for two or three
weeks. The rules to parse emphasis feel bogus and far detached from the
goal of simple readability that Markdown's creators had in mind during
it's creation. Thus, it is quite relieving that one of the fathers of
CommonMark, John MacFarlane,
[feels](https://johnmacfarlane.net/beyond-markdown.html) the same.

Reevaluating Awk as my programming language of choice for this project,
I still do not think it is a bad choice per se for the reasons explained
above. But as I have to grudgingly admit I no doubt felt the same pain
points plaguing David Given when working on his Awk compiler. I fully
agree with him that Awk's lack of native arrays and the error-prone
rules to declare locally scoped variables are [its biggest
problems](http://lua-users.org/lists/lua-l/2008-02/msg00477.html).

## What Now

Spending more than two weeks just on getting emphasis parsing right
humbled me quite a lot. And while I still think the project itself is a
worthwhile pursuit, I am old enough to know when to take a step back.

I intend to continue working on Awkdown at some time in the future after
gaining a more fundamental knowledge about compilers. Anything else
would be deeply unserious. The full code including all test cases can be
found [online](https://github.com/mxngls/awkdown).

As a closing note, working with and researching Markdown made me
question the way we use it today.
[Citing](https://daringfireball.net/projects/markdown/) John Gruber the
creator of Markdown:

> The overriding design goal for Markdown’s formatting syntax is to make
> it as readable as possible.

Considering this, one cannot but ask himself why we do not use Markdown
as it was intended. Pointing to the introduction of Mercat, it's README
is written in plain text, formatted in a similar spirit as if it
would have been written in Markdown. It's readability is outstanding and
requires no external dependencies.
