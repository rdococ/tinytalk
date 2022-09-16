# Colang 0.2.1

Colang is a minimalistic, purely object-oriented toy programming language with Smalltalk-inspired syntax.

## Semantics

* An object is a set of methods.
* You can send a message to an object, which runs the matching method.
* Objects can take on the methods of other objects.
* You can define variables to hold intermediary values.
* A method body is a list of expressions that returns the last expression's value.

## Utilities

There are several builtin objects.

* Number, string, boolean and nil implement a variety of operators.
* Booleans and nil implement `match:`, sending to it `true`, `false` or `nil`.
* The `console` can `read` input, `print:` or `write:` output, or throw an `error:`.
* The `Cell` factory can `make:` new mutable cells that can `get` or `set:` their value.
* The `library` can `fetch:` Colang objects from the filesystem.

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