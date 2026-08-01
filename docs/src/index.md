# cl-cowsay

`cl-cowsay` is a **one-shot ASCII-art talking-animal message tool** for SBCL.
It word-wraps a message into a speech or thought bubble drawn above one of a
small set of original, hand-written ASCII-art characters, prints the result,
and exits. There is no animation loop and no raw-mode terminal takeover.

Unlike the classic `cowsay`, `cl-cowsay` is not a clone of its `.cow` Perl
file format: built-in characters are plain Lisp data with a minimal
`${eyes}` / `${tongue}` / `${thoughts}` substitution scheme, and none of the
art is copied from upstream.

Start with [Getting Started](getting-started.md), then see the
[API Reference](reference/api.md) for `cl-cowsay:say` and the rest of the
public surface.
