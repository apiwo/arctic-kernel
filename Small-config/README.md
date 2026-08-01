# Small-config

`Default-config` with `CONFIG_MODULES` off, then reconciled with
`make olddefconfig` — every driver that only existed as a loadable module
in the default config, and has no built-in fallback, drops out entirely
rather than silently vanishing at runtime. Monolithic image, no module
loader in the kernel at all, smaller attack surface and no `modules_install`
step. Matches Arctic Linux's existing `Arctic-small-kernel` port.

Only makes sense for a known, fixed set of hardware (or a VM) — anything
Default-config would've handled by loading a module on demand, this
flavor needs built in ahead of time or not at all.
