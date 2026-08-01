# API Reference

Everything below is exported from the `cl-cowsay` package. The command-line
front end lives in the separate `cl-cowsay/cli` package (`make-cowsay-app`,
`main`, `image-entry-point`) and is documented by `cl-cowsay --help`.

## Rendering

### `say`

```lisp
(say message &key (character "cow") (mode :speech) eyes tongue (width 40))
```

Return a string rendering `message` inside a speech bubble (`mode :speech`,
the default) or thought bubble (`mode :thought`) above the built-in
`character`, a case-insensitive string naming one of [`list-characters`](#list-characters)
(default `"cow"`).

`eyes` and `tongue` override the character's `${eyes}` and `${tongue}`
template slots when non-`nil`; `nil` (the default for both) falls back to
`"oo"` and `""` respectively. `width` bounds the message's wrap column count
and must be a positive integer; it defaults to 40.

Signals [`unknown-character`](#unknown-character) when `character` names no
built-in, and [`invalid-message`](#invalid-message) when `width` is not a
positive integer.

## Characters

### `list-characters`

```lisp
(list-characters)
```

Return every registered character name, sorted alphabetically. Ships with at
least `"cow"` (the default), `"cat"`, `"robot"`, and `"ghost"` -- all original
ASCII art written for this project.

### `character-known-p`

```lisp
(character-known-p name)
```

True when `name` (case-insensitive) names a registered character.

## Conditions

### `cl-cowsay-error`

Base condition for every error `cl-cowsay` signals. A `handler-case` clause
on this type catches any of them.

### `unknown-character`

Signaled by [`say`](#say) when `character` names no built-in.
`unknown-character-name` reads the offending name back.

### `invalid-message`

Signaled by [`say`](#say) when `width` is not a positive integer.
`invalid-message-width` reads the offending value back.
