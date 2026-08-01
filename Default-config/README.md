# Default-config

The same `.config` `sys-kernel/gentoo-kernel-bin` actually ships, pulled
straight out of the real Gentoo dist-kernel binary package
(`gentoo-kernel-6.12.100-1.amd64.gpkg.tar`, built 2026-07-30) rather than
hand-assembled — the outer gpkg tar's `image.tar.xz` contains
`usr/src/linux-6.12.100-gentoo-dist-bin/.config`, extracted from there
unmodified, then reconciled against this tree with `make olddefconfig`
inside `container/build.sh` so the new ZEN/Arctic Kconfig symbols
(`CONFIG_ZEN_INTERACTIVE`, `CONFIG_SCHED_ALT`, `CONFIG_NTSYNC`,
`CONFIG_VHBA`, ...) get sane values instead of being silently dropped.

Broad hardware support, matches upstream Gentoo's own defaults, this is
what you want unless one of the other flavors' tradeoffs specifically
applies to you. `NTSYNC` and `VHBA` are explicitly enabled as modules
(off in stock Gentoo) since they're part of what the ZEN merge adds.
