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
- A small streaming library (`cl-cowsay:write-say`) behind the command line,
  usable from any SBCL program

Full documentation is published at <https://nerima-lisp.github.io/cl-cowsay/>.
The source for that site lives in [docs/src/](docs/src/).

## Quick Start

```lisp
(asdf:load-system "cl-cowsay")

(cl-cowsay:write-say "Hello, nerima-lisp!" *standard-output*)
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
  url = "github:nerima-lisp/cl-cowsay";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

This example follows the repository's default branch, so the source can change
between runs. For reproducible production use, replace the branch reference
with a reviewed release tag or commit and keep the resulting `flake.lock` under
version control.

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
nix flake check      # tests + coverage + formatting + docs, the CI gate
nix fmt              # format Nix sources (treefmt)
```

Tests live in `t/` and run under [cl-weave](https://github.com/nerima-lisp/cl-weave),
the org's test framework. `cl-weave` is test-only; it is not a runtime
dependency.

## Contributing

See the org-wide [CONTRIBUTING](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
guide and the [package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

See [SUPPORT](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
