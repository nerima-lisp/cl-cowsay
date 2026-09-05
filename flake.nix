{
  description = "cl-cowsay: a one-shot ASCII-art talking-animal message tool for SBCL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-codec-kit = {
      url = "github:nerima-lisp/cl-codec-kit/v0.5.0";
      flake = false;
    };

    cl-cli = {
      url = "github:nerima-lisp/cl-cli/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-host-kit.follows = "cl-host-kit";
    };

    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    cl-nix-forge.lib.${builtins.head systems}.mkPackageFlake {
      inherit
        self
        systems
        nixpkgs
        meta
        ;
      pname = "cl-cowsay";

      asd = ./cl-cowsay.asd;

      root = ./.;

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

      lispCheckDependencies = ctx: [ cl-weave.packages.${ctx.system}.cl-weave ];

      timeoutSeconds = 120;
      killAfterSeconds = 30;

      executable = {
        lispSystem = "cl-cowsay/cli";
        programPath = "src/cl-cowsay";
        dynamicSpaceSize = 1024;
        installSource = true;
      };

      docs.root = ./docs;

      treefmt.evalModule = treefmt-nix.lib.evalModule;

      devShellPackages =
        ctx:
        [
          self.formatter.${ctx.system}
          cl-weave.packages.${ctx.system}.default
        ]
        ++ lib.optional (paredit-cli.packages ? ${ctx.system}) paredit-cli.packages.${ctx.system}.default;

      extraOutputs =
        ctx:
        let
          packaged-cli = lib.getExe ctx.executable;

          cliSmoke = ctx.cl.mkCommandCheck {
            drv = ctx.package;
            name = "cl-cowsay-cli-smoke";
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

          coverageReport = ctx.cl.mkCoverageReport {
            drv = ctx.package;
            name = "cl-cowsay-coverage";
            systems = [
              "cl-cowsay"
              "cl-cowsay/cli"
            ];
            entryPointText = ''
              (asdf:load-system "cl-cowsay/test")
              (funcall
                (symbol-function
                  (find-symbol "RUN-TESTS" "CL-COWSAY/TEST"))
                :coverage t)
            '';
            timeoutSeconds = 600;
            killAfterSeconds = 30;
          };

          libraryBoundary = ctx.cl.mkScriptCheck {
            drv = ctx.package;
            name = "cl-cowsay-library-boundary";
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
                "Return the system name in a wrapped dependency, or NIL."
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
                "True when DEPENDENCIES names NAME, case-insensitively."
                (some (lambda (dependency)
                        (let ((dependency-name (boundary-dependency-name dependency)))
                          (and dependency-name (string-equal name dependency-name))))
                      dependencies))

              (defun boundary-homed-symbols (package-name home-name)
                "Return symbols in PACKAGE-NAME whose home is HOME-NAME."
                (let ((package (find-package package-name))
                      (home (find-package home-name))
                      (found nil))
                  (unless package
                    (error "FAILED: package ~S was not found."
                           package-name))
                  (unless home
                    (error "FAILED: home package ~S was not found."
                           home-name))
                  (do-symbols (symbol package)
                    (when (eq (symbol-package symbol) home)
                      (pushnew symbol found)))
                  found))

              (defun boundary-component-files (system-name)
                "Return the pathnames of SYSTEM-NAME's own source files."
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
                "Return needles occurring in PATH, case-insensitively."
                (let ((text (with-open-file (in path :external-format :utf-8)
                              (let ((buffer (make-string (file-length in))))
                                (subseq buffer 0 (read-sequence buffer in))))))
                  (remove-if-not (lambda (needle) (search needle text :test #'char-equal))
                                 needles)))

              (let ((library-system "cl-cowsay")
                    (cli-system "cl-cowsay/cli")
                    (tty-kit-system "cl-tty-kit")
                    (host-kit-system "cl-host-kit")
                    (cl-cli-system "cl-cli")
                    (library-package "CL-COWSAY")
                    (cli-package "CL-COWSAY/CLI")
                    (host-kit-package "HOST-KIT")
                    (cl-cli-package "CL-CLI")
                    (boundary-needles (list "host-kit" "cl-cli")))

              (asdf:load-system library-system)

              (unless (find-package library-package)
                (error "P1 FAILED: no package ~A after (asdf:load-system ~S)."
                       library-package library-system))

              (multiple-value-bind (symbol status) (find-symbol "WRITE-SAY" library-package)
                (unless (eq status :external)
                  (error "P2 FAILED: WRITE-SAY in ~A has status ~S, not :EXTERNAL (symbol ~S)."
                         library-package status symbol))
                (unless (fboundp symbol)
                  (error "P3 FAILED: CL-COWSAY:WRITE-SAY is exported but unbound.")))

              (let ((dependencies (boundary-dependencies library-system)))
                (unless dependencies
                  (error "P4 FAILED: system ~A has an empty :depends-on (expected ~A)."
                         library-system tty-kit-system))
                (unless (boundary-names-p dependencies tty-kit-system)
                  (error "P4 FAILED: system ~A :depends-on ~S does not contain ~A."
                         library-system dependencies tty-kit-system))

                (when (boundary-names-p dependencies host-kit-system)
                  (error "N2a FAILED: system ~A :depends-on ~S names forbidden dependency ~A (expected only in ~A)."
                         library-system dependencies host-kit-system cli-system))
                (when (boundary-names-p dependencies cl-cli-system)
                  (error "N1a FAILED: system ~A :depends-on ~S names forbidden dependency ~A (expected only in ~A)."
                         library-system dependencies cl-cli-system cli-system)))

              (when (find-package cl-cli-package)
                (error "N1 FAILED: package ~A exists after loading only library system ~A (expected only in ~A)."
                       cl-cli-package library-package cli-system))

              (unless (find-package host-kit-package)
                (error "P4b FAILED: package ~A is absent after loading library system ~A."
                       host-kit-package library-package))

              (let ((leaked (boundary-homed-symbols library-package host-kit-package)))
                (when leaked
                  (error "N2b FAILED: ~S symbol(s) homed in ~A are accessible in package ~A: ~S (expected only in ~A)."
                         (length leaked) host-kit-package library-package leaked cli-system)))

              (let ((library-files (boundary-component-files library-system))
                    (offenders nil))
                (unless library-files
                  (error "N2c FAILED: system ~A has no component source files."
                         library-system library-system))
                (dolist (path library-files)
                  (let ((hits (boundary-file-mentions path boundary-needles)))
                    (when hits (push (list path hits) offenders))))
                (when offenders
                  (error "N2c FAILED: ~S file(s) in system ~A mention boundary token(s) ~S: ~S."
                         (length offenders) library-system boundary-needles
                         (nreverse offenders) cli-system)))

              (let* ((cli-files (boundary-component-files cli-system))
                     (package-file (find "cli-package" cli-files
                                         :key #'pathname-name
                                         :test #'string-equal)))
                (unless package-file
                  (error "P4c FAILED: system ~A has no cli-package component; files: ~S."
                         cli-system cli-files))
                (let ((found (boundary-file-mentions package-file boundary-needles)))
                  (unless (= (length found) (length boundary-needles))
                    (error "P4c FAILED: found ~S of ~S boundary tokens ~S in ~A: ~S (expected ~S)."
                           (length found) (length boundary-needles) boundary-needles
                           package-file found boundary-needles))))

              (asdf:load-system cli-system)

              (unless (find-package cl-cli-package)
                (error "P5 FAILED: package ~A is absent after loading system ~A."
                       cl-cli-package cli-system))

              (let ((dependencies (boundary-dependencies cli-system)))
                (unless (boundary-names-p dependencies cl-cli-system)
                  (error "P6 FAILED: system ~A :depends-on ~S does not name ~A."
                         cli-system dependencies cl-cli-system))
                (unless (boundary-names-p dependencies host-kit-system)
                  (error "P6 FAILED: system ~A :depends-on ~S does not name ~A."
                         cli-system dependencies host-kit-system)))

              (let ((imported (boundary-homed-symbols cli-package host-kit-package)))
                (unless imported
                  (error "P7 FAILED: no ~A-homed symbol is accessible in ~A."
                         host-kit-package cli-package)))

              (format t "~&library boundary: P1-P4, P4b, P4c, P5-P7, N1, N1a, N2a, N2b and N2c all held.~%"))
            '';
          };

          characterDocsDrift =
            let
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
                nativeBuildInputs = [ ctx.pkgs.perl ];
              }
              ''
                set -euo pipefail
                export LC_ALL=C

                readme="$documents/README.md"
                index="$documents/docs/src/index.md"
                started="$documents/docs/src/getting-started.md"
                chars="$documents/docs/src/guide/characters.md"
                examples="$documents/docs/src/guide/examples.md"
                api="$documents/docs/src/reference/api.md"

                for document in "$readme" "$index" "$started" "$chars" "$examples" "$api"; do
                  if [ ! -f "$document" ]; then
                    printf 'FAILED: expected document is not in this check fileset: %s\n' "$document" >&2
                    exit 1
                  fi
                done

                ${lib.escapeShellArg packaged-cli} --list > names.txt
                if [ ! -s names.txt ]; then
                  printf 'G1 FAILED: `cl-cowsay --list` produced no output.\n' >&2
                  exit 1
                fi

                n=$(grep -c . names.txt || true)
                if [ "$n" -lt 1 ]; then
                  printf 'G2 FAILED: `cl-cowsay --list` yielded %s names; expected at least 1.\n' "$n" >&2
                  exit 1
                fi

                sort -u names.txt > names.sorted
                distinct=$(grep -c . names.sorted || true)
                if [ "$distinct" -ne "$n" ]; then
                  printf 'G3 FAILED: --list emitted %s names but only %s are distinct. Two defcharacter forms in src/characters-data.lisp share a name:\n' "$n" "$distinct" >&2
                  sort names.txt | uniq -d >&2
                  exit 1
                fi
                printf 'G1-G3 ok: --list is the authority, N=%s distinct names\n' "$n"

                grep -oE '^## [a-z][a-z0-9-]*$' "$chars" | cut -c4- > headings.txt || true
                headings=$(grep -c . headings.txt || true)
                if [ "$headings" -lt 1 ]; then
                  printf 'G4 FAILED: no character headings matched ^## [a-z][a-z0-9-]*$.\n' >&2
                  exit 1
                fi

                sort -u headings.txt > headings.sorted
                headingsDistinct=$(grep -c . headings.sorted || true)
                if [ "$headingsDistinct" -ne "$headings" ]; then
                  printf 'G5 FAILED: characters.md has %s character headings but only %s distinct. Duplicated:\n' "$headings" "$headingsDistinct" >&2
                  sort headings.txt | uniq -d >&2
                  exit 1
                fi

                if ! cmp -s headings.sorted names.sorted; then
                  printf 'G6 FAILED: the gallery in docs/src/guide/characters.md and `cl-cowsay --list` disagree.\n' >&2
                  printf '  has a ## heading in characters.md but is NOT in --list:\n' >&2
                  comm -23 headings.sorted names.sorted >&2
                  printf '  is in --list but has NO ## heading in characters.md:\n' >&2
                  comm -13 headings.sorted names.sorted >&2
                  exit 1
                fi
                printf 'G4-G6 ok: %s gallery headings match the %s names\n' "$headings" "$n"

                perl -ne 'if (/^### `list-characters`\s*$/) { $inside = 1; next }
                          if ($inside && /^#{1,3} /) { $inside = 0 }
                          print if $inside' "$api" > api-section.txt
                grep -oE '`"[a-z][a-z0-9-]*"`' api-section.txt | tr -d '`"' > api-names.txt || true
                apiNames=$(grep -c . api-names.txt || true)
                if [ "$apiNames" -lt 1 ]; then
                  printf 'G7 FAILED: no character names found in the list-characters API section.\n' >&2
                  exit 1
                fi

                sort -u api-names.txt > api-names.sorted
                apiDistinct=$(grep -c . api-names.sorted || true)
                if [ "$apiDistinct" -ne "$apiNames" ]; then
                  printf 'G7b FAILED: the `list-characters` section of docs/src/reference/api.md lists %s names but only %s distinct. Duplicated:\n' "$apiNames" "$apiDistinct" >&2
                  sort api-names.txt | uniq -d >&2
                  exit 1
                fi

                if ! cmp -s api-names.sorted names.sorted; then
                  printf 'G8 FAILED: the hand-written list in docs/src/reference/api.md and `cl-cowsay --list` disagree.\n' >&2
                  printf '  listed in api.md but NOT in --list:\n' >&2
                  comm -23 api-names.sorted names.sorted >&2
                  printf '  is in --list but NOT listed in api.md:\n' >&2
                  comm -13 api-names.sorted names.sorted >&2
                  exit 1
                fi
                printf 'G7-G8 ok: %s names hand-listed in api.md match\n' "$apiNames"

                assertCount() {
                  label="$1"; document="$2"; pattern="$3"; pinned="$4"
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

                rm -f checked.txt
                assertCount "README.md"         "$readme"   '[0-9]+ (original|built-in)' 2
                assertCount "index.md"          "$index"    '[0-9]+ (original|built-in)' 2
                assertCount "getting-started.md" "$started" '[0-9]+ (original|built-in)' 1
                assertCount "characters.md"     "$chars"    'All [0-9]+ are original'    1
                assertCount "examples.md"       "$examples" 'all [0-9]+ look like'       1
                assertCount "api.md"            "$api"      'Ships with [0-9]+'          1

                export COUNT_CLAIM_RE='(?<![0-9,.])[0-9]+(?![0-9,.])\s+(?:original|built-in|characters?\b)|\ball\s+[0-9]+\b|\bShips\s+with\s+[0-9]+'
                countClaimHits() {
                  perl -0777 -ne 'while (/$ENV{COUNT_CLAIM_RE}/gi) { my $m = $&; $m =~ s/\s+/ /g; print "$m\n" }' "$1"
                }

                while read -r relative; do
                  hits=$(countClaimHits "$documents/$relative" | grep -c . || true)
                  if [ "$hits" -lt 1 ]; then
                    printf 'G11a FAILED: /%s/ matched no count claim in %s.\n' \
                      "$COUNT_CLAIM_RE" "$relative" >&2
                    exit 1
                  fi
                done < checked.txt

                find "$documents" -type f | sort > all-documents.txt
                while read -r document; do
                  relative="''${document#"$documents/"}"
                  if grep -qxF "$relative" checked.txt; then
                    continue
                  fi
                  countClaimHits "$document" > "unpinned-hits.txt"
                  if [ -s "unpinned-hits.txt" ]; then
                    printf 'G11b FAILED: %s states a character count but has no count assertion:\n' "$relative" >&2
                    perl -pe 's/^/    /' "unpinned-hits.txt" >&2
                    printf '  Add an assertCount line or reword the claim.\n' >&2
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
          // lib.optionalAttrs (paredit-cli.lib ? ${ctx.system}) {
            paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
              inherit (ctx) src;
              name = "cl-cowsay-paredit-lint";
            };
          };
        };
    };
}
