# StringProc
Filter/group/sort strings from a text file. Generic command-line tool for parsing/analyzing logs or similar files.

Usage: StringProc [ConfigFileName] [InputFileName]

If no InputFileName passed, then it is specified in config file.
If no ConfigFileName passed, then StringProc.cfg is used.

Config file syntax.

One command per line. Lines starting with ';' are comments - ignored.

## Config example with explanation:

```
; Specify source file to process
input::filename

; Specify output file name. If not specified, then input file name is used with extension replaced with '.out'
output::filename

; Specify filter: each string should match the regular expression to be processed.
; It's possible to specify up to 5 filters: if string doesn't match any filter - it is ignored.
filter::regexp

; Specify regular expression for the exclude filter. If string match, then extracted value is tested.
exclude::regexp

; String for the exclude test: if this string contains the extracted value, the source string is ignored.
excludeIn::51614342;30187786

; Group strings by value extracted with this regular expression
groupBy::regexp

; If this token is specified, then only groups summary is printed to the output
groupsOnly

; Sort strings withing each group by the value extracted with this regular expression.
; If extracted values are integers, they're sorted as integers (i.e. "3" is less than "31"), otherwise as strings
sortBy::regexp

; Group function: count strings that match this regular expression
count::regexp

; Group function: calculate average of values extracted with this regular expression (they must be integers)
avg::regexp

; Group functions: get min/max of values extracted with this regular expression (they must be integers)
min::regexp
max::regexp
```

## Multiple configuration sets in one file.

It's possible to define multiple configs in one file using this syntax:

```
; common config lines
...

; This selects block2
>>> block2

/// block1

; These lines are ignored, because block2 is selected
...

/// block2

; These lines are used
...

/// block3

; These lines are ignored too
```