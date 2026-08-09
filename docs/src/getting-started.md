# Getting Started

`cl-cowsay` targets **SBCL**. The library system declares one direct runtime
dependency on [`cl-tty-kit`](https://github.com/nerima-lisp/cl-tty-kit) for
display-width-aware word wrapping. The separate CLI system adds
[`cl-cli`](https://github.com/nerima-lisp/cl-cli) for argument parsing and
[`cl-host-kit`](https://github.com/nerima-lisp/cl-host-kit) for process exit
and runtime working-directory handling. The test system additionally uses
[`cl-weave`](https://github.com/nerima-lisp/cl-weave), which is test-only and
not part of the runtime dependency closure.

## With Nix

```sh
# Run the CLI directly.
nix run github:nerima-lisp/cl-cowsay -- "Hello, nerima-lisp!"

# Or from a checkout:
nix build .#default     # build the delivered executable package
nix run .               # run the delivered binary
nix flake check         # tests + coverage + formatting + docs, the CI gate
nix develop              # SBCL with CL_SOURCE_REGISTRY already set
```

The `github:` form follows the repository's default branch, so it is
convenient but not reproducible across branch changes. For reproducible remote
execution, pin the flake reference to a reviewed release tag or commit. In a
checkout, `nix run .` and `nix build .#default` use the checkout's
`flake.lock`; keep that file when reproducing a build.

## As a library, without Nix

The test system also needs [`cl-weave`](https://github.com/nerima-lisp/cl-weave),
but it is not needed to load or run the runtime system.

Put `cl-cowsay`, `cl-tty-kit`, `cl-cli`, and `cl-host-kit` where ASDF can find
them (for example under `~/common-lisp/`), then load the library system:

```lisp
(asdf:load-system "cl-cowsay")

(cl-cowsay:write-say "Hello, nerima-lisp!" *standard-output*)
```

```text
 _____________________
| Hello, nerima-lisp! |
 ---------------------
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
cl-cowsay --timeout 5 "bounded work"     # stop after five seconds
```

`cl-cowsay` ships 29 built-in characters -- run `cl-cowsay -l` to list them,
or see the [character gallery](guide/characters.md) for what each looks like. See
the [CLI reference](reference/cli.md) for every flag, and the
[API reference](reference/api.md) for `cl-cowsay:write-say`,
`cl-cowsay:list-characters`, `cl-cowsay:eyes-preset-string`, and the
conditions it signals.
