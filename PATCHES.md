# Patch provenance

arctic-kernel is Linux 6.12.100 (the current kernel.org/Gentoo LTS point
release) with the ZEN Interactive patchset merged on top, plus a small set
of additional tuning patches curated by Arctic Linux. This file documents
where every layer came from, exactly what didn't apply cleanly, and why.

## Layer 1: vanilla 6.12.100

`linux-6.12.tar.xz` + `patch-6.12.100.xz` from cdn.kernel.org, applied with
zero modifications. Same base tarball + incremental patch pair that
Gentoo's own `gentoo-kernel-bin` ebuild fetches.

## Layer 2: ZEN patchset (`patches/zen/0001-zen-sauce-6.12-at-v6.12.17.patch`)

Source: [zen-kernel/zen-kernel](https://github.com/zen-kernel/zen-kernel),
branch `6.12/main`.

zen-kernel's per-version branch layout is not what it looks like at first
glance: `6.12/zen-sauce` is a *frozen* branch (last commit 2024-12-14,
kernel 6.12.17) that predates a workflow change. `6.12/main` is the branch
that actually stays current — it already contains the zen-sauce patches
merged in, plus continuing upstream stable merges (confirmed: `6.12/main`'s
merge-base with `zen-sauce` *is* zen-sauce's own tip commit, i.e. zen-sauce
is wholly an ancestor of main). Same story for the `6.12/bbr3` branch —
its commits are also already ancestors of `main`. So `6.12/main` alone is
"upstream 6.12 + zen sauce + BBR3", frozen at v6.12.17.

The patch here is `diff -rNu` between vanilla v6.12.17 and that `6.12/main`
snapshot — i.e. the pure ZEN delta, isolated from the point-release noise
between .17 and .100. That patch was then applied to our 6.12.100 base.

Adds, notably:
- `CONFIG_SCHED_ALT`: Con Kolivas' PDS/BMQ alternate CPU scheduler
  (`kernel/sched/alt_*.c`, `bmq.h`, `pds.h`) as a swap-in replacement for
  CFS/EEVDF.
- `CONFIG_ZEN_INTERACTIVE`: lower `sysctl_sched_base_slice` (400us) and
  `sysctl_sched_migration_cost` (250us) for desktop responsiveness.
- PCIe ACS override (`pcie_acs_override=` boot param) — common for VFIO
  GPU-passthrough setups.
- Inlined futex fast paths (`futex_cmpxchg_value_locked`,
  `futex_get_value_locked`) using `masked_user_access_begin()`.
- `vhba` virtual SCSI HBA driver, `intel-nvme-remap`, `ntsync` (Wine sync
  primitives), assorted TCP/cpufreq/mm sysctl default tweaks.

### Hunks that needed manual reconciliation (9 of 185 files)

83 point releases (.17 → .100) is enough upstream churn that a few hunks
had drifted. Handled individually rather than force-applied:

| File | What happened |
|---|---|
| `Makefile` | Context-only mismatch (`SUBLEVEL` line). Applied the real change (EXTRAVERSION, drop `-fconserve-stack`) by hand. |
| `arch/arm64/tools/syscall_64.tbl` | No-op — upstream had *already* added the exact `process_ksm_*` syscalls zen's hunk wanted to add, between .17 and .100. |
| `drivers/pci/quirks.c` | Pure addition (the ACS override function), rejected only because upstream inserted an unrelated NVIDIA quirk right at the insertion point. Spliced in beside it. |
| `kernel/futex/futex.h` | Context drift only. Verified `masked_user_access_begin()` exists in this tree before applying — it does. |
| `kernel/sched/sched.h` | Context drift (upstream added a new `#include` ahead of the insertion point). Applied by hand. |
| `kernel/sched/cpufreq_schedutil.c` | Upstream had already changed the guarded line to `WRITE_ONCE(...)` (a real data-race fix) between .17 and .100. Kept upstream's fixed form, just added zen's `#ifndef CONFIG_SCHED_ALT` guard around it. |
| `kernel/sched/fair.c` | Upstream had already changed the non-interactive default from 750000 to 700000ULL between .17 and .100. Kept upstream's new default for the `#else` branch; used zen's 400000/250000 values for the `CONFIG_ZEN_INTERACTIVE` branch. |
| `net/ipv4/tcp_input.c` | One of two call sites to `tcp_process_tlp_ack()` was missing the 4th argument that an already-applied hunk had added to the function signature — this one wasn't optional, the tree wouldn't compile without it. Added the argument. |
| `arch/x86/mm/tlb.c` | **Reverted entirely, plus dependent files.** This one turned out bigger than "9 of 185 files": zen's `6.12/main` backports AMD's INVLPGB broadcast-TLB-flush ("global ASID") subsystem — real, legitimate, upstream-bound work, just not something that belongs in this base yet. The `tlb.c` hunk that failed to apply was two interdependent chunks (a `goto reload_tlb;` added by an *earlier, cleanly-applied* hunk, paired with the `reload_tlb:` label itself, which was in the chunk that failed). Initially I dropped only the failing chunk, which left a `goto` with no matching label — caught this at actual compile time (`error: label 'reload_tlb' used but not defined`), not by inspection. Rather than hand-complete a CPU/TLB-security-sensitive feature I can't fully verify or test on real INVLPGB-capable hardware, `arch/x86/mm/tlb.c` was restored to pristine 6.12.100 in full (`git show 1db0e7a:arch/x86/mm/tlb.c`). That cascaded into three more fixes, each caught by an actual failed build, not by inspection: removed the `config X86_BROADCAST_TLB_FLUSH` Kconfig entry zen added in `arch/x86/Kconfig.cpu` (it's a `def_bool y depends on CPU_SUP_AMD && 64BIT`, also force-`select`ed by `CPU_SUP_AMD` — not something `scripts/config -d` can turn off, has to go at the source); removed two related lines in `arch/x86/kernel/cpu/amd.c` (an unconditional `invlpgb_count_max` declaration/assignment that collided with `tlbflush.h`'s `#define invlpgb_count_max 1` fallback once the config symbol stopped existing — `error: label`-style failures are loud, but this one was a genuine second compile error on the next attempt); and restored `arch_tlbbatch_add_pending()` as a `static inline` directly in `arch/x86/include/asm/tlbflush.h` (vanilla 6.12.100 defines it inline in the header; zen's patch moved the implementation into `tlb.c` as an `extern` to add INVLPGB-aware branching — reverting `tlb.c` alone left a dangling `extern` with no definition, caught as `undefined reference to 'arch_tlbbatch_add_pending'` at the final link step of a full build, not at compile time, since `mm/rmap.c` — untouched by the zen patch, itself unmodified — calls it unconditionally as part of the standard generic TLB-batching API). `mmu_context.h`, `mmu.h`, and `tlbbatch.h` needed no changes — already guarded behind `#ifdef CONFIG_X86_BROADCAST_TLB_FLUSH` with working stubs. |
| `certs/` (build-time, not a patch) | Gentoo's `.config` hardcodes `CONFIG_MODULE_SIG_KEY` to an absolute path inside their own portage sandbox (`/var/tmp/portage/.../kernel_key.pem`) — an artifact of how they build, not something that exists here. Repointed to the upstream default `certs/signing_key.pem`, which the build auto-generates a throwaway signing key for. `CONFIG_MODULE_SIG_FORCE` was already off in Gentoo's config, so this doesn't change whether unsigned modules load — consistent with Arctic's no-module-signing policy either way. |
| `kernel/sched/alt_core.c` | Not part of the 185-file reconciliation at all — `alt_core.c` is a wholesale new file from zen (PDS/BMQ), so `git apply` just writes it verbatim with no opportunity to notice drift against upstream. It calls `blk_plug_invalidate_ts(tsk)` (1 arg); vanilla 6.12.100's version of that function (`include/linux/blkdev.h`) takes zero arguments now — upstream simplified it between .17 and .100 to operate implicitly on `current`. Confirmed correct by cross-referencing `kernel/sched/core.c`'s equivalent `sched_update_worker()`, which already calls the zero-arg form. Found this one specifically *because* none of the four shipped config flavors enable `CONFIG_SCHED_ALT` by default, which meant this file had never been compiled at all — see "Verified by build" below. |

