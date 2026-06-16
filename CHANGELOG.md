# Changelog

All notable changes to this project are documented in this file.

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


