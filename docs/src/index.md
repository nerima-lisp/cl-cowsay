# cl-cowsay

`cl-cowsay` is a **one-shot ASCII-art talking-animal message tool** for SBCL.
It word-wraps a message into a speech or thought bubble drawn above one of
**29 original, hand-written ASCII-art characters**, prints the result, and
exits. There is no animation loop and no raw-mode terminal takeover.

Unlike the classic `cowsay`, `cl-cowsay` is not a clone of its `.cow` Perl
file format: built-in characters are plain Lisp data with a minimal
`${eyes}` / `${tongue}` / `${thoughts}` substitution scheme, and none of the
art is copied from upstream.

## What's here

- **29 built-in characters** -- from the classic `cow` to a `dragon`, a
  `unicorn`, and a `skull`. Browse them all in the
  [character gallery](guide/characters.md).
- **8 eyes presets** (`borg`, `dead`, `greedy`, `paranoid`, `stoned`,
  `tired`, `wired`, `youthful`), the same shortcuts classic `cowsay` offers.
- **Speech and thought bubbles**, custom eyes/tongue overrides, adjustable
  wrap width, an optional no-wrap mode, a `--list` flag, and a `--random`
  character picker.
- **Shell completion** for Bash, Zsh, Fish, PowerShell, Nushell, and Elvish
  (`cl-cowsay --completion bash`), rendered live from the same option spec
  `--help` uses.
- A small, dependency-light **Lisp library** (`cl-cowsay:write-say`) behind the
  command line, usable on its own from any SBCL program.

## Where to go next

- [Getting started](getting-started.md) -- install it and run your first `cl-cowsay`.
- [Character gallery](guide/characters.md) -- see every built-in character rendered.
- [Examples](guide/examples.md) -- a cookbook of CLI and library usage.
- [CLI reference](reference/cli.md) -- every flag, in one table.
- [API reference](reference/api.md) -- `cl-cowsay:write-say` and the rest of the public surface.
