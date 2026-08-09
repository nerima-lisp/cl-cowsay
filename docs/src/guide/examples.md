# Examples

A cookbook of `cl-cowsay` usage, from the command line and as a library.
See the [CLI reference](../reference/cli.md) for every flag and the
[API reference](../reference/api.md) for the full `cl-cowsay:write-say` signature.

## Speech vs. thought bubbles

```sh
cl-cowsay "hi"
```

```text
 ____
| hi |
 ----
        \   ^__^
         \  (oo)
            (__)
             u  u
```

```sh
cl-cowsay --think -c robot "Beep boop."
```

```text
 ____________
: Beep boop. :
 ------------
          o    (_)
         o  .-----.
          o |oo |
            '--|-|--'
               |_|
```

Speech bubbles use `|` sides and a `\` connector; thought bubbles use `:`
sides and an `o` connector, so the two are visually distinct even without
reading the message itself.

## Eyes presets

`--eyes-preset`/`-E` is a shortcut for the classic `cowsay` eyes; an explicit
`--eyes` always overrides it when both are given (see
[`eyes-preset-string`](../reference/api.md#eyes-preset-string)).

```sh
cl-cowsay -E dead "Oh no"
```

```text
 _______
| Oh no |
 -------
        \   ^__^
         \  (XX)
            (__)
             u  u
```

## Word-wrap vs. `--no-wrap`

By default, `cl-cowsay` wraps the message to `--width` columns (40 by
default):

```sh
cl-cowsay -w 10 "hello world"
```

```text
 _______
| hello |
| world |
 -------
        \   ^__^
         \  (oo)
            (__)
             u  u
```

`--no-wrap`/`-n` disables that -- the message stays on one line regardless
of `--width`, and only its own embedded newlines still break it:

```sh
cl-cowsay -w 10 -n "hello world"
```

```text
 _____________
| hello world |
 -------------
        \   ^__^
         \  (oo)
            (__)
             u  u
```

## Picking a character

```sh
cl-cowsay -l                # list every built-in character name
cl-cowsay -c dragon "Roar!" # pick one explicitly
cl-cowsay -r "Surprise me!" # let cl-cowsay pick one at random
```

See the [character gallery](characters.md) for what all 29 look like.

## Shell completion

`--completion` prints a completion script for the named shell, generated
from the same option spec `--help` uses:

```sh
eval "$(cl-cowsay --completion bash)"   # current bash session
source <(cl-cowsay --completion zsh)    # current zsh session
```

See the [CLI reference](../reference/cli.md#shell-completion) for every
supported shell.

## Shell one-liners

```sh
# Pipe a message in from standard input.
echo "piped in" | cl-cowsay

# A cowsay-flavored git post-commit hook message.
git log -1 --pretty=%s | cl-cowsay -c cat

# Whatever fortune(6) prints, from a random built-in character.
fortune | cl-cowsay -r --think
```

## As a library

```lisp
(asdf:load-system "cl-cowsay")

;; The basics: character, mode, eyes/tongue overrides, width.
(cl-cowsay:write-say "Hello, nerima-lisp!" *standard-output*)
(cl-cowsay:write-say "Hmm..." *standard-output* :character "dragon" :mode :thought)
(cl-cowsay:write-say "Encrypted" *standard-output*
                     :eyes (cl-cowsay:eyes-preset-string "borg"))
(cl-cowsay:write-say "kept on one line no matter how long" *standard-output* :no-wrap t)

;; Handle every error this library signals with one clause: they all derive
;; from cl-cowsay-error, and each one reports itself under ~A.
(handler-case (cl-cowsay:write-say "hi" *standard-output* :character "not-a-real-character")
  (cl-cowsay:cl-cowsay-error (c)
    (format t "cl-cowsay failed: ~A~%" c)))

;; A reader such as unknown-character-name belongs to one subtype, not to the
;; base condition, so asking for it means a clause on that subtype. handler-case
;; takes the first matching clause, so the specific one goes above the catch-all.
(handler-case (cl-cowsay:write-say "hi" *standard-output* :character "not-a-real-character")
  (cl-cowsay:unknown-character (c)
    (format t "no such character: ~A~%" (cl-cowsay:unknown-character-name c)))
  (cl-cowsay:cl-cowsay-error (c)
    (format t "cl-cowsay failed: ~A~%" c)))

;; Enumerate what's available.
(cl-cowsay:list-characters)   ; => ("alien" "bat" "bear" ... "wolf")
(cl-cowsay:list-eye-presets)  ; => ("borg" "dead" "greedy" ...)
```
