# API Reference

Everything below is exported from the `cl-cowsay` package. `write-say` is the
library's streaming rendering boundary. The command-line front end lives in
the separate `cl-cowsay/cli` package (`*cowsay-app*`, `main`,
`image-entry-point`) and is documented by `cl-cowsay --help`.

## CLI lifecycle

The command-line package is a process boundary, separate from the rendering
API. `main` parses the command-line arguments and terminates the current
process with the resulting exit code; it does not return that code to its
caller.

`image-entry-point` is the entry point used by the delivered executable. It
first sets `*default-pathname-defaults*` from the process's current working
directory, then calls `main`. This restores the startup working directory for a
dumped image. Applications embedding the library should call `write-say`
instead of these process-facing entry points.

## Rendering

### `write-say`

```lisp
(write-say message stream &key (character "cow") (mode :speech) eyes tongue
          (width 40) no-wrap
          (timeout-seconds +default-timeout-seconds+))
```

Write a rendering of `message` to the supplied output `stream`. Use this entry
point when the result should be streamed instead of accumulated in memory.
`message` must be a string, and `mode` must be either `:speech` or `:thought`.
`character` is a case-insensitive string naming one of
[`list-characters`](#list-characters); it defaults to `"cow"`.

`eyes` and `tongue` override the character's `${eyes}` and `${tongue}`
template slots when non-`nil`; `nil` (the default for both) falls back to
`"oo"` and `""` respectively. [`eyes-preset-string`](#eyes-preset-string) is
a convenient source for `eyes`.

`width` bounds the message's wrap column count and must be a positive integer;
it defaults to 40. `no-wrap`, when true, disables width-based wrapping
entirely -- `message` is split only on its own embedded newlines, and `width`
is ignored for wrapping purposes (though still validated).

`timeout-seconds` is a positive real wall-clock limit for the operation and
defaults to `+default-timeout-seconds+`. A non-positive or non-real value
signals [`invalid-timeout`](#invalid-timeout); expiry signals
[`operation-timeout`](#operation-timeout).

Signals [`unknown-character`](#unknown-character) when `character` names no
built-in, [`invalid-message`](#invalid-message) when `width` is not a positive
integer, and a standard `type-error` for a non-string `message` or an
unsupported `mode`.

### `with-operation-timeout`

```lisp
(with-operation-timeout (operation timeout-seconds) &body body)
```

Macro for placing another application-level operation under the same positive
wall-clock timeout policy. `operation` is included in the
`operation-timeout` report when the body expires.

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
"borg")` returns `"=="`. Pass the result as `write-say`'s `:eyes` argument. Signals
[`unknown-eyes-preset`](#unknown-eyes-preset) when `name` is not registered.

## Conditions

### `cl-cowsay-error`

Base condition for every error `cl-cowsay` signals. A `handler-case` clause
on this type catches any of them.

### `unknown-character`

Signaled by [`write-say`](#write-say) when `character` names no built-in.
`unknown-character-name` reads the offending name back.

### `unknown-eyes-preset`

Signaled by [`eyes-preset-string`](#eyes-preset-string) when `name` names no
built-in preset. `unknown-eyes-preset-name` reads the offending name back.

### `invalid-message`

Signaled by [`write-say`](#write-say) when `width` is not a positive integer.
`invalid-message-width` reads the offending value back.

### `invalid-timeout`

Signaled when `write-say` or `with-operation-timeout` receives a timeout that
is not a positive real number.

### `operation-timeout`

Signaled when a bounded operation exceeds its wall-clock timeout. The
`operation-timeout-operation` reader identifies the operation label.

### `stdin-too-large`

Signaled by the `cl-cowsay` command line when standard input exceeds its
read limit without reaching EOF. `stdin-too-large-limit` reads the
configured limit back.
