# Colang

Colang is a purely object-oriented toy programming language. It has a LISP-like syntax, immutable variables by default, and a codata-inspired approach to objects.

## Syntax

```
; Comment
abc ; Variable access
(define <variable> <value>) ; Variable definition
{...} ; Object construction
	((<message> <parameters...>) <body...>) ; Method definition
	(-> <expression>) ; Object decoration
(<expression> <message> <arguments...>) ; Message send
[(<parameters...>) <body...>] ; Procedure construction
1.23 ; Number literal
"abc" ; String literal
```

Procedures are syntax sugar for objects with only a `:` method.

## Semantics

All values are objects. An object consists of a set of methods with zero or more parameters. Sending a message to an object runs the method with that name, or throws an error if there is no such method.