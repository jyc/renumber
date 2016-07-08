# renumber

renumber is a script for renumbering files in a directory so that they are
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
