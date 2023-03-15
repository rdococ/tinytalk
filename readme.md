![# tinytalk](logo.png)

```
Animal := [new
            []].
Cat := [new
         [makeSound
           console print: 'Meow!'.
         | ...Animal new]].
Dog := [new
         [makeSound
           console print: 'Woof!'.
         | ...Animal new]].

peppy := Cat new.
peppy makeSound. "This will print 'Meow!'"
```

A purely object-oriented toy language, demonstrating how OOP does not need inheritance, traditional classes or prototypes.

## Semantics

Every value is an object, and an object is a record of callable methods (i.e. closures). Objects can decorate other objects, copying their methods. Variables are mutable and hoisted to the top of the method, but the initial value is not.

## Syntax

Operator precedence is not finalized, but is currently as follows:
* Unary messages have the highest precedence. `3 factorial + 4` means `(3 factorial) + 4`.
* Binary operators are next, and left-associative. `3 + 4 * 5 min: 2` means `((3 + 4) * 5) min: 2`.
* Keyword messages are last and also left-associative.

Expressions can be sequenced with `.`.

Object literals are defined with `[]` enclosing a set of methods and decorations, separated by `|`. A method consists of a method signature and a sequence of expressions. `...<expr>` is a decoration, and copies methods from a given object.

## Utilities

There are several builtin convenience objects.

* Numbers, strings and booleans implement a variety of operators. Strings can `import` the file with their name in the repository, e.g. `'brainfuck' import`.
* Booleans implement `if:`, sending `true` or `false`.
* The `console` can `read` input, `print:` or `write:` output, or throw an `error:`.
* The `Array` object can create `new` arrays, that can get values `at:` a position, or `at:Put:`.
* The `system` can `require:` tinytalk code or `open:` files. Files can `read` lines, `readAll`, `write:`, get their `position` and `size`, `goto:`, `move:` and `close`.