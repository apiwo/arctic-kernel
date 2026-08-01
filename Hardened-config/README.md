# Hardened-config

`Default-config` plus mainline (no out-of-tree grsecurity) exploit-mitigation
options turned on: `HARDENED_USERCOPY`, `FORTIFY_SOURCE`,
`STACKPROTECTOR_STRONG`, `INIT_ON_ALLOC_DEFAULT_ON` /
`INIT_ON_FREE_DEFAULT_ON`, `SLAB_FREELIST_RANDOM` / `SLAB_FREELIST_HARDENED`,
`RANDOMIZE_MEMORY`, `LEGACY_VSYSCALL_NONE`, `SECURITY_DMESG_RESTRICT`,
`SECURITY_LOCKDOWN_LSM` (+ early lockdown, forced integrity mode).

`io_uring` was deliberately targeted for removal (it's a real, repeated
source of privilege-escalation CVEs and several distros disable it in
their hardened profiles) but `make olddefconfig` kept re-enabling it —
something else selected in `Default-config` depends on it. Didn't chase
down what, since silently forcing it off and hoping nothing else in the
broad-hardware default config breaks felt worse than documenting it
honestly. If you want it gone, start from a narrower base config and
disable whatever pulls it in.

No module-signing enforcement here, unlike most "hardened" kernel
configs — consistent with the rest of Arctic Linux, which verifies
package integrity through alpm rather than kernel module signing.
