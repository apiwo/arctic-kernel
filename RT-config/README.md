# RT-config

`Default-config` with `CONFIG_PREEMPT_RT=y` (fully preemptible kernel) and
`CONFIG_SCHED_ALT` explicitly left off — mainline PREEMPT_RT is far more
tested against the stock CFS/EEVDF scheduler than against ZEN's PDS/BMQ
alternate scheduler, so this flavor deliberately doesn't combine the two.
Selecting PREEMPT_RT without needing `CONFIG_EXPERT` first is itself one
of the patches the ZEN merge carries
(`kernel/Kconfig.preempt`, see `PATCHES.md`).

For hard/soft real-time workloads (audio production, industrial control,
robotics) where worst-case scheduling latency matters more than
throughput. Everything else — module set, filesystem support, driver
coverage — is unchanged from Default-config.
