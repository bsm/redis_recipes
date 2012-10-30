# Redis Recipes: Range Lookup X

A data structure, very similar to the "normal" Range Lookup, except that it 
stores ranges that exclude the end value.

### Example / Internals:

Consider the following use case: "Holiday System"

* [A]lice is on vacation from the 4th until the 11th
* [B]ob leaves an 7th and returns on the 21st
* [C]olin is also away from 4th, but returns only on the 18th
* [D]eborah's holidays are from 16th to the 23th

Our numeric ranges would therefore be:

    A  4...12
    B  7...22
    C  4...19
    D 16...24

To identify the people away for any specific date quickly, we create a
flattened index:

     4  [A C]
     7  [A B C]
    12  [B C]
    16  [B C D]
    19  [B D]
    22  [D]
    24  []

For any given day, we can match the list (set) of members that are on vacation,
by:

1. Finding the index <= the given value. For example: a search for the 18th would return 16.
2. Reading the members on the index. For example: for the 16th, [B C D] would be returned.

### Usage:

Add ranges:

    redis-cli --eval <path/to/add.lua> holidays , A 4 12
    redis-cli --eval <path/to/add.lua> holidays , B 7 22
    redis-cli --eval <path/to/add.lua> holidays , C 4 19
    redis-cli --eval <path/to/add.lua> holidays , D 16 24
    redis-cli --eval <path/to/add.lua> holidays , X 5 16

Remove a range:

    redis-cli --eval <path/to/remove.lua> holidays , X 5 16

Lookup range:

    redis-cli --eval <path/to/lookup.lua> holidays , 18   # =>  1) "B"
                                                          #     2) "C"
                                                          #     3) "D"
    redis-cli --eval <path/to/lookup.lua> holidays , 19   # =>  1) "B"
                                                          #     2) "D"
