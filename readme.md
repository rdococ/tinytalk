# Colang 0.3.2

Colang is a minimalistic, purely object-oriented toy programming language with Smalltalk-inspired syntax.

## Semantics

* An object is a set of methods.
* You can send a message to an object, which runs the matching method.
* Objects can decorate other objects to copy their methods.
* You can name intermediary values using the `:=` operator.

## Utilities

There are several builtin objects.

* Numbers, strings and booleans implement a variety of operators.
* Booleans implement `if:`, sending `true` or `false`.
* The `console` can `read` input, `print:` or `write:` output, or throw an `error:`.
* The `Cell` factory can `make:` new mutable cells that can get their `value` or `put:` a new one.
* The `Array` object can `make` arrays, that can get values `at:` a position, or `at:Put:`.
* The `system` can `require:` Colang code or `open:` files. Files can `read` lines, `readAll`, `write:`, get their `position` and `size`, `goto:` and `move:`.

## Syntax

```
"Comment"

"Body of statements"
zombie attackedWith: player weapon By: player.
player weapon degrade: 1.

"Variable access"
abc

"Variable definition"
abc := x

"Keyword message"
player attackedWith: zombie jaw By: zombie

"Operator message"
x + y

"Unary message"
x negate

"Parentheses"
(x)

"Object definition"
[callTo: person
    person barkedAt
|fetch: ball For: person
    ball fetched.
    person takeItem: ball.]

"Object decoration"
[makeNoise
    console print: 'Cockadoodle doo!'
|...bird]

"String literal"
'abc'

"Number literal"
1.23
```