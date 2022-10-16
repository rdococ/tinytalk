![# Tinytalk](logo.png)

Tinytalk is a minimalistic, purely object-oriented toy programming language.

## Semantics

* An object is a set of methods.
* You can send a message to an object, which runs the matching method.
* Objects can decorate other objects to copy their methods.
* You can use variables to name intermediary values.

## Utilities

There are several builtin objects.

* Numbers, strings and booleans implement a variety of operators. Strings can `import` the file with their name in the repository, e.g. `'brainfuck' import`.
* Booleans implement `if:`, sending `true` or `false`.
* The `console` can `read` input, `print:` or `write:` output, or throw an `error:`.
* The `Cell` factory can `make:` new mutable cells that can get their `value` or `put:` a new one.
* The `Array` object can `make` arrays, that can get values `at:` a position, or `at:Put:`.
* The `system` can `require:` Colang code or `open:` files. Files can `read` lines, `readAll`, `write:`, get their `position` and `size`, `goto:`, `move:` and `close`.

## Syntax

```
"Comment"

zombie attackedWith: player weapon By: player. "Statements"
player weapon degrade: 1.

abc := x. "Variable definition"
console print: abc. "Variable access"

player attackedWith: zombie weapon By: zombie "Keyword message"

console print: x + y. "Operator message"
player poisoned. "Unary message"

cell put: (fibonacci of: 5). "Parentheses"

dog := [callTo: person "Object definition"
           person barkedAt
       |fetch: ball For: person
           ball fetched.
           person takeItem: ball].

"Variable redefinition"
dog := [name 'Percy' "String literal"
       |...dog]. "Object decoration"
```