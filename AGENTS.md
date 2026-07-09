# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-svckill` is a SIMP Puppet module that enforces the security best practice
that **"no unnecessary services should be running on the system."** It is a
service *reaper*: it enumerates every service the system knows about and stops +
disables any that are **not** declared in the Puppet catalog and **not** on an
explicit ignore list (`manifests/init.pp`,
`lib/puppet/type/svckill.rb`).

The reaping is done by a **custom native type + provider** (`svckill`), not by
Puppet manifest logic — the manifests only assemble the ignore list and declare
a single `svckill { 'svckill': }` resource. The heart of this module is
therefore in `lib/`, not `manifests/`.

The module ships **`warning` mode by default** (`init.pp`,
`lib/puppet/type/svckill.rb`): out of the box it only *reports* which
services it *would* stop/disable, and makes no changes. You must explicitly set
`svckill::mode: enforcing` for it to actually kill anything — a deliberate
safety default, since mis-configured, this type can shut down critical services.

## Business logic

Three manifests (`init`, `ignore`, `ignore::collector`) plus one native
type/provider pair. There are **no** `assert_private()` calls anywhere.

### `svckill` — public entry class (`manifests/init.pp`)

Parameters (`init.pp`):

- `$enable` (`Boolean`, default `true`) — master switch. When `false`, the class
  declares nothing at all (`init.pp`).
- `$ignore` (`Array[String]`, default `[]`) — services to never kill; may
  contain knockout entries (`--name`) to remove a service from the defaults.
- `$ignore_defaults` (`Array[String]`, default `[]` in the manifest) — the
  built-in ignore list, **supplied from module data** (see below), merged
  `unique` across the hierarchy.
- `$ignore_files` (`Array[Stdlib::Absolutepath]`, default `[]`) — extra files
  listing services to ignore, one per line.
- `$mode` (`Enum['enforcing','warning']`, default `'warning'`).
- `$verbose` (`Boolean`, default `true`).

When `$enable` (`init.pp`):

- `include '::svckill::ignore::collector'` — builds the managed ignore file.
- `$combined_ignore_list = $ignore + $ignore_defaults` (`init.pp`), then
  passed through **`simplib::knockout(...)`** (`init.pp`) which resolves the
  `--` knockout prefixes so a consumer can subtract a service (e.g. `--sshd`)
  from the defaults.
- `$flattened_ignore_files` = the caller's `$ignore_files` plus the
  collector's managed `default_ignore_file` (`init.pp`).
- Declares the one `svckill { 'svckill': }` resource, wiring `ignore`,
  `ignorefiles`, `verbose`, and `mode`, and `require`-ing the collector class
  (`init.pp`).

### `svckill::ignore` — define (`manifests/ignore.pp`)

`svckill::ignore { 'sshd': }` marks a single service as never-kill. It
`include`s the collector and uses `ensure_resource('concat::fragment', ...)` to
append `$name` as a fragment to the collector's `concat` file
(`ignore.pp`). This is the **collection mechanism**: any number of
`svckill::ignore` declarations, anywhere in the catalog, aggregate their names
into one on-disk ignore file via `concat` fragments — the provider then reads
that file at runtime.

### `svckill::ignore::collector` — class (`manifests/ignore/collector.pp`)

Owns the `concat { $default_ignore_file: }` container
(`/usr/local/etc/svckill.ignore`, `mode 0600`, `ensure_newline => true`,
`warn => true`) that the `svckill::ignore` fragments target
(`collector.pp`). `$default_ignore_file` is the single source of truth for
the ignore-file path and is referenced by both `init.pp` and `ignore.pp`.

### `svckill` native type (`lib/puppet/type/svckill.rb`)

- `:name` is fixed to the literal string `'svckill'` — declaring a second one is
  an error (`type/svckill.rb`); it is a singleton per node scope.
