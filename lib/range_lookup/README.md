# Redis Recipes: Range Lookup

Data structure, optimised for fast lookups of (possibly overlapping) ranges
containing a given value. Works with any numericly representable ranges, e.g.
dates, times, IP addresses, etc. Inspired by: http://stackoverflow.com/questions/8622816/redis-or-mongo-for-determining-if-a-number-falls-within-ranges/8624231#8624231

### Example / Internals:

Consider the following use case: "Holiday System"

* [A]lice is on vacation from the 4th until the 11th
* [B]ob leaves an 7th and returns on the 21st
* [C]olin is also away from 4th, but returns only on the 18th
* [D]eborah's holidays are from 16th to the 23th

Our numeric ranges would therefore be:

    A  4-11
    B  7-21
    C  4-18
    D 16-23

To identify the people away for any specific date quickly, we create a
flattened index:

     4  [A C]
     7  [A B C]
    11  [B C]
    16  [B C D]
    18  [B D]
    21  [D]
    23  []

For any given day, we can match the list (set) of members that are on vacation,
by:

1. Just reading the members for exact hits. For example: on the 18th [B C D]
match.
2. Creating an intersection between the preceeding and the following set. For
example: on the 19th INTER([B C D], [B D]) -> [B D] match.

### Usage:

Add ranges:

    redis-cli --eval <path/to/add.lua> holidays , A 4 11
    redis-cli --eval <path/to/add.lua> holidays , B 7 21
    redis-cli --eval <path/to/add.lua> holidays , C 4 18
    redis-cli --eval <path/to/add.lua> holidays , D 16 23
    redis-cli --eval <path/to/add.lua> holidays , X 5 15

Remove a range:

    redis-cli --eval <path/to/remove.lua> holidays , X 5 15

Lookup range:

    redis-cli --eval <path/to/lookup.lua> holidays , 18   # =>  1) "B"
                                                          #     2) "C"
                                                          #     3) "D"
    redis-cli --eval <path/to/lookup.lua> holidays , 19   # =>  1) "B"
                                                          #     2) "D"
