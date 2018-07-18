+++
title = "GSoC: Phase 2 status update"
date = 2018-07-16T14:22:32+05:30
slug = "gsoc-phase-2-status"
tags = ["gsoc", "rtems"]
categories = ["tech"]
+++

Since our last blog post, I realized that the RTEMS mailing list was a much more
convenient method of actually having discussions, and making important
decisions. In lieu of that, this blog doesn't include _all_ the decisions that
have been made. I'll summarize some of them here.

# Boot method

Our very first conundrum was the boot method - how do we make our RTEMS kernel
and user application UEFI-aware?

The last two posts
([1]({{< relref "rtems-uefi-application-options" >}}) [2]({{< relref "gnu-efi-kernel-so" >}}))
discussed some options to consider.

Since then, we've settled on a _usable_ approach, which may not be ideal, but
for now it's the simplest and most functional one; we use FreeBSD's UEFI
bootloader. [`loader(8)`](https://www.freebsd.org/cgi/man.cgi?loader(8)) allows
us to replace `/boot/kernel/kernel`, the ELF FreeBSD kernel, with our own RTEMS
ELF, and the loader will happily jump into its entry point and transfer control
to us after calling `ExitBootServices`.

The reason this isn't ideal is:

- It ties us into using only the UFS/ZFS filesystems (since they're the only
  ones that `loader` supports loading the kernel from) - these filesystems are
  hard to mount as read-write on most existing operating systems (most non
  FreeBSD OS's can only mount them as read-only). This means that a FreeBSD
  virtual image is likely needed every time the `/boot/kernel/kernel` needs to
  updated. This slows iterative development down majorly.

Regardless, using this approach is
documented
[here](http://web.archive.org/web/20180718114032/http://whatthedude.com/rtems/user/html/bsps/bsps-x86_64.html#boot-rtems-via-freebsd-s-bootloader).

-------------------------------------------------------------------------------

An alternative approach was compiling all of RTEMS as a position-independent
shared library, and then converting it to an EFI application. All work to make
this possible through tooling (GCC, binutils) is done, but was abandoned in
favour of the likely cleaner and more sustainable approach of leaving the RTEMS
kernel as a static ELF.

# Context initialization and switching code

All basic code for context initialization (i.e. setting an entry-point, filling
kernel data structures up) and context switching (jumping to entry-point and
setting CPU registers to their appropriate values for the current context) was
completed - this lets our x86_64 port complete all of the RTEMS initialization
chains, and finally reach the user-determined `Init` task (RTEMS' equivalent of
what we think of as `int main` in traditional C runtime environments).

[This, and other relevant code is available in this commit
upstream.](https://git.rtems.org/rtems/commit/?id=76c03152e110dcb770253b54277811228e8f78df)

# Console driver

Per the original
[GSoC proposal](https://docs.google.com/document/d/1X79Yj0DNqvaDFqpJMUX4gF3WC550GDvVDS5QufvAnFE/) and
[RTEMS ticket](https://devel.rtems.org/ticket/2898#Console), we intended to have
an easy implementation of `printk` for now. One that could just use something
like UEFI's provided
[`EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL`](http://wiki.phoenix.com/wiki/index.php/EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL).

We meant to implement UART functionality in phase 3, but since the FreeBSD
bootloader doesn't let us access the UEFI services, we were only left with the
UART as an option.

[RTEMS' built-in NS16550 polled driver is used in this port at the
moment](https://git.rtems.org/rtems/commit/?id=cf811a4eb2358d66f403cd1397b29829e1827220),
and is sufficient to allow RTEMS' hello world sample test run.

# Upcoming

A list of miscallenous wants for the future, all of which may not be completed:

- ACPI setup code (to allow the port to exit cleanly by resetting the system, to
  detect features available, etc.)
- Basic interrupt support, likely through the APIC
- Real clock driver (likely using the APIC timer - [see this thread for
  discussions](https://lists.rtems.org/pipermail/devel/2018-July/022440.html)
- Empty out `bsp_specs` by setting GCC up to use default `crti, crtbegin`
- RTEMS Source Builder recipes to build:
  - TianoCore's UEFI firmware
  - QEMU with SDL graphics support if required
  - FreeBSD or other bootloader image to be used for UEFI-awareness
- rtems-tools recipe to allow testsuite to be run automatically
- Thread-Local Storage support (currently ignored during context-switches)
- FPU support (currently disabled)

I aim to get to all the items in the above list, but it doesn't seem likely that
_all_ of them will be accomplished. I'll likely prioritize in a way that allows
future contributors to get up and running most easily - this will likely mean a
greater focus on good documentation, clean code, and the RSB recipes to let
RTEMS applications for this port be run easily.

Bonus (almost certainly won't be touched in this GSoC):

- Networking
- SMP
- Graphics
- Robust ACPI and APIC support

-------------------------------------------------------------------------------

Finito.
