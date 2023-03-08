![# tinytalk](logo.png)

tinytalk is a purely object-oriented toy language.

## Semantics

Every value is an object, and an object is just a record of methods (i.e. closures) you can call. Objects can decorate other objects, copying their methods. Variables are mutable and hoisted to the top of the method, but the initial value is not.

## Utilities

There are several builtin convenience objects.

* Numbers, strings and booleans implement a variety of operators. Strings can `import` the file with their name in the repository, e.g. `'brainfuck' import`.
* Booleans implement `if:`, sending `true` or `false`.
* The `console` can `read` input, `print:` or `write:` output, or throw an `error:`.
* The `Array` object can create `new` arrays, that can get values `at:` a position, or `at:Put:`.
* The `system` can `require:` tinytalk code or `open:` files. Files can `read` lines, `readAll`, `write:`, get their `position` and `size`, `goto:`, `move:` and `close`.

## Syntax

```
Square :=                                                   "Variable definition"
  [at: origin WithSize: size                                "Object creation & method signature"
    corner := origin + (Point atX: size Y: size).           "Binary operators & parentheses"
    [contains: point
      point >= origin and: point < corner                   "Keyword messages"
    |origin  origin                                         "Method separator"
    |corner  corner
    |bottomLeft
      Point atX: origin x Y: corner y                       "Unary messages"
    |topRight
      Point atX: corner x Y: origin y]].

bob := [name 'Bob'
       |...Square at: (Point atX: 10 Y: 10) WithSize: 15].  "Object decoration"

bob <- [age 30 | ...bob].                                   "Variable assignment"
```