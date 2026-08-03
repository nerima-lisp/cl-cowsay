# Getting Started

`cl-cowsay` targets **SBCL** and depends on two sibling nerima-lisp
libraries: [`cl-tty-kit`](https://github.com/nerima-lisp/cl-tty-kit) for
display-width-aware word wrapping, and
[`cl-cli`](https://github.com/nerima-lisp/cl-cli) for argument parsing. The
test system additionally uses
[`cl-weave`](https://github.com/nerima-lisp/cl-weave).

## With Nix

```sh
# Run the CLI directly.
nix run github:nerima-lisp/cl-cowsay -- "Hello, nerima-lisp!"

# Or from a checkout:
nix build .#cl-cowsay   # build the library
nix run .               # run the delivered binary
nix flake check         # tests + formatting + docs, the same gate CI uses
nix develop              # SBCL with CL_SOURCE_REGISTRY already set
```

## As a library, without Nix

Put `cl-cowsay`, `cl-tty-kit`, and `cl-cli` where ASDF can find them (for
example under `~/common-lisp/`), then:

```lisp
(asdf:load-system "cl-cowsay")

(format t "~A~%" (cl-cowsay:say "Hello, nerima-lisp!"))
```

```text
  ____________________
| Hello, nerima-lisp! |
  --------------------
        \   ^__^
         \  (oo)
            (__)
             u  u
```

## The command line

```sh
cl-cowsay "Hello!"                       # speech bubble, default cow
cl-cowsay --think "Hmm."                 # thought bubble
cl-cowsay -c robot "Beep boop."          # a different built-in character
cl-cowsay --eyes "^^" --tongue "U" "Hi"  # override eyes and tongue
cl-cowsay -E dead "Rest in peace"        # a preset eyes shortcut
cl-cowsay -r "Surprise me"               # a random character
cl-cowsay -l                             # list every character name
cl-cowsay -n "kept on one line"          # disable word-wrap
echo "piped in" | cl-cowsay              # message from standard input
cl-cowsay --completion bash              # shell completion script
cl-cowsay --help                         # every flag, free from cl-cli
```

`cl-cowsay` ships 29 built-in characters -- run `cl-cowsay -l` to list them,
or see the [character gallery](guide/characters.md) for what each looks like. See
the [CLI reference](reference/cli.md) for every flag, and the
[API reference](reference/api.md) for `cl-cowsay:say`,
`cl-cowsay:list-characters`, `cl-cowsay:eyes-preset-string`, and the
conditions it signals.
