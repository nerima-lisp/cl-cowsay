# cl-cowsay

[![CI](https://github.com/nerima-lisp/cl-cowsay/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/cl-cowsay/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-0a7a5a)](https://nerima-lisp.github.io/cl-cowsay/)

A one-shot ASCII-art talking-animal message tool for SBCL: word-wrap a
message into a speech or thought bubble above one of **29 original,
hand-written characters**, print it, exit. Not a clone of the classic
`cowsay`'s `.cow` Perl file format -- characters are plain Lisp data with a
minimal `${eyes}`/`${tongue}`/`${thoughts}` substitution scheme, and none of
the art is copied from upstream.

- 29 built-in characters (`cl-cowsay -l` to list them; see the
  [character gallery](https://nerima-lisp.github.io/cl-cowsay/characters/))
- Speech and thought bubbles, custom eyes/tongue overrides, and 8 classic
  `cowsay`-style eyes presets (`-E borg`, `-E dead`, ...)
- Adjustable wrap width, an opt-out `--no-wrap` mode, and a `--random`
  character picker
- Bash/Zsh/Fish/PowerShell/Nushell/Elvish completion scripts
  (`cl-cowsay --completion bash`, ...)
- A small library (`cl-cowsay:say`) behind the command line, usable on its
  own from any SBCL program

Full documentation is published at <https://nerima-lisp.github.io/cl-cowsay/>.
The source for that site lives in [docs/src/](docs/src/).

## Quick Start

```lisp
(asdf:load-system "cl-cowsay")

(format t "~A~%" (cl-cowsay:say "Hello, nerima-lisp!"))
;;   ____________________
;; | Hello, nerima-lisp! |
;;   --------------------
;;         \   ^__^
;;          \  (oo)
;;             (__)
;;              u  u
```

Or from the command line:

```sh
cl-cowsay --think -c robot "Beep boop."
```

## Install

```nix
# flake.nix
inputs.cl-cowsay = {
  url = "github:nerima-lisp/cl-cowsay/v0.1.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Note the pinned tag. Consumers inside this org must pin a release tag rather
than follow the default branch.

## Documentation

- [Getting started](https://nerima-lisp.github.io/cl-cowsay/getting-started/)
- [Character gallery](https://nerima-lisp.github.io/cl-cowsay/guide/characters/)
- [Examples](https://nerima-lisp.github.io/cl-cowsay/guide/examples/)
- [CLI reference](https://nerima-lisp.github.io/cl-cowsay/reference/cli/)
- [API reference](https://nerima-lisp.github.io/cl-cowsay/reference/api/)

## Development

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY already set
nix run .#test       # run the test suite
nix flake check      # tests + formatting + docs, the same gate CI uses
nix fmt              # format Nix sources (treefmt)
```

Tests live in `t/` and run under [cl-weave](https://github.com/nerima-lisp/cl-weave),
the org's test framework.

## Contributing

See the org-wide [CONTRIBUTING](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
guide and the [package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

See [SUPPORT](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
