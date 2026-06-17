# Changelog

All notable changes to this project are documented in this file.

## [1.0.0] - 2026-06-17


### Bug Fixes

- Address code-review findings (#1-#8)

- Lean changelog dep-group + keep lint green after release

- Harden release version parse, Forgejo release id, and renovate token


### Features

- Make docker/vagrant molecule scenarios optional for both kinds

- Add Renovate dependency automation, replacing Dependabot

- Scaffold example plugins + ansible-test units (include_plugins)

- Add antsibull-changelog release automation (Galaxy + Forgejo)


### Performance

- Validate the static renovate.json once, not per variant


### Refactoring

- Flatten the conditional molecule job separator


### Tests

- Add adversarial free-text self-test variants

- Smoke-test the declared min ansible-core floor (R6)


## [0.3.0] - 2026-06-16


### Bug Fixes

- JSON-escape free-text fields into TOML/YAML

- Gate vagrant Makefile targets on include_vagrant

- Make lint install Galaxy collections first

- Enforce Galaxy name pattern for role/namespace/collection

- Default min_ansible_version to the tested 2.21.0

- Cap min_ansible_version default at ansible-lint-accepted 2.19.0

- Generate from HEAD in self-test and local-debug copies

- JSON-escape free-text fields into TOML/YAML

- Make lint install Galaxy collections first

- Pin molecule dependency versions

- Exclude dev/test artifacts from the built tarball


### Documentation

- Fix Makefile sanity help text


### Features

- Allow pinning Galaxy collection versions


### Tests

- Add update-collection self-test job


## [0.2.0] - 2026-06-16


### Bug Fixes

- Runner label [self-hosted, libvirt] -> [self-hosted, kvm]

- Install dnsmasq-base + iptables explicitly in the vagrant builder

- Relax libvirt container isolation + route destroy through the #301 workaround

- Add --init to reap the qemu zombie on teardown (+ job timeout)

- Reap qemu via a tini subreaper for libvirtd (container.options --init is ignored)

- Drop ineffective container.options --privileged (Forgejo ignores it)


### Documentation

- Finalize vagrant CI + builder-image docs; record one-tag-per-commit convention


### Features

- Update vagrant box default cpus and memory to 1c1g


### Refactoring

- Rely on the image's baked tini + qemu.conf (drop runtime setup)


## [0.1.0] - 2026-06-15


### Documentation

- Add CLAUDE.md guidance for Claude Code

- Collection guide, tasks-split convention, release automation

- Fix builder-image build mechanism, tag format, copier source URL

- Reconcile docs with the Phase 2 mechanism changes


### Features

- Containerize vagrant CI + Forgejo tag-release; pin builder images

- Tag-driven releases for the scaffold and versioned builder images


### Tests

- Cover collections + role release toggle


