# CLI Reference

`cl-cowsay` is a single root command -- no subcommands -- built with
[`cl-cli`](https://github.com/nerima-lisp/cl-cli)'s `define-app`. Every flag
below is also visible from the terminal itself via `cl-cowsay --help`, which
is the authoritative source if this page and the installed binary ever
disagree.

```text
cl-cowsay [OPTIONS] [MESSAGE...]
```

`MESSAGE` is one or more positional words, joined by a single space. When no
positional words are given, `cl-cowsay` reads the message from standard input
instead, up to 65,536 characters (`64 * 1024`; the limit is measured in
characters). The input read and rendering operation share a positive
wall-clock timeout, defaulting to 10 seconds. All consecutive trailing newline characters are removed (see
[`stdin-too-large`](api.md#stdin-too-large)). `--completion` takes precedence
over `--list`, and both modes exit without reading standard input. Otherwise,
the normal rendering path is used; when `--random` is present, it selects the
character instead of `--character`.

## Options

| Flag | Short | Takes a value | Default | Description |
| --- | --- | --- | --- | --- |
| `--character` | `-c` | one of [`list-characters`](api.md#list-characters) | `cow` | Built-in character to draw. |
| `--think` | `-T` | flag | off | Use a thought bubble instead of a speech bubble. |
| `--eyes` | `-e` | free-form string | `oo` | Override the character's eyes. |
| `--eyes-preset` | `-E` | one of [`list-eye-presets`](api.md#list-eye-presets) | none | Preset eyes; `--eyes` overrides this when both are given. |
| `--tongue` | `-t` | free-form string | empty | Override the character's tongue. |
| `--width` | `-w` | positive integer | `40` | Column width to wrap `MESSAGE` to. |
| `--timeout` | `-o` | positive number | `10` | Wall-clock seconds allowed for input and rendering. |
| `--no-wrap` | `-n` | flag | off | Do not word-wrap `MESSAGE`; only its own embedded newlines break lines. |
| `--list` | `-l` | flag | off | List every built-in character name and exit, without reading a message at all. |
| `--random` | `-r` | flag | off | Pick a random built-in character, ignoring `--character`. |
| `--completion` | -- | one of `bash`, `zsh`, `fish`, `powershell`, `nushell`, `elvish` | none | Print a shell completion script for the named shell and exit. |
| `--help` | `-h` | flag | -- | Print usage and exit 0. |
| `--version` | -- | flag | -- | Print the running version and exit 0. |

## Shell completion

`--completion` renders a completion script straight from `*cowsay-app*` via
`cl-cli:render-completion`, so it always covers every flag above -- there is
no second, hand-written list of options to keep in sync.

```sh
eval "$(cl-cowsay --completion bash)"                 # current bash session
source <(cl-cowsay --completion zsh)                  # current zsh session
source <(cl-cowsay --completion fish)                 # current fish session
```

## Examples

```sh
cl-cowsay "Hello!"                        # speech bubble, default cow
cl-cowsay --think "Hmm."                  # thought bubble
cl-cowsay -c dragon "Beep boop."          # a different built-in character
cl-cowsay --eyes "^^" --tongue "U" "Hi"   # override eyes and tongue
cl-cowsay -E dead "Oh no"                 # a preset eyes shortcut
cl-cowsay -r "Surprise me"                # a random character
cl-cowsay -l                              # list every character name
cl-cowsay -n "one line, please, no matter how long the message actually is"
echo "piped in" | cl-cowsay               # message from standard input
```

## Exit codes

`cl-cowsay` follows the conventional Unix split: `0` on success, and a
non-zero [`sysexits.h`](https://man.openbsd.org/sysexits)-style code from
`cl-cli`'s `run-app` when something goes wrong -- for example `70`
(`EX_SOFTWARE`) when [`stdin-too-large`](api.md#stdin-too-large) is signaled,
or a non-zero parse-error code when an option or its value is invalid (an
unknown `--character`, a non-positive `--width`, and so on).
Successful rendering, character-listing, and completion output goes to
standard output; diagnostics and parse errors go to standard error.
