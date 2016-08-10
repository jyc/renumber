# Renumber

Renumber is a script for renumbering files in a directory so that they are
numbered consecutively.

Recently I have been working with patches in a patch series, and renumbering
them every time I split a patch into parts or remove a patch got really
annoying.

To make this a little less frustrating (and also because I was very bored) I
wrote this small script to do the same thing automatically.

For example, suppose you start out with a patch series:

    p1-CSSVariableDeclarations
    p2-CSSComputedValue 
    p3-nsStyleComputedVars

... then realize that CSSVariableDeclarations is actually too big of a patch
and should be split up, I'm annoyed to have to renumber offset all of the
subsequent patches by one myself. It gets really bad when there are more than
half a dozen patches. (I'm sure there's some Bash wizardry for
this).

Instead, what I can do is split the patch into two files:

    p1.1-Declaration
    p1.2-CSSVariableDeclarations
    p2-CSSComputedValue 
    p3-nsStyleComputedVars

... and then run `renumber -s '-' -p 'p' -f series` to get:

    p1-Declaration
    p2-CSSVariableDeclarations
    p3-CSSComputedValue
    p4-nsStyleComputedVars

`-s '-'` says that the separator between parts is the dash character.
Files are sorted lexicographically by parts.
Parts that can be parsed as floating point numbers are compared numerically,
while other parts are compared as strings.

`-p 'p'` says that the prefix of files to consider is `p`.
You can set it to `-p ''` to simply rename all files.

`-f series` will look for occurrences of the original file names in the file
`series` and replace them with the renamed file names.
For me, `series` is the MQ patch series file.

renumber will also automatically substitute substrings matching the regex
`(^[^-+].*Part) [0-9]+` with the substitution `$1 %d`, where %d is the new
patch number.

This means that in the above patches, if p2-CSSComputedValue started with:

    Bug 1273706 - Part 2: Add a new type for computed CSS values.

Then while renaming, this would be replaced with:

    Bug 1273706 - Part 3: Add a new type for computed CSS values.

That is, the part number has been updated to match the file.

You can specify your own regexes and substitutions with the `-ir` and `-is`
flags. Renumber uses the [PCRE](http://mmottl.github.io/pcre-ocaml/) bindings
for OCaml. `%d` in the substitution specification will be replaced with the
new patch number before compilation.

# Building

Batteries and PCRE are the only dependencies, which you can install using OPAM:

    opam install batteries pcre

Build using [Car](https://github.com/jonathanyc/car):

    car opt
    ./main.native -help

# Copyright

This is copyright Mozilla Corporation because I started work on this while
doing other work at my summer internship.
