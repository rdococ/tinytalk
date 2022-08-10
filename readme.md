# Colang

Colang is a purely object-oriented toy programming language. It has a LISP-like syntax, immutable variables by default, and a closure-based approach to objects.

## Syntax

```
; Comment
abc ; Variable access
(define <variable> <value>) ; Variable definition
{((<message> <parameters...>) <body...>)...} ; Object construction
(<expression> <message> <arguments...>) ; Message send
[(<parameters...>) <body...>] ; Procedure construction
1.23 ; Number literal
"abc" ; String literal
```

Procedures are syntax sugar for objects with only one method, named `:`.

## Semantics

An object consists of a set of methods with zero or more parameters. Sending a message to an object runs the method with that name, or throws an error if there is no such method.