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
  [character gallery](https://nerima-lisp.github.io/cl-cowsay/guide/characters/))
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
;;  _____________________
;; | Hello, nerima-lisp! |
;;  ---------------------
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
nix flake check      # the whole CI gate -- every check listed below
nix fmt              # format Nix sources (treefmt)
```

Tests live in `t/` and run under [cl-weave](https://github.com/nerima-lisp/cl-weave),
the org's test framework. `cl-weave` is test-only; it is not a runtime
dependency.

`nix flake check` is more than tests and formatting. Each check in `flake.nix`
is its own derivation, so they build in parallel and any one of them can be run
alone with `nix build .#checks.<system>.<name>`. `nix flake show` lists the ones
your system actually has -- a check whose tooling is not published for your
platform is simply absent there -- so trust that listing over this one:

- `default` -- the `t/` suite.
- `cli-smoke` -- runs the delivered binary: `--version`, `--help`, a piped
  render, and ten separate `--random` starts that must not all produce the same
  character.
- `coverage` -- an sb-cover report gated at 100% expression and branch coverage
  over the executable library and CLI code.
- `library-boundary` -- the `cl-cowsay` library system must not reach for
  `cl-cli` or `cl-host-kit`; those belong to `cl-cowsay/cli` alone.
- `character-docs-drift` -- the character documentation must agree with
  `cl-cowsay --list`. See below.
- `docs` -- the MkDocs site, built with `--strict`, so a broken link or a page
  missing from the nav in `docs/mkdocs.yml` fails the build.
- `formatting` -- treefmt, the same evaluation `nix fmt` runs.
- `paredit-lint` -- every `.lisp` and `.asd` file the build ships must parse as
  a balanced S-expression document.

### The documentation drift gate

`checks.character-docs-drift` compares documentation against the built binary,
which means editing prose alone can turn CI red. It takes `cl-cowsay --list` as
the source of truth. The documents it gates are the ones named in that check's
own fileset in `flake.nix` -- this README, plus the pages under `docs/src/` that
state the character count. In each of them it checks

- the character count each document states -- and *how many times* it states
  it. Both the extraction pattern and its expected number of matches are pinned
  in the `assertCount` calls in `flake.nix`, so rewording, moving, or deleting a
  sentence that carries the count fails the check even when the number itself is
  still correct.
- the per-character `##` headings in the gallery and the hand-written name list
  in the API reference, each of which must match `--list` exactly, as a set.

When it fails, the message names the assertion (`G1` through `G10`) and prints
the disagreement. Usually the fix is to update the document. If a document
legitimately gains or loses a mention of the count, update the pinned
expectation in `flake.nix` in the same change; the gate is deliberately built so
that going quiet is a failure rather than a silent pass.

## Contributing

See the org-wide [CONTRIBUTING](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
guide and the [package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

See [SUPPORT](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
