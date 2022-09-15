# Colang 0.2.1

Colang is a minimalistic, purely object-oriented toy programming language with Smalltalk-inspired syntax.

## Semantics

* An object is a set of methods.
* You can send a message to an object, which runs the matching method.
* Objects can take on the methods of other objects.
* You can define variables to hold intermediary values.
* A method body is a list of expressions that returns the last expression's value.

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