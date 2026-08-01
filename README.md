# arctic-kernel

Linux 6.12.100 (current kernel.org/Gentoo LTS) with the
[ZEN](https://github.com/zen-kernel/zen-kernel) patchset merged on top —
PDS/BMQ alternate scheduler, PCIe ACS override, inlined futex fast paths,
`ntsync`, `vhba`, assorted scheduler/TCP/cpufreq tuning — plus a small
Arctic-specific tweak on top of that. Four ready-to-use `.config` flavors.
Kernel for [Arctic Linux](https://github.com/apiwo/arctic-linux).

Full provenance of every patch, including the parts of the ZEN merge that
needed hand reconciliation against 83 point releases of upstream drift
(6.12.17 → 6.12.100), is in [`PATCHES.md`](PATCHES.md) — including what
didn't apply cleanly and why, not just what did.

## What's actually in here

```
Default-config/   The real gentoo-kernel-bin .config, reconciled for this tree
Hardened-config/  + mainline exploit mitigations (no signed-module enforcement)
Small-config/     Monolithic, no module loader
RT-config/        CONFIG_PREEMPT_RT, mainline scheduler (not PDS/BMQ)
patches/zen/      The ZEN delta as a standalone patch, for reference
patches/arctic/   Arctic's own patch(es) on top
container/        bwrap sandboxed build script
PATCHES.md        Full provenance + every manual-reconciliation decision
```

Everything else is the kernel source tree itself — this is a real fork,
not a patch dump; `Default-config` builds a working `bzImage` + modules
straight out of this checkout.

## Building

No docker/podman assumed. `container/build.sh` uses
[bubblewrap](https://github.com/containers/bubblewrap) instead: a
throwaway mount namespace with the host toolchain bound read-only, no
network, and the only writable path being the build's own output
directory.

```sh
container/build.sh Default-config/config default bzImage modules
```

First argument is the config file, second is a name for the output
directory (`$ARCTIC_BUILD_ROOT/<name>`, defaults to
`/var/tmp/arctic-kernel-build/<name>`), rest are `make` targets.

Verified end to end this way: `Default-config` does a full `bzImage` +
`modules` build cleanly (4,623 modules). `Hardened`/`Small`/`RT` reconcile
cleanly via `olddefconfig` against the same already-building tree.
`CONFIG_SCHED_ALT` (PDS/BMQ, off by default in all four flavors) was
targeted-compiled separately since it's otherwise never exercised — see
`PATCHES.md` for the two real bugs that surfaced only by actually
building, not by reading the diff.

## Versioning

Tracks Linux's own `6.12.x` LTS releases. `EXTRAVERSION` is `-arctic`;
each config flavor sets its own `CONFIG_LOCALVERSION`
(`-hardened`/`-small`/`-rt`, empty for `Default-config`) so multiple
flavors can coexist in `/lib/modules` and `/boot` on the same system.

## License

GPL-2.0-only, same as upstream Linux — see `COPYING`. Linux itself is
copyright Linus Torvalds and the Linux kernel community; the ZEN
patchset is copyright the zen-kernel project and its contributors.
Arctic Linux's own contribution is the patch in `patches/arctic/`, the
config flavors, and the build tooling around all of it — see
`PATCHES.md` for exactly where every line came from.
