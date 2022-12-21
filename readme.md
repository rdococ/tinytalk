![# tinytalk](logo.png)

tinytalk is a minimalistic, purely object-oriented toy programming language.

## Semantics

* An object is a set of methods.
* You can send a message to an object, which runs the matching method.
* Objects can decorate other objects to copy their methods.
* You can use variables to store intermediary values.
* Variables are hoisted to the top of the method but their values aren't assigned until the definition is reached.

## Utilities

There are several builtin objects.

* Numbers, strings and booleans implement a variety of operators. Strings can `import` the file with their name in the repository, e.g. `'brainfuck' import`.
* Booleans implement `if:`, sending `true` or `false`.
* The `console` can `read` input, `print:` or `write:` output, or throw an `error:`.
* The `Cell` factory can `make:` new mutable cells that can get their `value` or `put:` a new one. (Alternatively, you can try the WIP `<-` assignment form.)
* The `Array` object can `make` arrays, that can get values `at:` a position, or `at:Put:`.
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

bob <- [age 30 | ...bob].                                   "Variable assignment (WIP)"
```