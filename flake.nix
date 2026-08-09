{
  description = "cl-cowsay: a one-shot ASCII-art talking-animal message tool for SBCL";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # `inputs.nixpkgs.follows` is mandatory on every input: without it each one
    # drags in its own nixpkgs, inflating flake.lock and rebuilding the same
    # derivations.

    # The org flake preset. Everything this file would otherwise spell out by
    # hand -- the `.asd` version extraction, `forAllSystems`, the treefmt eval
    # wired to both `formatter` and `checks.formatting`, the mkdocs package
    # plus its check, the run-tests.lisp gate, and the `apps.test`/
    # `apps.default` pair -- is one `mkPackageFlake` call below. Pinned to a
    # release TAG, never to the branch: a bare `github:nerima-lisp/cl-nix-forge`
    # follows that repository's default branch and would change this build
    # without warning.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Display-cell measurement (cl-tty-kit:char-width and
    # cl-tty-kit:string-width), used by src/bubble.lisp and src/wrap.lisp.
    # v1.4.0's additions (stream-fd/fd-wait polling,
    # renderer-invalidate, with-screen-batch, terminal-size/stream-input
    # pollers) are all for a resident, raw-mode TUI's tick loop; this is a
    # one-shot, non-interactive renderer (see src/cli.lisp's own header
    # comment), so none of them apply here. The width API this package uses is
    # covered by cl-tty-kit's own API stability guarantee; the version bump
    # also carries the SBCL type-declaration/optimization pass v1.4.0 made
    # across its hot paths.
    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # cl-tty-kit v1.5.0 names cl-codec-kit and cl-concurrent-kit in its ASDF
    # system. Its package installs only its OWN source tree, so the sibling
    # source trees must also be placed on this build's registry or ASDF cannot
    # resolve those edges. cl-concurrent-kit's matching boundary/date inputs
    # are registered below from cl-tty-kit's locked input graph.
    # `flake = false`: consumed as a SOURCE TREE and built here, not read from
    # its own `packages` output. cl-codec-kit has not cut a release declaring
    # aarch64-darwin, so reading `packages.${system}` would fail on macOS; a
    # source tree has no platform at all. This is ADR-0079's default shape --
    # a non-flake input also contributes no second nixpkgs to flake.lock.
    cl-codec-kit = {
      url = "github:nerima-lisp/cl-codec-kit/v0.5.0";
      flake = false;
    };

    # Declarative CLI parsing plus --help/--version scaffolding, used by
    # src/cli.lisp -- including its DEFINE-APP macro, which is what
    # *COWSAY-APP* is built with instead of nested MAKE-APP/MAKE-OPTION/
    # MAKE-POSITIONAL calls. cl-cli.asd itself `:depends-on`s cl-host-kit
    # (below), so its OWN cl-host-kit input follows this build's rather than
    # bringing in a second, separately pinned copy -- the same "mandatory
    # `nixpkgs.follows`" reasoning above, applied to a second shared input.
    cl-cli = {
      url = "github:nerima-lisp/cl-cli/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-host-kit.follows = "cl-host-kit";
    };

    # Structural S-expression tooling for src/ and t/: a dev-shell binary for
    # agent-driven refactors (paredit edit/refactor/query/fix) and a
    # structural-parse lint gate reused in `checks.paredit-lint` below.
    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # QUIT and GETCWD for src/cli.lisp's IMAGE-ENTRY-POINT -- SBCL-native
    # replacements for the two UIOP calls it used to make. cl-cowsay is
    # SBCL-only already (see :build-operation in cl-cowsay.asd), so UIOP's
    # cross-implementation portability buys it nothing there. `flake = false`
    # like cl-codec-kit above and for the same reason: cl-cli already
    # `:depends-on`s cl-host-kit as a SOURCE TREE built locally (see
    # `lispDependencies`), and `inputs.cl-host-kit.follows` on the `cl-cli`
    # input above only works if both inputs resolve the same way -- a built
    # `packages.${system}` output here would give `installSource` two
    # differently-shaped copies of the same system name.
    cl-host-kit = {
      url = "github:nerima-lisp/cl-host-kit/v0.3.1";
      flake = false;
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-nix-forge,
      cl-weave,
      cl-tty-kit,
      cl-codec-kit,
      cl-cli,
      cl-host-kit,
      paredit-cli,
      treefmt-nix,
    }:
    let
      lib = nixpkgs.lib;

      # x86_64-linux is what CI gates; aarch64-darwin is the development
      # machine. Every per-system output -- packages, checks, apps AND devShells
      # -- comes from this one list, so leaving aarch64-darwin out takes `nix
      # build` and `nix develop` off the development machine as well. That trade
      # was made on 2026-08-01 and reverted on 2026-08-02; aarch64-darwin carries
      # no CI gate, which PACKAGE_STANDARD.md's "systems" section accepts
      # explicitly. aarch64-linux and x86_64-darwin are nobody's verification and
      # are not declared.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      meta = {
        description = "A one-shot ASCII-art talking-animal message tool for SBCL";
        homepage = "https://github.com/nerima-lisp/cl-cowsay";
        license = lib.licenses.mit;
        platforms = lib.platforms.unix;
        mainProgram = "cl-cowsay";
      };
    in
    # `mkPackageFlake` spans systems -- it obtains a `pkgs` and its own
    # cl-nix-forge instance per entry in `systems` -- so the per-system `lib`
    # instance this function is *taken from* contributes nothing but the
    # function itself.
    cl-nix-forge.lib.${builtins.head systems}.mkPackageFlake {
      inherit
        self
        systems
        nixpkgs
        meta
        ;
      pname = "cl-cowsay";

      # Single source of truth for the package version: the `:version` form in
      # cl-cowsay.asd. A release only ever edits the .asd file and every
      # derivation carrying a version follows automatically.
      asd = ./cl-cowsay.asd;

      # Path literal, not `self`: `lib.fileset` refuses a flake's string-like
      # `self`. `./.` is the same directory.
      root = ./.;

      # cl-tty-kit and cl-cli are BUILT DERIVATIONS (each sibling's ASDF
      # system, from its own flake's `packages.<system>`), not source
      # directories -- putting a sibling's uncompiled source on the registry
      # instead would have ASDF try to write fasls next to it, inside the
      # read-only Nix store.
      # `fromDerivation` on cl-tty-kit, plain on cl-cli. The two siblings are
      # built by different machinery: cl-cli's flake is a `mkPackageFlake`
      # adopter, so its package carries the `passthru.ancestry` cl-nix-forge's
      # deduplicating registry walk reads, while cl-tty-kit still builds its
      # own package with nixpkgs' `pkgs.sbcl.buildASDFSystem`, which does not.
      # Passing the latter straight through fails evaluation with
      # `attribute 'ancestry' missing`; `fromDerivation` is cl-nix-forge's own
      # adapter for exactly that -- a package it did not build and about which
      # it can assume nothing. cl-regex-kit wraps cl-weave the same way.
      lispDependencies =
        ctx:
        let
          hostKit = ctx.cl.lispDerivation {
            pname = "cl-host-kit";
            lispSystem = "cl-host-kit";
            version = ctx.cl.fromAsdSystem "${cl-host-kit}/cl-host-kit.asd";
            src = cl-host-kit;
          };
          boundaryKit = ctx.cl.lispDerivation {
            pname = "cl-boundary-kit";
            lispSystem = "cl-boundary-kit";
            version = ctx.cl.fromAsdSystem "${cl-tty-kit.inputs.cl-boundary-kit}/cl-boundary-kit.asd";
            src = cl-tty-kit.inputs.cl-boundary-kit;
            lispDependencies = [ hostKit ];
          };
          dateKit = ctx.cl.lispDerivation {
            pname = "cl-date-kit";
            lispSystem = "cl-date-kit";
            version = ctx.cl.fromAsdSystem "${cl-tty-kit.inputs.cl-date-kit}/cl-date-kit.asd";
            src = cl-tty-kit.inputs.cl-date-kit;
          };
          concurrentKit = ctx.cl.lispDerivation {
            pname = "cl-concurrent-kit";
            lispSystem = "cl-concurrent-kit";
            version = ctx.cl.fromAsdSystem "${cl-tty-kit.inputs.cl-concurrent-kit}/cl-concurrent-kit.asd";
            src = cl-tty-kit.inputs.cl-concurrent-kit;
            lispDependencies = [
              boundaryKit
              dateKit
            ];
          };
        in
        [
          (ctx.cl.fromDerivation { drv = cl-tty-kit.packages.${ctx.system}.cl-tty-kit; })
          (ctx.cl.lispDerivation {
            lispSystem = "cl-codec-kit";
            version = ctx.cl.fromAsdSystem "${cl-codec-kit}/cl-codec-kit.asd";
            src = cl-codec-kit;
          })
          hostKit
          boundaryKit
          dateKit
          concurrentKit
          cl-cli.packages.${ctx.system}.cl-cli
        ];

      # cl-weave is a dependency of `cl-cowsay/test` only (see cl-cowsay.asd),
      # so it is a CHECK dependency: it must not enter the library's closure.
      lispCheckDependencies = ctx: [ cl-weave.packages.${ctx.system}.cl-weave ];

      # Drives BOTH `checks.default` and `apps.test`, from this one number, so
      # the command a contributor runs by hand and the gate CI runs cannot
      # drift apart. `killAfterSeconds` is cl-nix-forge's own default (30);
      # spelled out rather than left implicit so a runaway test process is
      # provably bounded by an escalating SIGTERM-then-SIGKILL, not by
      # whatever timeout the enclosing CI job happens to have.
      timeoutSeconds = 120;
      killAfterSeconds = 30;

      # The delivered `cl-cowsay` binary: `packages.default`, `apps.default`
      # and `apps.cl-cowsay`, all three built from the same `lispDerivation`
      # arguments as `packages.cl-cowsay`. The library system remains the
      # package's default ASDF entry, so the executable must explicitly select
      # the separate `cl-cowsay/cli` program system below. Its
      # `:build-operation "program-op"`, `:build-pathname "cl-cowsay"` and
      # `:entry-point "cl-cowsay/cli::image-entry-point"` stay authoritative in
      # cl-cowsay.asd; this Nix selection is the bridge from the package to that
      # system. See cl-weave/flake.nix and cl-nix-forge's org-preset example.
      executable = {
        lispSystem = "cl-cowsay/cli";
        # Where cl-nix-forge should LOOK for the image, not where ASDF puts it
        # -- the two are different questions and only the first one is Nix's.
        # ASDF writes the program to `:pathname` + `:build-pathname`, i.e.
        # `src/` + `cl-cowsay`; left unset, cl-nix-forge falls back to
        # `lispSystem` and asserts a file exists at `$out/cl-cowsay/cli`. That
        # fallback cannot succeed for a slash-bearing system name: `cl-cowsay/
        # cli` names an ASDF secondary system, and no `:build-pathname` can
        # ever spell it, because ASDF would read the slash as a directory
        # separator. So this is a lookup path, not a relocation -- the
        # `:build-pathname "cl-cowsay"` named in the comment above stays
        # authoritative in cl-cowsay.asd and still decides where the image
        # lands; this attribute only tells cl-nix-forge to go there.
        # Invisible on aarch64-darwin: cl-nix-forge takes a separate
        # Darwin-workaround code path that never reaches this assertion, so the
        # development machine builds green while x86_64-linux CI fails.
        programPath = "src/cl-cowsay";
        dynamicSpaceSize = 1024;
        installSource = true;
      };

      # docs/mkdocs.yml + docs/src/, built with `--strict` so a broken link or
      # a page missing from the nav is a build failure. `checks.docs` comes
      # with it.
      docs.root = ./docs;

      # ONE treefmt evaluation drives `nix fmt` and the `checks.formatting`
      # gate, so the formatter and CI can never disagree about what
      # "formatted" means.
      treefmt.evalModule = treefmt-nix.lib.evalModule;

      # The interactive-only extras: `self.formatter` is the same treefmt
      # evaluation `checks.formatting` uses, so formatting in the shell
      # cannot disagree with the gate; the cl-weave CLI binary puts `cl-weave
      # run` on PATH for ad-hoc filtered/watch runs the generated `apps.test`
      # does not cover; and paredit-cli is the structure-editing tool
      # PACKAGE_STANDARD.md and this repository's own refactors are done
      # through, rather than by hand-editing parentheses.
      #
      # paredit-cli v1.5.0 declares BOTH x86_64-linux and aarch64-darwin --
      # flake.nix:44-47 of the locked revision. So on this machine the guards
      # below are SATISFIED: paredit-cli is in the aarch64-darwin dev shell,
      # and `checks.aarch64-darwin.paredit-lint` exists as a real
      # aarch64-darwin derivation rather than being skipped.
      #
      # This comment used to assert the opposite, and the consequences it drew
      # were the inverse of what this machine does. The reasoning was sound
      # against the wrong tree: rev 9f8db23 really does declare only
      # x86_64-linux -- but that is the paredit-cli **cl-cli** pins. flake.lock
      # holds four paredit-cli nodes, and the one this flake uses is whichever
      # the ROOT's input edge points at (`paredit-cli_4`, rev 110e4e1a), not
      # the node that happens to be spelled `paredit-cli`.
      #
      # Resolve an input by EVALUATION, not by matching hashes against store
      # paths:
      #
      #   nix eval --raw --impure --expr \
      #     '(builtins.getFlake "git+file:///path/to/repo").inputs.paredit-cli.outPath'
      #
      # Hash-hunting for a store path is what produced the wrong answer twice
      # here; the store holds older checkouts of the same repository, and
      # `nix hash path --sri` on the correct path does not reproduce the lock's
      # narHash anyway.
      #
      # The guards stay, and are not vestigial -- they are defensive against
      # that declaration CHANGING, which is live: paredit-cli's own flake
      # states a policy of declaring only what a CI gate verifies, and this
      # input is pinned to a TAG. `lib.optional`/`lib.optionalAttrs` on a `?`
      # membership test then degrade to a missing dev-shell entry and a skipped
      # check, instead of failing evaluation with `attribute 'aarch64-darwin'
      # missing` -- the same shape of gap cl-tty-kit's `:depends-on
      # ("cl-codec-kit")` hit before it (see the `cl-codec-kit` input above).
      devShellPackages =
        ctx:
        [
          self.formatter.${ctx.system}
          cl-weave.packages.${ctx.system}.default
        ]
        ++ lib.optional (paredit-cli.packages ? ${ctx.system}) paredit-cli.packages.${ctx.system}.default;

      # Granularity lives here, not in extra GitHub Actions jobs: `nix flake
      # check` evaluates each attribute as its own derivation, with build
      # caching, so a check added here is exactly as parallel as the
      # generated ones.
      extraOutputs =
        ctx:
        let
          # Exercise the delivered image, not an SBCL script or the library
          # derivation. This catches a regression where the executable preset
          # silently selects the library ASDF system and produces a no-op
          # wrapper with no entry point.
          packaged-cli = lib.getExe ctx.executable;

          cliSmoke = ctx.cl.mkCommandCheck {
            drv = ctx.package;
            name = "cl-cowsay-cli-smoke";
            # mkCommandCheck wraps the WHOLE script in a single
            # `timeout --kill-after=<k>s <n>s` (cl-nix-forge
            # lib/core/check-runtime.nix), so this one budget covers every
            # invocation below plus the loop -- it is not a per-command limit.
            # The script went from 3 invocations to 13 (--version, --help, one
            # piped render, and ten --random runs), each of which execs a
            # wrapper that starts SBCL against a ~105 MB dumped core whose
            # pages fault in from disk on a cold runner. 130 keeps roughly the
            # original ~10s-per-start allowance instead of tightening it to
            # 4.6s; this check exists to catch a constant --random, not to
            # catch slowness, so the slack costs nothing and removes a flake
            # source.
            timeoutSeconds = 130;
            command = [
              (lib.getExe ctx.pkgs.bash)
              "-e"
              "-u"
              "-o"
              "pipefail"
              "-c"
              ''
                ${lib.escapeShellArg packaged-cli} --version > version.txt
                ${lib.escapeShellArg packaged-cli} --help > help.txt
                printf '%s\n' 'Hello from the packaged CLI.' | ${lib.escapeShellArg packaged-cli} > output.txt

                # --random must not be a constant. SBCL starts every fresh
                # process with an identical *random-state*, and
                # save-lisp-and-die preserves whatever state the image was
                # dumped with, so a one-shot CLI that draws exactly once per
                # process returns the SAME character forever unless
                # IMAGE-ENTRY-POINT reseeds -- which is a defect no in-process
                # test can see, because within one process the draws do vary.
                # Only separate process starts expose it, which is why this
                # lives in the packaged-binary check and not in t/.
                #
                # Ten runs, comparing whole renderings rather than lines: two
                # different characters can share a bubble line, so counting
                # distinct lines would call a constant picker "varied".
                #
                # The seen-set is an associative array, not a delimited string.
                # Any single-character delimiter cheap enough to use also
                # occurs INSIDE the data -- `|` in particular is the speech
                # bubble's own side character (%BUBBLE-SIDE-CHARACTER in
                # src/bubble.lisp), and `--random` renders in speech mode -- so
                # a `case "$seen" in *"|$rendering|"*)` membership test can
                # match a candidate against one stored rendering's internal `|`
                # and the next one's, across the boundary between them. That
                # counts a genuinely new rendering as already-seen, i.e. it
                # UNDERCOUNTS, which is the direction that fails a healthy CI
                # run. Bash compares whole associative-array keys, newlines and
                # pipes included, so there is no delimiter to collide with.
                # `declare -A seen=()` rather than a bare `declare -A seen`:
                # under `set -u`, reading ''${#seen[@]} from an associative
                # array that was declared but never assigned is an unbound-
                # variable error, and the empty assignment is what makes the
                # zero-iteration case safe.
                #
                # Threshold: with the reseed reverted distinct is exactly 1,
                # but `-le 1` passes a PARTIAL reseed -- one drawing from a
                # coarse clock, where runs landing in the same second agree and
                # distinct settles at 2 or 3. With 29 characters and 10 draws
                # the expected number of distinct renderings is about 8.4, and
                # a genuinely seeded run yielding 2 or fewer is on the order of
                # 1e-9, so `-le 2` is decisive and strictly stronger.
                # Written with only bash builtins on purpose -- the check's
                # PATH is not guaranteed to carry coreutils.
                declare -A seen=()
                attempt=0
                while [ "$attempt" -lt 10 ]; do
                  rendering="$(${lib.escapeShellArg packaged-cli} --random 'hi')"
                  seen["$rendering"]=1
                  attempt=$((attempt + 1))
                done
                distinct=''${#seen[@]}
                printf 'distinct renderings across 10 --random runs: %s\n' "$distinct" > random.txt
                if [ "$distinct" -le 2 ]; then
                  printf '%s\n' 'cl-cowsay --random produced 2 or fewer distinct renderings across 10 separate processes: *random-state* is not being reseeded at the process boundary, or is being reseeded from a source too coarse to vary between runs' >&2
                  exit 1
                fi
              ''
            ];
            artifacts = [
              "version.txt"
              "help.txt"
              "output.txt"
              "random.txt"
            ];
          };

          # An sb-cover HTML report with a hard 100% gate over executable
          # `cl-cowsay` and `cl-cowsay/cli` code. cl-weave's coverage filters
          # exclude only non-runtime declaration/data files (packages, macro
          # and condition declarations, character/eyes/bubble data, and CLI
          # declaration files); rendering, wrapping, and runtime handlers
          # remain instrumented. The test entry point supplies the thresholds
          # because `mkCoverageReport` exposes the runner, not a separate
          # validation hook. Spelled once, as a function of
          # `ctx`, and used for both `packages.coverage` and `checks.coverage`
          # below, so the two attributes are literally the same derivation.
          # It asserts its own report is non-empty before installing it.
          coverageReport = ctx.cl.mkCoverageReport {
            drv = ctx.package;
            name = "cl-cowsay-coverage";
            systems = [
              "cl-cowsay"
              "cl-cowsay/cli"
            ];
            # Run the normal test package through its coverage mode. A
            # nonzero result from cl-weave's threshold check fails this
            # derivation and therefore both the package and check outputs.
            entryPointText = ''
              (asdf:load-system "cl-cowsay/test")
              (funcall
                (symbol-function
                  (find-symbol "RUN-TESTS" "CL-COWSAY/TEST"))
                :coverage t)
            '';
            # Instrumented SB-COVER compilation exceeds the normal test
            # timeout on a cold Darwin store; keep coverage bounded without
            # truncating the report before the test system finishes loading.
            timeoutSeconds = 600;
            killAfterSeconds = 30;
          };

          # The library/CLI boundary, made machine-enforced instead of
          # reviewer-enforced. `.serena/memories/cl-cowsay/runtime-boundaries.md`
          # records the invariant: the `cl-cowsay` LIBRARY must not load
          # cl-cli or cl-host-kit; only `cl-cowsay/cli` may. Until this check
          # existed the only thing holding it was cl-cowsay.asd:24's
          # `:depends-on ("cl-tty-kit")` and somebody noticing a diff.
          #
          # HALF THAT INVARIANT IS ALREADY FALSE, and writing this check is
          # what found it. `(find-package "HOST-KIT")` is NON-NIL after
          # loading the library alone, on an untouched tree, through a chain
          # that is entirely outside this repository:
          #
          #   cl-cowsay.asd:24          :depends-on ("cl-tty-kit")
          #   cl-tty-kit.asd:79         :depends-on ("cl-codec-kit" "cl-concurrent-kit")
          #   cl-concurrent-kit.asd:29  :depends-on ("cl-boundary-kit" "cl-date-kit")
          #   cl-boundary-kit.asd:24    :depends-on (:asdf :cl-host-kit)
          #   cl-host-kit/src/package.lisp:7  (defpackage #:host-kit ...)
          #
          # So a literal `(find-package "HOST-KIT")` must-be-NIL assertion is
          # red on a correct tree, and pinning it green the other way -- an
          # assertion that HOST-KIT IS present -- would freeze somebody
          # else's transitive edge and turn a future cl-tty-kit cleanup into
          # a failing gate here. Neither is the invariant anyone cares about.
          #
          # What the memory is actually protecting is that the LIBRARY does
          # not reach for cl-host-kit itself, and that survives as three
          # assertions that are true, checkable, and falsifiable, one per
          # level at which the reach can happen:
          #
          #   N2a  DECLARATION -- the library's own :depends-on must not name
          #        cl-host-kit, wrapped or bare.
          #   N2b  DEFPACKAGE  -- no symbol accessible in package CL-COWSAY may
          #        be homed in HOST-KIT, which is what a `(:use #:host-kit)` or
          #        `(:import-from #:host-kit ...)` in src/package.lisp trips.
          #   N2c  REFERENCE   -- no file the library system compiles may
          #        mention `host-kit` or `cl-cli` at all.
          #
          # N2c is not redundant, and the gap it fills was measured rather than
          # imagined. A fully package-qualified call -- `(host-kit:getcwd)`
          # dropped into src/render.lisp -- declares nothing and interns
          # nothing, so N2a and N2b are both silent, and it COMPILES AND RUNS,
          # because ASDF has already loaded cl-host-kit transitively by the
          # time it compiles this library. That mutation was run against this
          # very check and it reported `N2a ... held` and exited 0.
          #
          # This is also where the boundary's weakest link used to be recorded
          # as prose: "verified today, no non-CLI file under src/ mentions
          # host-kit or cl-cli at all." That was a real check, performed by
          # hand, on one day, decaying from the moment it was written. N2c is
          # that same sentence, executed every build.
          #
          # cl-cli's half needs no such reinterpretation -- N1 below is the
          # plain package probe and it holds.
          #
          # `drv = ctx.package`, deliberately, and NOT `ctx.executable`.
          # `ctx.package` is the library-only `lispDerivation` (cl-nix-forge
          # lib/batteries/package-flake.nix:473, built from
          # `lispDerivationArgs` whose `lispSystem` defaults to `pname`,
          # :357) -- so what it has loaded at the start of this script is
          # exactly the library. Its resolved CL_SOURCE_REGISTRY does carry
          # the whole dependency closure, cl-cli and cl-host-kit included
          # (see `lispDependencies` above), and that REACHABILITY is what
          # gives the check teeth rather than taking them away: being on the
          # registry is not being loaded, so a stray `:depends-on ("cl-cli")`
          # added to the library system would genuinely resolve and load, and
          # trip N1 below -- instead of dying with an ASDF "system not found"
          # that proves nothing about the boundary. `ctx.executable` would be
          # wrong twice: it is a `runCommand` whose `passthru` differs
          # between the Linux and Darwin code paths, and its image has
          # `cl-cowsay/cli` loaded by construction, so N1/N2 could never hold.
          #
          # Two traps, both load-bearing:
          #
          # 1. `mkScriptCheck` runs `entryPointText` RAW -- it writes the text
          #    to a store file and hands it straight to `sbcl --script`
          #    (cl-nix-forge lib/core/script-check.nix:79-89). It does NOT
          #    prepend `(require "asdf")`. `mkCoverageReport` does wrap its
          #    text in a runner that opens with `(require "asdf")`
          #    (lib/batteries/coverage.nix:93-116), which is the only reason
          #    `coverageReport` above gets away without one. Hence the
          #    explicit `require` on the first line here.
          #
          # 2. NOTHING below is wrapped in `handler-case` or `ignore-errors`.
          #    This derivation fails on a bad load only because SBCL's
          #    `--script` implies `--disable-debugger`, and that is what turns
          #    an unhandled condition into exit 1
          #    (lib/core/asdf-derivation.nix:55-57). Catching the condition to
          #    "report it nicely" would convert every real failure into a
          #    green build.
          libraryBoundary = ctx.cl.mkScriptCheck {
            drv = ctx.package;
            name = "cl-cowsay-library-boundary";
            # The library's own FASLs are already built by `buildPhase`, but
            # phase 2 compiles `cl-cowsay/cli` from source in this same
            # image, so this is not a load-only budget.
            timeoutSeconds = 180;
            killAfterSeconds = 30;
            entryPointText = ''
              (require "asdf")

              (defun boundary-dependencies (system-name)
                "SYSTEM-NAME's DIRECT :depends-on list, as ASDF parsed it."
                (let ((system (asdf:find-system system-name nil)))
                  (unless system
                    (error "FAILED: (asdf:find-system ~S nil) returned NIL." system-name))
                  (asdf:system-depends-on system)))

              (defun boundary-dependency-name (dependency)
                "The system name DEPENDENCY refers to, as a string, or NIL.

              ASDF does NOT normalize a wrapped :depends-on entry. Written
              (:version \"cl-host-kit\" \"0.3.1\"), it is handed straight back
              by ASDF:SYSTEM-DEPENDS-ON as that three-element LIST, so a
              predicate that inspects only atoms stops seeing the name and
              every negative assertion built on it silently passes. That is not
              hypothetical: it was measured on this tree -- with the library's
              :depends-on written as (\"cl-tty-kit\" (:version \"cl-host-kit\"
              \"0.3.1\")), the atom-only predicate returned NIL and this whole
              check reported `N2a ... held`.

              (:feature <feature> <dep>) nests the real dependency in its THIRD
              element, and either wrapper may nest inside the other, so this
              recurses rather than unwrapping one level."
                (cond ((stringp dependency) dependency)
                      ((and (symbolp dependency) dependency) (string dependency))
                      ((consp dependency)
                       (let ((head (first dependency)))
                         (cond ((not (or (stringp head) (symbolp head))) nil)
                               ((member (string head) '("VERSION" "REQUIRE")
                                        :test #'string-equal)
                                (boundary-dependency-name (second dependency)))
                               ((string-equal (string head) "FEATURE")
                                (boundary-dependency-name (third dependency)))
                               (t nil))))
                      (t nil)))

              (defun boundary-names-p (dependencies name)
                "True when DEPENDENCIES names NAME, wrapped or not,
              case-insensitively. See BOUNDARY-DEPENDENCY-NAME for why the
              wrapped forms have to be unwrapped here rather than assumed away."
                (some (lambda (dependency)
                        (let ((dependency-name (boundary-dependency-name dependency)))
                          (and dependency-name (string-equal name dependency-name))))
                      dependencies))

              (defun boundary-homed-symbols (package-name home-name)
                "Every symbol ACCESSIBLE in PACKAGE-NAME whose HOME package is
              HOME-NAME -- i.e. what a (:use ...) or (:import-from ...) of
              HOME-NAME would introduce.

              Signals an error rather than returning NIL when either package is
              missing. The earlier `(when (and package home) ...)` guard FAILED
              OPEN: a renamed or misspelled HOME-NAME made this return NIL, and
              NIL is exactly what a clean tree returns, so the probe reported
              `clean` about nothing. An absence must never be producible by a
              lookup failure."
                (let ((package (find-package package-name))
                      (home (find-package home-name))
                      (found nil))
                  (unless package
                    (error "FAILED: (find-package ~S) returned NIL, so a symbol scan over it could only ever report a vacuous absence."
                           package-name))
                  (unless home
                    (error "FAILED: (find-package ~S) returned NIL, so a scan for symbols homed there could only ever report a vacuous absence."
                           home-name))
                  (do-symbols (symbol package)
                    (when (eq (symbol-package symbol) home)
                      (pushnew symbol found)))
                  found))

              (defun boundary-component-files (system-name)
                "The pathname of every source file SYSTEM-NAME itself compiles.
              Its OWN components only -- not its dependencies'. Taken from ASDF
              rather than from a hand-written list so it cannot drift from
              cl-cowsay.asd's :components."
                (let ((system (asdf:find-system system-name nil))
                      (files nil))
                  (unless system
                    (error "FAILED: (asdf:find-system ~S nil) returned NIL." system-name))
                  (labels ((walk (component)
                             (cond ((typep component 'asdf:source-file)
                                    (push (asdf:component-pathname component) files))
                                   ((typep component 'asdf:module)
                                    (mapc #'walk (asdf:component-children component))))))
                    (mapc #'walk (asdf:component-children system)))
                  (nreverse files)))

              (defun boundary-file-mentions (path needles)
                "Every needle in NEEDLES occurring in the file at PATH,
              case-insensitively. Reads the whole file: a mention inside a
              comment or a string counts, because this is a REFERENCE-level ban
              and not a reader-level one."
                (let ((text (with-open-file (in path :external-format :utf-8)
                              (let ((buffer (make-string (file-length in))))
                                (subseq buffer 0 (read-sequence buffer in))))))
                  (remove-if-not (lambda (needle) (search needle text :test #'char-equal))
                                 needles)))

              ;;; ---- Shared names --------------------------------------------
              ;; Every probe and the control that certifies it read the SAME
              ;; binding. Spelled twice -- once in the probe, once in its
              ;; control -- a single typo disarms the probe while its control
              ;; goes on passing against the other copy, which is the exact
              ;; shape of failure the controls exist to prevent. There were
              ;; eight such literals here.
              (let ((library-system "cl-cowsay")
                    (cli-system "cl-cowsay/cli")
                    (tty-kit-system "cl-tty-kit")
                    (host-kit-system "cl-host-kit")
                    (cl-cli-system "cl-cli")
                    (library-package "CL-COWSAY")
                    (cli-package "CL-COWSAY/CLI")
                    (host-kit-package "HOST-KIT")
                    (cl-cli-package "CL-CLI")
                    ;; The reference-level ban, as literal source text. Bare
                    ;; tokens, NOT the package-qualified `host-kit:` spelling:
                    ;; no cl-cowsay/cli component contains a colon-qualified
                    ;; reference at all (src/cli-package.lisp reaches
                    ;; cl-host-kit through `(:import-from #:host-kit ...)`), so
                    ;; a control over the qualified form could never be
                    ;; satisfied from this repository and would be the vacuity
                    ;; it was meant to rule out. The token form both SUBSUMES
                    ;; the qualified form -- `(host-kit:getcwd)` contains
                    ;; `host-kit` -- and has a real positive instance to
                    ;; certify against. It is also the literal mechanisation of
                    ;; the hand-check this comment block used to record: "no
                    ;; non-CLI file under src/ mentions host-kit or cl-cli at
                    ;; all."
                    (boundary-needles (list "host-kit" "cl-cli")))

              ;;; ---- Phase 1: the library, alone -----------------------------
              (asdf:load-system library-system)

              (unless (find-package library-package)
                (error "P1 FAILED: no package ~A after (asdf:load-system ~S)."
                       library-package library-system))

              (multiple-value-bind (symbol status) (find-symbol "WRITE-SAY" library-package)
                (unless (eq status :external)
                  (error "P2 FAILED: WRITE-SAY in ~A has status ~S, not :EXTERNAL (symbol ~S). The library's public entry point is not exported."
                         library-package status symbol))
                ;; P3 separates "the defpackage form was read" from "the
                ;; components actually ran". An export interns a symbol; it
                ;; does not define it. Without this, a build that loaded
                ;; src/package.lisp and nothing else would satisfy P1 and P2.
                (unless (fboundp symbol)
                  (error "P3 FAILED: CL-COWSAY:WRITE-SAY is exported but unfbound. The defpackage loaded; the components that define it did not.")))

              ;; P4 pins WHICH cl-cowsay.asd was read. Every dependency in the
              ;; closure sits on this image's CL_SOURCE_REGISTRY, so ASDF could
              ;; in principle resolve the name against some other tree; an
              ;; empty or cl-tty-kit-less :depends-on is the signature of that.
              ;; P4 is also what makes N2a below mean anything: N2a is a
              ;; NEGATIVE claim about this same list, and a negative claim
              ;; about an empty or foreign list is worth nothing.
              (let ((dependencies (boundary-dependencies library-system)))
                (unless dependencies
                  (error "P4 FAILED: system ~A declares an EMPTY :depends-on. cl-cowsay.asd names ~A, so the .asd ASDF read here is not this project's."
                         library-system tty-kit-system))
                (unless (boundary-names-p dependencies tty-kit-system)
                  (error "P4 FAILED: system ~A :depends-on is ~S, which does not contain ~A. A stale sibling .asd was found on the registry first."
                         library-system dependencies tty-kit-system))

                ;; N2a -- the library must not reach for cl-host-kit ITSELF.
                ;; Deliberately about the DIRECT :depends-on and not about
                ;; (find-package "HOST-KIT"), which is non-NIL here through
                ;; cl-tty-kit -> cl-concurrent-kit -> cl-boundary-kit. See the
                ;; comment above this derivation for the full chain.
                (when (boundary-names-p dependencies host-kit-system)
                  (error "N2a FAILED: system ~A :depends-on is ~S, which names ~A directly (wrapped forms such as (:version ...) count). cl-host-kit belongs to ~A alone -- see .serena/memories/cl-cowsay/runtime-boundaries.md."
                         library-system dependencies host-kit-system cli-system))
                (when (boundary-names-p dependencies cl-cli-system)
                  (error "N1a FAILED: system ~A :depends-on is ~S, which names ~A directly (wrapped forms such as (:version ...) count). cl-cli belongs to ~A alone."
                         library-system dependencies cl-cli-system cli-system)))

              ;; N1 -- the runtime half of the cl-cli invariant. Nothing
              ;; anywhere in the library's closure loads cl-cli, so unlike
              ;; HOST-KIT this really is NIL, and it catches an edge that
              ;; N1a cannot: cl-cli pulled in TRANSITIVELY by some future
              ;; library dependency.
              (when (find-package cl-cli-package)
                (error "N1 FAILED: package ~A exists after loading ONLY the ~A library. The library/CLI boundary is broken -- see .serena/memories/cl-cowsay/runtime-boundaries.md. cl-cli belongs to ~A alone; check cl-cowsay.asd's library :depends-on and every (:import-from #:cl-cli ...) outside src/cli-package.lisp."
                       cl-cli-package library-package cli-system))

              ;; P4b -- N2b's PRECONDITION, asserted in Phase 1 because that is
              ;; where N2b runs. N2b is a scan for symbols homed in HOST-KIT,
              ;; and a scan whose home package does not exist reports the same
              ;; empty result as a clean tree. P7 in Phase 2 cannot stand in for
              ;; this: by then `cl-cowsay/cli` has loaded cl-host-kit directly,
              ;; so P7 certifies only that the package name is right AFTER a
              ;; load Phase 1 never performed. What makes HOST-KIT present HERE
              ;; is the transitive chain through cl-tty-kit documented above --
              ;; a chain entirely outside this repository, and therefore one
              ;; that can be broken by a release nobody here reviews.
              (unless (find-package host-kit-package)
                (error "P4b FAILED: package ~A does not exist after loading ONLY the ~A library, so N2b below would scan for symbols homed in a package that is absent and report a vacuous `clean`. cl-host-kit used to arrive transitively via ~A -> cl-concurrent-kit -> cl-boundary-kit; that edge is gone. N2b is now dead code -- delete it, or re-point it at whatever the boundary is today."
                       host-kit-package library-package tty-kit-system))

              ;; N2b -- the DEFPACKAGE half of the cl-host-kit invariant. NOT
              ;; the runtime half, which is what it used to be labelled: this
              ;; walks the symbols ACCESSIBLE in CL-COWSAY, so it sees exactly
              ;; what a (:use #:host-kit) or (:import-from #:host-kit ...) in
              ;; src/package.lisp would introduce -- and nothing else. A fully
              ;; package-qualified call, `(host-kit:getcwd)` in src/render.lisp,
              ;; interns nothing into CL-COWSAY, so it passes N2a and N2b and
              ;; compiles and runs, because ASDF has cl-host-kit loaded before
              ;; it compiles this library. That hole was demonstrated on this
              ;; tree with a live control; N2c below is what closes it.
              (let ((leaked (boundary-homed-symbols library-package host-kit-package)))
                (when leaked
                  (error "N2b FAILED: ~S symbol(s) homed in ~A are accessible in package ~A: ~S. The library's defpackage is importing from cl-host-kit; that belongs to ~A alone -- see .serena/memories/cl-cowsay/runtime-boundaries.md."
                         (length leaked) host-kit-package library-package leaked cli-system)))

              ;; N2c -- the REFERENCE half, and the one N2a and N2b between
              ;; them cannot see. Reads every file the library system itself
              ;; compiles and rejects any mention of the boundary tokens, in
              ;; code or comment. This is the assertion that used to live in
              ;; this derivation's header comment as a hand-check performed
              ;; once, by a person, on one day.
              (let ((library-files (boundary-component-files library-system))
                    (offenders nil))
                (unless library-files
                  (error "N2c FAILED: system ~A reports ZERO component source files, so the scan below would examine nothing and pass. cl-cowsay.asd's :components is empty, or ASDF resolved ~A to a system that is not this project's."
                         library-system library-system))
                (dolist (path library-files)
                  (let ((hits (boundary-file-mentions path boundary-needles)))
                    (when hits (push (list path hits) offenders))))
                (when offenders
                  (error "N2c FAILED: ~S file(s) compiled by the ~A LIBRARY mention a boundary token ~S: ~S. Both cl-cli and cl-host-kit belong to ~A alone -- see .serena/memories/cl-cowsay/runtime-boundaries.md. A package-qualified reference such as (host-kit:getcwd) interns nothing and is invisible to N2a and N2b, which is why this file-level scan exists."
                         (length offenders) library-system boundary-needles
                         (nreverse offenders) cli-system)))

              ;; P4c -- N2c's CONTROL, and in Phase 1 for the same reason P4b
              ;; is: N2c runs here. Purely a file read, so it needs no system
              ;; loaded, only cl-cowsay.asd parsed. The IDENTICAL needle list
              ;; and the IDENTICAL scanning function must find a match in
              ;; src/cli-package.lisp, whose (:import-from #:cl-cli ...) and
              ;; (:import-from #:host-kit ...) are the only thing pinning these
              ;; two spellings anywhere in the tree. If this fires, N2c was
              ;; scanning for text that occurs nowhere and reporting the
              ;; library clean of a token that no longer exists under either
              ;; name.
              (let* ((cli-files (boundary-component-files cli-system))
                     (package-file (find "cli-package" cli-files
                                         :key #'pathname-name
                                         :test #'string-equal)))
                (unless package-file
                  (error "P4c FAILED: system ~A has no component named cli-package; its files are ~S. N2c's control has no subject, so N2c is uncertified."
                         cli-system cli-files))
                (let ((found (boundary-file-mentions package-file boundary-needles)))
                  (unless (= (length found) (length boundary-needles))
                    (error "P4c FAILED: only ~S of the ~S boundary token(s) ~S occur in ~A -- found ~S. N2c is therefore searching for a spelling that appears nowhere, and its `clean` verdict on the library means nothing. Update ~S to whatever src/cli-package.lisp names today."
                           (length found) (length boundary-needles) boundary-needles
                           package-file found boundary-needles))))

              ;;; ---- Phase 2: the LOAD-DEPENDENT controls, same image --------
              ;; Not optional, and not bonus assertions. Every negative above
              ;; is an absence, and an absence is exactly what a renamed or
              ;; misspelled probe reports forever while looking at nothing:
              ;; (find-package ...) against a renamed package returns NIL
              ;; permanently, and `boundary-names-p` against a respelled
              ;; dependency returns false permanently.
              ;;
              ;; Phase 2 is NOT the control for everything above it, and the
              ;; comment that used to claim so was false by construction. A
              ;; control is only worth the state it shares with its probe, and
              ;; loading `cl-cowsay/cli` changes that state: it pulls in cl-cli
              ;; and cl-host-kit DIRECTLY, so any Phase-2 assertion is
              ;; certifying a name against an image the Phase-1 probe never
              ;; saw. Concretely, P7 below cannot certify N2b -- after this
              ;; load, HOST-KIT is present because cl-cowsay/cli asked for it,
              ;; which says nothing about whether it was present when N2b ran.
              ;; The probes that run in Phase 1 are controlled in Phase 1, by
              ;; P4b and P4c. What genuinely belongs here is only what REQUIRES
              ;; the CLI to be loaded: P5, and P6's read of a second system's
              ;; :depends-on.
              (asdf:load-system cli-system)

              ;; P5 -- control for N1.
              (unless (find-package cl-cli-package)
                (error "P5 FAILED: package ~A is absent even after loading ~A. N1 above was therefore vacuous -- it probed a name that can never appear. The package was renamed; update the CL-CLI-PACKAGE binding from src/cli-package.lisp."
                       cl-cli-package cli-system))

              ;; P6 -- control for N1a and N2a. Proves `boundary-names-p`
              ;; reads a populated list and that both spellings match what
              ;; ASDF actually stores.
              (let ((dependencies (boundary-dependencies cli-system)))
                (unless (boundary-names-p dependencies cl-cli-system)
                  (error "P6 FAILED: system ~A :depends-on is ~S, which does not name ~A. N1a above was therefore vacuous -- it searched for a spelling that appears nowhere."
                         cli-system dependencies cl-cli-system))
                (unless (boundary-names-p dependencies host-kit-system)
                  (error "P6 FAILED: system ~A :depends-on is ~S, which does not name ~A. N2a above was therefore vacuous -- it searched for a spelling that appears nowhere."
                         cli-system dependencies host-kit-system)))

              ;; P7 -- control for the SCANNER `boundary-homed-symbols`, not
              ;; for N2b's precondition (that is P4b's job, in Phase 1).
              ;; cl-cowsay/cli imports HOST-KIT:QUIT and HOST-KIT:GETCWD, so a
              ;; working scan MUST return a non-empty result here. If this
              ;; fires, the scan cannot detect an import it is looking straight
              ;; at, and N2b's `clean` verdict is worthless for that reason
              ;; rather than for a missing-package reason.
              (let ((imported (boundary-homed-symbols cli-package host-kit-package)))
                (unless imported
                  (error "P7 FAILED: no ~A-homed symbol is accessible in ~A, yet src/cli-package.lisp imports HOST-KIT:QUIT and HOST-KIT:GETCWD. The symbol scan itself is broken, so N2b above detects nothing."
                         host-kit-package cli-package)))

              (format t "~&library boundary: P1-P4, P4b, P4c, P5-P7, N1, N1a, N2a, N2b and N2c all held.~%"))
            '';
          };

          # Gate the character-count and gallery drift that six documents
          # and src/characters-data.lisp currently keep in sync by hand.
          #
          # Why a plain `runCommand` and not a Lisp derivation reading the
          # markdown: it CANNOT be one. `mkLispSource` is an extension
          # allowlist defaulting to [ "asd" "lisp" ] (cl-nix-forge
          # lib/core/source.nix:58-66), and this flake passes `root = ./.`
          # with no `sourceInclude`, so `ctx.src` contains 28 .lisp files and
          # 1 .asd and zero .md. A Lisp check would die on file-not-found or,
          # written defensively, pass while comparing nothing.
          #
          # And the fix is NOT to add markdown to `sourceInclude`: `ctx.src`
          # feeds `ctx.package`, `checks.default`, `checks.coverage`,
          # `checks.cli-smoke` and `packages.default`, so a README typo would
          # rebuild the library, re-run the suite, and re-run the 600-second
          # instrumented coverage build. source.nix:7-41 argues at length
          # against exactly that coupling.
          #
          # That cost argument is about `sourceInclude`, and it does NOT
          # transfer to the fileset below, which was for a while defended with
          # it. Widening THIS fileset rebuilds this `runCommand` and nothing
          # else -- no library, no suite, no coverage derivation -- so the only
          # thing a narrow fileset here buys is a cache hit on a check that
          # runs in about a second. It cost correctness: the fileset named four
          # documents while SIX state the character count, and the two it
          # omitted were not merely ungated but structurally invisible.
          # Measured, not reasoned: with `docs/src/getting-started.md` edited
          # to claim 9999 characters, this check rebuilt to the byte-identical
          # store path -- it cannot fail on a file that is not among its
          # inputs. `docs/src/guide/examples.md` was doubly missed, being both
          # outside the fileset and matched by no pattern.
          #
          # So: two narrow inputs and nothing else. The generator is the
          # already-built `packaged-cli` (no new build -- `cliSmoke` above
          # uses the same store path), and the documents come in through their
          # own markdown-only fileset, so this check rebuilds when a doc
          # changes and nothing else in the flake does.
          characterDocsDrift =
            let
              # Every markdown file under docs/, plus README.md. Deliberately
              # NOT an enumeration: an enumeration is a claim about which files
              # make a count claim, and G11 below turns that claim into an
              # assertion. Restricted to `.md` so the fileset and G11's walk
              # cover exactly the same files, and so adding an image to docs/
              # does not rebuild this check.
              documents = lib.fileset.toSource {
                root = ./.;
                fileset = lib.fileset.unions [
                  ./README.md
                  (lib.fileset.fileFilter (file: file.hasExt "md") ./docs/src)
                ];
              };
            in
            ctx.pkgs.runCommand "cl-cowsay-character-docs-drift"
              {
                inherit documents;
                # perl for the one job shell cannot do cleanly here
                # (extracting a heading-delimited section of api.md);
                # coreutils/grep/diffutils come from stdenv.
                nativeBuildInputs = [ ctx.pkgs.perl ];
              }
              ''
                set -euo pipefail
                # Every `sort`/`comm`/`cmp` below must agree on collation, and
                # the names are plain lowercase ASCII, so C ordering also
                # matches the CL `string<` that src/characters.lisp:24-25
                # sorts `--list` with.
                export LC_ALL=C

                readme="$documents/README.md"
                index="$documents/docs/src/index.md"
                started="$documents/docs/src/getting-started.md"
                chars="$documents/docs/src/guide/characters.md"
                examples="$documents/docs/src/guide/examples.md"
                api="$documents/docs/src/reference/api.md"

                # A renamed or moved document must fail here, not silently
                # reduce a later grep to zero matches.
                for document in "$readme" "$index" "$started" "$chars" "$examples" "$api"; do
                  if [ ! -f "$document" ]; then
                    printf 'FAILED: expected document is not in this check fileset: %s\n' "$document" >&2
                    exit 1
                  fi
                done

                # ---- G1: the generator runs and says something -------------
                # `--list` writes one name per line and never reads stdin
                # (%LIST-CHARACTERS-HANDLER, src/cli.lisp), so there is no
                # pipe to feed it.
                ${lib.escapeShellArg packaged-cli} --list > names.txt
                if [ ! -s names.txt ]; then
                  printf 'G1 FAILED: `cl-cowsay --list` exited 0 but produced no output. Every comparison below would have been vacuous.\n' >&2
                  exit 1
                fi

                # ---- G2: N, the authority for everything after this --------
                # `grep -c .`, not `wc -l`: every peer count in this script
                # (G3, G4, G5, G7) counts NON-EMPTY LINES, and `wc -l` counts
                # newlines. The two agree only while `--list` terminates its
                # last name with a newline, which it does today because
                # %LIST-CHARACTERS-HANDLER uses `write-line`. Switch that to
                # `write-string` and `wc -l` undercounts by one while
                # `grep -c .` does not -- surfacing as a G3 failure blaming
                # src/characters-data.lisp for a duplicate `defcharacter` that
                # is not there. Counting the same way everywhere removes the
                # possibility rather than documenting it.
                n=$(grep -c . names.txt || true)
                if [ "$n" -lt 1 ]; then
                  printf 'G2 FAILED: `cl-cowsay --list` yielded %s names; expected at least 1.\n' "$n" >&2
                  exit 1
                fi

                # ---- G3: the source of truth has no duplicates -------------
                sort -u names.txt > names.sorted
                distinct=$(grep -c . names.sorted || true)
                if [ "$distinct" -ne "$n" ]; then
                  printf 'G3 FAILED: --list emitted %s names but only %s are distinct. Two defcharacter forms in src/characters-data.lisp share a name:\n' "$n" "$distinct" >&2
                  sort names.txt | uniq -d >&2
                  exit 1
                fi
                printf 'G1-G3 ok: --list is the authority, N=%s distinct names\n' "$n"

                # ---- G4: anti-vacuity for the gallery ----------------------
                # Anchored to a single lowercase word on purpose: a future
                # prose heading like `## Choosing a character` is excluded by
                # construction rather than showing up as a phantom character.
                grep -oE '^## [a-z][a-z0-9-]*$' "$chars" | cut -c4- > headings.txt || true
                headings=$(grep -c . headings.txt || true)
                if [ "$headings" -lt 1 ]; then
                  printf 'G4 FAILED: zero headings in docs/src/guide/characters.md matched ^## [a-z][a-z0-9-]*$. The gallery was restructured, so G5 and G6 below would compare an empty set against itself and pass. Re-point this pattern at the new gallery structure.\n' >&2
                  exit 1
                fi

                # ---- G5: no duplicated heading -----------------------------
                sort -u headings.txt > headings.sorted
                headingsDistinct=$(grep -c . headings.sorted || true)
                if [ "$headingsDistinct" -ne "$headings" ]; then
                  printf 'G5 FAILED: characters.md has %s character headings but only %s distinct. Duplicated:\n' "$headings" "$headingsDistinct" >&2
                  sort headings.txt | uniq -d >&2
                  exit 1
                fi

                # ---- G6: gallery == --list, as SETS ------------------------
                # Sets, not sequences: `--list` is alphabetical
                # (src/characters.lisp:24-25 sorts with #'string<) while the
                # gallery is in definition order (cow, cat, robot, ghost,
                # dragon, ...). A `diff` of the two orders is red on a
                # perfectly correct tree, and the obvious "fix" for that is
                # to weaken the check.
                if ! cmp -s headings.sorted names.sorted; then
                  printf 'G6 FAILED: the gallery in docs/src/guide/characters.md and `cl-cowsay --list` disagree.\n' >&2
                  printf '  has a ## heading in characters.md but is NOT in --list:\n' >&2
                  comm -23 headings.sorted names.sorted >&2
                  printf '  is in --list but has NO ## heading in characters.md:\n' >&2
                  comm -13 headings.sorted names.sorted >&2
                  exit 1
                fi
                printf 'G4-G6 ok: %s gallery headings match the %s names\n' "$headings" "$n"

                # ---- G7: anti-vacuity for api.md's hand-written list -------
                # Scoped to the list-characters section: api.md uses the same
                # `"..."` backtick form for the eyes presets and for the
                # default `"oo"`, so a whole-file grep sees 39 names, not 29.
                perl -ne 'if (/^### `list-characters`\s*$/) { $inside = 1; next }
                          if ($inside && /^#{1,3} /) { $inside = 0 }
                          print if $inside' "$api" > api-section.txt
                grep -oE '`"[a-z][a-z0-9-]*"`' api-section.txt | tr -d '`"' > api-names.txt || true
                apiNames=$(grep -c . api-names.txt || true)
                if [ "$apiNames" -lt 1 ]; then
                  printf 'G7 FAILED: zero backtick-quoted names found in the `list-characters` section of docs/src/reference/api.md. Either the section heading changed or the list was reformatted, so G8 below would compare an empty set against itself and pass.\n' >&2
                  exit 1
                fi

                # ---- G7b: no duplicated name in api.md's list --------------
                # Symmetric with G5 over the gallery headings. Without it, a
                # name listed twice in api.md and another one missing cancel
                # out under `sort -u`, and G8 compares two equal sets while the
                # document is wrong in two places at once.
                sort -u api-names.txt > api-names.sorted
                apiDistinct=$(grep -c . api-names.sorted || true)
                if [ "$apiDistinct" -ne "$apiNames" ]; then
                  printf 'G7b FAILED: the `list-characters` section of docs/src/reference/api.md lists %s names but only %s distinct. Duplicated:\n' "$apiNames" "$apiDistinct" >&2
                  sort api-names.txt | uniq -d >&2
                  exit 1
                fi

                # ---- G8: api.md list == --list, as SETS --------------------
                if ! cmp -s api-names.sorted names.sorted; then
                  printf 'G8 FAILED: the hand-written list in docs/src/reference/api.md and `cl-cowsay --list` disagree.\n' >&2
                  printf '  listed in api.md but NOT in --list:\n' >&2
                  comm -23 api-names.sorted names.sorted >&2
                  printf '  is in --list but NOT listed in api.md:\n' >&2
                  comm -13 api-names.sorted names.sorted >&2
                  exit 1
                fi
                printf 'G7-G8 ok: %s names hand-listed in api.md match\n' "$apiNames"

                # ---- G9 / G10: the prose counts ----------------------------
                # NEVER grep for the literal count. Searching for `29` is
                # circular: add a 30th character, update all four documents to
                # `30` and forget the code, and a search for `29` finds
                # nothing and passes vacuously -- exactly backwards. Capture
                # the integer by pattern (G9, which also pins HOW MANY times
                # the pattern must match, so a reworded sentence is a failure
                # and not a silent skip) and compare it to N (G10).
                assertCount() {
                  label="$1"; document="$2"; pattern="$3"; pinned="$4"
                  # Record what was actually checked, for G11. The pinned list
                  # is NOT written out a second time down there: G11 reads this
                  # file, so deleting an assertCount call does not quietly drop
                  # a document from the gate -- it moves that document into
                  # G11's scope, where its count claim is then a failure.
                  printf '%s\n' "''${document#"$documents/"}" >> checked.txt
                  grep -oE "$pattern" "$document" > "matches-$label.txt" || true
                  found=$(grep -c . "matches-$label.txt" || true)
                  if [ "$found" -ne "$pinned" ]; then
                    printf 'G9 FAILED: %s -- the count-extraction pattern /%s/ matched %s time(s), but is pinned at %s. A count claim was reworded, moved, or deleted; this gate is now blind to that file. Update the pattern AND the pinned number together.\n' \
                      "$label" "$pattern" "$found" "$pinned" >&2
                    exit 1
                  fi
                  grep -oE '[0-9]+' "matches-$label.txt" > "ints-$label.txt" || true
                  captured=$(grep -c . "ints-$label.txt" || true)
                  if [ "$captured" -ne "$pinned" ]; then
                    printf 'G9 FAILED: %s -- %s match(es) but %s integer(s) captured from them.\n' "$label" "$pinned" "$captured" >&2
                    exit 1
                  fi
                  while read -r value; do
                    if [ "$value" -ne "$n" ]; then
                      printf 'G10 FAILED: %s claims %s characters; `cl-cowsay --list` reports %s. src/characters-data.lisp is the source of truth.\n' \
                        "$label" "$value" "$n" >&2
                      exit 1
                    fi
                  done < "ints-$label.txt"
                  printf 'G9-G10 ok: %-14s %s match(es), every captured integer == %s\n' "$label" "$pinned" "$n"
                }

                # Pinned counts, determined by reading each document rather
                # than assumed: README.md states the count twice ("**29
                # original," in the lede, "29 built-in characters" in the
                # feature list) and index.md does the same; the other four
                # state it once each. api.md's claim wraps across a line break
                # after the integer, so its pattern anchors on the text BEFORE
                # the number. getting-started.md and examples.md were added
                # when G11 below was written -- getting-started.md matched the
                # README/index pattern already and only ever needed to be in
                # the fileset, while examples.md's "what all 29 look like" was
                # matched by no pattern here at all.
                rm -f checked.txt
                assertCount "README.md"         "$readme"   '[0-9]+ (original|built-in)' 2
                assertCount "index.md"          "$index"    '[0-9]+ (original|built-in)' 2
                assertCount "getting-started.md" "$started" '[0-9]+ (original|built-in)' 1
                assertCount "characters.md"     "$chars"    'All [0-9]+ are original'    1
                assertCount "examples.md"       "$examples" 'all [0-9]+ look like'       1
                assertCount "api.md"            "$api"      'Ships with [0-9]+'          1

                # ---- G11: the pinned list is EXHAUSTIVE --------------------
                # Everything above this point assumes the six documents named
                # in `checked.txt` are the only ones making a character-count
                # claim. That assumption is what failed last time -- the gate
                # covered four of six and was green while two were stale -- and
                # an assumption that has already failed once does not get to
                # stay an assumption. G11 asserts it: any file in this check's
                # fileset that is NOT pinned above and DOES look like it states
                # a count is a failure, whose fix is to pin it.
                #
                # The detector is deliberately broader than the per-document
                # patterns, since its job is to catch a claim nobody has
                # written a pattern for yet. The lookarounds keep it off
                # grouped and fractional numbers -- docs/src/reference/cli.md's
                # "up to 65,536 characters" and "a `--timeout` below `0.001`"
                # are prose about limits, not about how many characters ship,
                # and neither may fire this.
                export COUNT_CLAIM_RE='(?<![0-9,.])[0-9]+(?![0-9,.])\s+(?:original|built-in|characters?\b)|\ball\s+[0-9]+\b|\bShips\s+with\s+[0-9]+'
                countClaimHits() {
                  perl -0777 -ne 'while (/$ENV{COUNT_CLAIM_RE}/gi) { my $m = $&; $m =~ s/\s+/ /g; print "$m\n" }' "$1"
                }

                # G11a -- the detector must not be a pattern that matches
                # nothing. Same discipline as G1, G4 and G7: a typo here would
                # otherwise make G11b pass forever while scanning for a
                # spelling that cannot occur. Every pinned document states a
                # count, so the detector must fire on every one of them.
                while read -r relative; do
                  hits=$(countClaimHits "$documents/$relative" | grep -c . || true)
                  if [ "$hits" -lt 1 ]; then
                    printf 'G11a FAILED: the exhaustiveness detector /%s/ matched nothing in %s, a document pinned above as stating a character count. The detector is broken, so G11b below is scanning for text that cannot occur and would pass over any stale document.\n' \
                      "$COUNT_CLAIM_RE" "$relative" >&2
                    exit 1
                  fi
                done < checked.txt

                # G11b -- and now the assertion the enumeration used to be.
                # Redirected from a file, NOT piped into: `find ... | while`
                # puts the loop in a subshell, where the `exit 1` below would
                # end the subshell and leave the script running with a zero
                # status. A gate that cannot fail is the thing this check is
                # being repaired for; it does not get to reintroduce one.
                find "$documents" -type f | sort > all-documents.txt
                while read -r document; do
                  relative="''${document#"$documents/"}"
                  if grep -qxF "$relative" checked.txt; then
                    continue
                  fi
                  countClaimHits "$document" > "unpinned-hits.txt"
                  if [ -s "unpinned-hits.txt" ]; then
                    printf 'G11b FAILED: %s is in this check fileset, is NOT pinned to a count assertion above, and states what looks like a character count:\n' "$relative" >&2
                    perl -pe 's/^/    /' "unpinned-hits.txt" >&2
                    printf '  Nothing here verifies that number against `cl-cowsay --list`, so it can go stale silently -- which is exactly how getting-started.md and examples.md drifted. Add an assertCount line for it, or reword the claim so it does not read as a count.\n' >&2
                    exit 1
                  fi
                done < all-documents.txt
                printf 'G11 ok: the %s pinned document(s) are the only ones in the fileset stating a count\n' "$(grep -c . checked.txt || true)"

                mkdir -p "$out"
                cp names.txt headings.txt api-names.txt checked.txt "$out/"
                printf 'character count and gallery: G1-G11 held at N=%s\n' "$n" | tee "$out/summary.txt"
              '';
        in
        {
          packages.coverage = coverageReport;

          checks = {
            cli-smoke = cliSmoke;
            coverage = coverageReport;
            library-boundary = libraryBoundary;
            character-docs-drift = characterDocsDrift;
          }
          # Structural parse gate over every Lisp source in the filtered
          # tree: fails if any .lisp/.asd file this build actually ships is
          # not a balanced S-expression document. Skipped on a system
          # paredit-cli itself does not publish (see `devShellPackages`
          # above) rather than failing `nix flake check` evaluation outright.
          // lib.optionalAttrs (paredit-cli.lib ? ${ctx.system}) {
            paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
              inherit (ctx) src;
              name = "cl-cowsay-paredit-lint";
            };
          };
        };
    };
}
