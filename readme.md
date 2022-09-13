# Colang 0.2

Colang is a purely object-oriented toy programming language with a Smalltalk-like syntax and immutable variables by default.

## Syntax

```
"Comment"

"Body of statements"
zombie attackedWith: player wieldedItem By: player.
player wieldedItem degrade: 1.

"Variable access"
abc

"Variable definition"
abc := x

"Keyword message"
x doWith: y And: z

"Binary operator message"
x + y

"Unary message"
x negate 

"Parentheses"
(x)

"Object definition"
[doWith: x
	x foo
|doWith: x And: y
	x foo: y
\decoratee]

"String literal"
'abc'

"Number literal"
1.23
```

## Semantics

All values are objects. An object consists of a set of methods with zero or more parameters. Sending a message to an object runs the method with that name, or throws an error if there is no such method. Objects with decoration expressions will forward messages to decorated objects.