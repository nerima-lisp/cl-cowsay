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
      # paredit-cli v1.5.0 declares only x86_64-linux -- "only what a gate
      # verifies," by its own flake.nix, and aarch64-darwin carries no CI gate
      # here either. `lib.optional` on a `?` membership test drops it from
      # the aarch64-darwin dev shell instead of failing evaluation with
      # `attribute 'aarch64-darwin' missing`, the same shape of gap
      # cl-tty-kit's `:depends-on ("cl-codec-kit")` hit before it (see the
      # `cl-codec-kit` input above).
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
            timeoutSeconds = 30;
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
              ''
            ];
            artifacts = [
              "version.txt"
              "help.txt"
              "output.txt"
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
        in
        {
          packages.coverage = coverageReport;

          checks = {
            cli-smoke = cliSmoke;
            coverage = coverageReport;
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
