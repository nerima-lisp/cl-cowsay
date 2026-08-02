# API Reference

Everything below is exported from the `cl-cowsay` package. The command-line
front end lives in the separate `cl-cowsay/cli` package (`*cowsay-app*`,
`main`, `image-entry-point`) and is documented by `cl-cowsay --help`.

## Rendering

### `say`

```lisp
(say message &key (character "cow") (mode :speech) eyes tongue (width 40) no-wrap)
```

Return a string rendering `message` inside a speech bubble (`mode :speech`,
the default) or thought bubble (`mode :thought`) above the built-in
`character`, a case-insensitive string naming one of [`list-characters`](#list-characters)
(default `"cow"`).

`eyes` and `tongue` override the character's `${eyes}` and `${tongue}`
template slots when non-`nil`; `nil` (the default for both) falls back to
`"oo"` and `""` respectively. [`eyes-preset-string`](#eyes-preset-string) is
a convenient source for `eyes`.

`width` bounds the message's wrap column count and must be a positive
integer; it defaults to 40. `no-wrap`, when true, disables width-based
wrapping entirely -- `message` is split only on its own embedded newlines,
and `width` is ignored for wrapping purposes (though still validated).

Signals [`unknown-character`](#unknown-character) when `character` names no
built-in, and [`invalid-message`](#invalid-message) when `width` is not a
positive integer.

## Characters

### `list-characters`

```lisp
(list-characters)
```

Return every registered character name, sorted alphabetically. Ships with 29
built-ins -- `"cow"` (the default), `"cat"`, `"robot"`, `"ghost"`, `"dragon"`,
`"penguin"`, `"fox"`, `"owl"`, `"bear"`, `"rabbit"`, `"mouse"`, `"snake"`,
`"alien"`, `"koala"`, `"tiger"`, `"lion"`, `"panda"`, `"dog"`, `"wolf"`,
`"turtle"`, `"frog"`, `"hedgehog"`, `"squirrel"`, `"bat"`, `"unicorn"`,
`"octopus"`, `"crab"`, `"bee"`, and `"skull"` -- all original ASCII art
written for this project. See the [character gallery](../guide/characters.md) for
what each one looks like.

### `character-known-p`

```lisp
(character-known-p name)
```

True when `name` (case-insensitive) names a registered character.

## Eyes presets

### `list-eye-presets`

```lisp
(list-eye-presets)
```

Return every built-in eyes-preset name: `"borg"`, `"dead"`, `"greedy"`,
`"paranoid"`, `"stoned"`, `"tired"`, `"wired"`, and `"youthful"` -- the same
shortcuts classic `cowsay` offers as `-b`/`-d`/`-g`/`-p`/`-s`/`-t`/`-w`/`-y`.

### `eyes-preset-string`

```lisp
(eyes-preset-string name)
```

Return the `${eyes}` string for `name` (case-insensitive), one of
[`list-eye-presets`](#list-eye-presets) -- for example `(eyes-preset-string
"borg")` returns `"=="`. Pass the result as `say`'s `:eyes` argument. Signals
[`unknown-eyes-preset`](#unknown-eyes-preset) when `name` is not registered.

## Conditions

### `cl-cowsay-error`

Base condition for every error `cl-cowsay` signals. A `handler-case` clause
on this type catches any of them.

### `unknown-character`

Signaled by [`say`](#say) when `character` names no built-in.
`unknown-character-name` reads the offending name back.

### `unknown-eyes-preset`

Signaled by [`eyes-preset-string`](#eyes-preset-string) when `name` names no
built-in preset. `unknown-eyes-preset-name` reads the offending name back.

### `invalid-message`

Signaled by [`say`](#say) when `width` is not a positive integer.
`invalid-message-width` reads the offending value back.

### `stdin-too-large`

Signaled by the `cl-cowsay` command line when standard input exceeds its
read limit without reaching EOF. `stdin-too-large-limit` reads the
configured limit back.