- `:ignore` — array of service names/regexes to never kill (`:27-31`).
- `:ignorefiles` — files of ignore entries; defaults to
  `/usr/local/etc/svckill.ignore` (`:33-40`).
- `:verbose` (boolean, default `:true`) — full per-service output vs. counts
  (`:42-49`).
- `:mode` — the **only property** (`newproperty`, `:51-117`); values
  `enforcing` / `warning`, default `warning` (`:62-68`). Its
  `change_to_s` renders the human-readable stop/disable report from
  `provider.results` (`:74-116`), and `insync?` delegates to the provider
  (`:70-72`).
- **Autorequires** the `ignorefiles` path as both a `file` and a `simpcat_build`
  resource (`:119-125`) so the ignore file is built before reaping runs.

### `kill` provider (`lib/puppet/provider/svckill/kill.rb`)

The actual reaper.

- **`initialize`** (`:6-44`) builds a systemd alias lookup table via
  `systemctl list-unit-files` + `systemctl show -p Names`, skipping `static`
  and templated (`@`) units, so that a service reached via an *alias* in the
  catalog is not killed under its canonical name (`:9-43`).
- **`mode` (getter, `:46-168`)** does the work of deciding what to kill:
  1. Collects every `service` resource name from the catalog (`:47-49`) — these
     are the "declared / keep" set.
  2. Merges `@resource[:ignore]` and every readable `:ignorefiles` line
     (stripping `#` comments) into one `ignore` list (`:52-76`).
  3. Iterates `Puppet::Type.type('service').instances` (all services on the
     box) and **skips** anything that is: an RPM leftover
     (`.rpmsave`/`.rpmnew`, RedHat only, `:86-92`); matched by an ignore entry
     (treated as an anchored regex `^entry$`, `:96-99`); present in the catalog
     by either name form (`:103-106`); or reachable via a catalog-declared
     systemd alias (`:110-121`).
  4. Whatever survives and is *running* or *enabled* is added to
     `@running_services` (`:129-166`), with special handling per provider
     (`upstart` vs `redhat`/`systemd`); systemd services are only targeted when
     their cached enabled state is exactly `enabled` or `disabled` (`:145-153`)
     — killing units in other states can cause system errors.
- **`insync?` (`:170-182`)** — in `noop` OR `warning` mode it logs a
  `Puppet.warning` listing what it *would* have killed and returns `true`
  (never changes anything). In `enforcing` mode it is in sync only when nothing
  is left to kill.