## Verified by build

Not just "does the patch apply" — actually compiled, inside `container/build.sh`'s bwrap sandbox, host GCC 15.3.0:

- **Default-config**: full `bzImage` + `modules` build, clean. 4,623 `.ko` modules built, kernel release `6.12.100-arctic-gentoo-dist-bin+`. This is what caught the `arch_tlbbatch_add_pending` link failure above (two earlier attempts failed — one on the stale `certs/` key path, one on the dangling `reload_tlb` label).
- **Hardened/Small/RT-config**: `make olddefconfig` reconciles cleanly (no build errors possible from Kconfig-only deltas on top of an already-building tree), not independently full-compiled — would be redundant given they share the exact same source tree Default-config already builds, and none of the three touch a code path Default-config doesn't also exercise.
- **`CONFIG_SCHED_ALT=y` (PDS/BMQ)**: not enabled in any shipped config, so targeted-compiled separately (`make kernel/sched/`) since it's a large, untested-by-default code path. Caught the `alt_core.c` bug above; compiles clean after the fix (one benign `-Wframe-larger-than=2048` warning, common in scheduler code).

## Layer 3: Arctic custom patches (`patches/arctic/`)

Small, deliberately conservative — zen already owns the scheduler/TCP/ACS
territory above, so this layer is additions that don't overlap it:

- `0001-mm-bump-default-readahead-to-512k.patch`: raises
  `VM_READAHEAD_PAGES` from 128KiB to 512KiB
  (`include/linux/pagemap.h`). Same value Clear Linux and CachyOS ship;
  larger sequential-read-ahead trades a bit of page-cache memory for fewer
  I/O round trips on spinning and networked storage.

Deliberately *not* included here as "custom" patches, because they're
already config knobs rather than something a source patch should own:
BBR as default congestion control, `net.core.default_qdisc`,
`vm.max_map_count` — vanilla Linux already exposes these as sysctl/Kconfig
defaults; changing them belongs in `Default-config` (or Arctic Linux's
userspace `sysctl.d`), not in a kernel patch.

## License

GPL-2.0-only, same as upstream Linux (see `COPYING`). Linux itself is
copyright Linus Torvalds and the Linux kernel community; the ZEN patchset
is copyright the zen-kernel project and its contributors. Arctic Linux
adds only the small delta in `patches/arctic/` and the config/build
scaffolding around all of it.
