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
      url = "github:nerima-lisp/cl-nix-forge/v0.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.1.4";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Display-width-aware word wrap and padding (cl-tty-kit:wrap-string,
    # cl-tty-kit:pad-string, cl-tty-kit:string-width), used by src/bubble.lisp
    # and src/render.lisp. v1.1.0 is now tagged; the animation work it adds
    # (entity/sprite/tick-loop) is orthogonal to a one-shot renderer like this
    # one, but the word-wrap/pad API this package actually uses is unchanged
    # and covered by cl-tty-kit's own API stability guarantee.
    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative CLI parsing plus --help/--version scaffolding, used by
    # src/cli.lisp -- including its DEFINE-APP macro, which is what
    # *COWSAY-APP* is built with instead of nested MAKE-APP/MAKE-OPTION/
    # MAKE-POSITIONAL calls.
    cl-cli = {
      url = "github:nerima-lisp/cl-cli/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Structural S-expression tooling for src/ and t/: a dev-shell binary for
    # agent-driven refactors (paredit edit/refactor/query/fix) and a
    # structural-parse lint gate reused in `checks.paredit-lint` below.
    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
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
      cl-cli,
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
      lispDependencies =
        ctx: [
          cl-tty-kit.packages.${ctx.system}.cl-tty-kit
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
      # arguments as `packages.cl-cowsay`. Nothing here repeats what
      # cl-cowsay.asd already declares -- `:build-operation "program-op"`,
      # `:build-pathname "cl-cowsay"` and `:entry-point
      # "cl-cowsay/cli::image-entry-point"` live in the system definition, so
      # `(asdf:operate 'asdf:program-op "cl-cowsay")` in a REPL and `nix build`
      # produce the same binary. See cl-weave/flake.nix for the pattern this
      # follows.
      executable = {
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
      devShellPackages = ctx: [
        self.formatter.${ctx.system}
        cl-weave.packages.${ctx.system}.default
        paredit-cli.packages.${ctx.system}.default
      ];

      # Granularity lives here, not in extra GitHub Actions jobs: `nix flake
      # check` evaluates each attribute as its own derivation, with build
      # caching, so a check added here is exactly as parallel as the
      # generated ones.
      extraOutputs =
        ctx:
        let
          # An sb-cover HTML report over the `cl-cowsay` system alone, so
          # `cl-cowsay/test` itself never inflates the numbers. Spelled once,
          # as a function of `ctx`, and used for both `packages.coverage` and
          # `checks.coverage` below, so the two attributes are literally the
          # same derivation rather than two calls that happen to agree (see
          # cl-prolog's flake.nix, the pattern this follows). It asserts its
          # own report is non-empty before installing it, so no separate
          # `test -f cover-index.html` wrapper derivation is needed.
          coverageReport = ctx.cl.mkCoverageReport {
            drv = ctx.package;
            name = "cl-cowsay-coverage";
            systems = [ "cl-cowsay" ];
            timeoutSeconds = 180;
            killAfterSeconds = 30;
          };
        in
        {
          packages.coverage = coverageReport;

          checks = {
            coverage = coverageReport;

            # Structural parse gate over every Lisp source in the filtered
            # tree: fails if any .lisp/.asd file this build actually ships
            # is not a balanced S-expression document.
            paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
              inherit (ctx) src;
              name = "cl-cowsay-paredit-lint";
            };
          };
        };
    };
}