- **`mode=` (setter, `:184-230`)** — the enforcing action: for each survivor,
  `stop` it if running and `disable` it if enabled, recording pass/fail into
  `@results` (which feeds the type's `change_to_s` report).

## Gotchas / non-obvious details

- **`warning` is the default mode — svckill kills nothing until you set
  `enforcing`.** In `warning` (or `--noop`), `insync?` always returns `true`
  after logging what it *would* do (`kill.rb`). Do not assume applying
  this module reaps services; it doesn't unless `svckill::mode: enforcing`.
- **This module has NO `simp_options` seam.** Unlike most SIMP modules, it makes
  **no** `simplib::lookup('simp_options::*', ...)` calls — it consumes nothing
  from `simp_options`. The only `simplib` function it uses in a manifest is
  `simplib::knockout` (`init.pp`). This is a genuine special case; don't add
  a `simp_options` lookup expecting parity with other modules.
- **Ignore entries are anchored regexes, not literals.** The provider matches
  each ignore entry as `Regexp.new("^#{x}$")` (`kill.rb`). The default data
  relies on this (e.g. `^pe-.*`, `^rhsm*`, `^autovt@.*`). A bare name like
  `sshd` still works because it anchors to the whole service name.
- **The ignore file is regex-capable and comment-aware.** Lines beginning with
  `#` in an `ignorefiles` file are dropped (`kill.rb`); other lines are
  matched as regexes too.
- **`svckill::ignore` requires the concat plumbing.** It writes `concat`
  fragments into the collector's file; that is the only supported way to add a
  single ignore entry declaratively. The type's `simpcat_build` autorequire
  (`type/svckill.rb`) sequences the build before the reap.
- **The type is a hard singleton.** `:name` must equal `'svckill'`
  (`type/svckill.rb`); you cannot declare two `svckill` resources.
- **`ignore_defaults` comes from Hiera, not the manifest.** The manifest default
  is `[]` (`init.pp`); the real defaults live in `data/*.yaml` under
  `svckill::ignore_defaults` with `merge: unique` (`data/common.yaml`), so
  OS-family and OS files *add to* rather than replace the common list. Override
  via Hiera, using the `--` knockout prefix to subtract an entry
  (`init.pp`).
- **systemd aliases and RPM leftovers are deliberately spared** (`kill.rb`,
  `:108-121`) — behavior that is easy to regress if the skip logic is edited.
- **Acceptance tests exist on disk but are NOT run in CI** (see CI subsection).

## Dependencies

Module dependencies (from `metadata.json`):

- `puppetlabs/concat` `>= 6.4.0 < 10.0.0` — provides the `concat` /
  `concat::fragment` (and the `simpcat_build` autorequire target) used to build
  the ignore file.
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0`.
- `simp/simplib` `>= 4.9.0 < 5.0.0` — provides `simplib::knockout`
  (`init.pp`).

There are **no optional dependencies** (no `simp.optional_dependencies` in
`metadata.json`) and **no `simplib::assert_optional_dependency` calls** in the
code.

Fixture-only repositories (from `.fixtures.yml`, checked out for test
compilation, not runtime deps): `concat`, `simplib`, `stdlib` (all from the
`simp/` GitHub mirrors).

Runtime requirement (from `metadata.json`): `puppet >= 7.0.0 < 9.0.0`.
This is the **older Puppet 7/8 baseline** — this module has **not** yet been
migrated to OpenVox. When `metadata.json` switches this to `openvox`, update
this line to match.

Supported OS matrix (from `metadata.json`): CentOS 7/8/9; RedHat 7/8/9;
OracleLinux 7/8/9; Rocky 8/9; AlmaLinux 8/9.

## Repository layout

- `lib/puppet/type/svckill.rb` — the `svckill` native type (params + the `mode`
  property; **the module's public interface at the resource level**).
- `lib/puppet/provider/svckill/kill.rb` — the `kill` provider; **the reaper
  logic lives here.**
- `manifests/init.pp` — the `svckill` class: assembles the ignore list and
  declares the single `svckill` resource.
- `manifests/ignore.pp` — the `svckill::ignore` define: adds one service to the
  ignore file via a `concat::fragment`.
- `manifests/ignore/collector.pp` — the `svckill::ignore::collector` class: owns
  the `concat` container for the ignore file.
- `data/common.yaml` — base `svckill::ignore_defaults` (+ its `merge: unique`
  `lookup_options`).
- `data/os/RedHat.yaml`, `data/osfamily/RedHat.yaml`,
  `data/osfamily/RedHat/RedHat-{7,8,9}.yaml`, `data/virtual/{kvm,vmware}.yaml` —
  additive OS/family/virtual overrides to `svckill::ignore_defaults`.
- `hiera.yaml` — v5 hierarchy: OS-family+release → OS-family → OS → virtual →
  common (`hiera.yaml`).
- `metadata.json` — deps, OS matrix, Puppet requirement.
- `spec/classes/init_spec.rb`, `spec/defines/ignore_spec.rb` — rspec-puppet unit
  tests.
- `spec/acceptance/suites/default/{00_default,01_symlinked_services}_spec.rb`,
  `spec/acceptance/nodesets/{default,oel}.yml` — beaker acceptance suite +
  nodesets (present but **not wired into CI**; see below).
- `REFERENCE.md` — generated Puppet Strings reference.
- No `types/`, no `functions/`, no `templates/` — the only custom code is the
  native type/provider under `lib/`.

### CI (`.github/workflows/pr_tests.yml`)

Triggered on pull requests. Uses an **older workflow style** with a global
`env: PUPPET_VERSION: '~> 7'` (`pr_tests.yml`) and Ruby 2.7.8 for the
lint/check jobs. Six jobs, **no acceptance job**:

1. `puppet-syntax` — `rake syntax`.
2. `puppet-style` — `rake lint` + `rake metadata_lint`.
3. `ruby-style` — `rake rubocop` (`continue-on-error: true`).
4. `file-checks` — `rake check:dot_underscore` + `rake check:test_file`.
5. `releng-checks` — `pkg:check_version`, `pkg:compare_latest_tag`,
   `pkg:create_tag_changelog`, and `pdk build --force`.
6. `spec-tests` — `rake spec` across a Puppet 7.x (Ruby 2.7) and Puppet 8.x
   (Ruby 3.2) matrix (`pr_tests.yml`).

**GOTCHA: CI does not run the acceptance suites.** The beaker suites and
nodesets under `spec/acceptance/` exist on disk but are **not** referenced by
`pr_tests.yml` — there is no `acceptance`/beaker job. Changes to the provider's
real-system behavior are only covered by unit specs in CI; run acceptance
locally if you touch the kill logic.

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run a single spec
bundle exec rspec spec/classes/init_spec.rb
bundle exec rspec spec/defines/ignore_spec.rb

# Puppet lint + metadata lint (matches CI puppet-style)
bundle exec rake lint
bundle exec rake metadata_lint

# Puppet syntax (matches CI puppet-syntax)
bundle exec rake syntax

# Ruby lint (the type/provider live in lib/)
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
puppet strings generate --format markdown --out REFERENCE.md

# Acceptance suite (NOT run in CI — run locally against a VM)
bundle exec rake beaker:suites[default]
```

Relevant gem pins: `rubocop ~> 1.88.0` (`Gemfile`),
`puppetlabs_spec_helper ~> 8.0.0` (`Gemfile`),
`simp-rake-helpers ~> 5.24.0` (`Gemfile`),
`simp-beaker-helpers ~> 2.0.0` (`Gemfile`). The test Puppet range defaults to
`>= 7 < 9` (`Gemfile`); the Puppet gem is pulled in only via
`gem 'puppet', puppet_version` (`Gemfile`). `spec/spec_helper.rb` requires
`puppetlabs_spec_helper/module_spec_helper` (`spec_helper.rb`).

## Conventions

- **Reaping logic belongs in the provider, not the manifests.** Keep
  `manifests/` limited to assembling the ignore list and declaring the single
  `svckill` resource; put service-decision logic in
  `lib/puppet/provider/svckill/kill.rb`.
- **Default to safety: `warning` mode.** Preserve `warning` as the default for
  both the class and the type; `enforcing` must be an explicit opt-in.
- **Add default ignores via module data, not the manifest.** Put new never-kill
  entries in the appropriate `data/*.yaml` under `svckill::ignore_defaults`
  (which merges `unique`), and remember entries are matched as anchored regexes.
- **Do not introduce a `simp_options` lookup.** This module intentionally has no
  `simp_options` seam; adding one would change its contract.
- **Preserve the systemd-alias and RPM-leftover skip logic** in the provider —
  it exists to avoid killing services reachable under a different name.
- Preserve the `@summary` / `@param` puppet-strings docstrings on the manifests
  and the `@doc`/`desc` strings on the type/provider — they drive `REFERENCE.md`.
  Regenerate `REFERENCE.md` after changing docs or parameters.
- `Gemfile`, `spec/spec_helper.rb`, `.pdkignore`, and
  `.github/workflows/pr_tests.yml` carry a **puppetsync** notice — they are
  baseline-managed and the next sync overwrites local edits. Push changes to
  those files upstream to the baseline, not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter
  style used in the manifests.
