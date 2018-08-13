+++
title = "GSoC: The all-encompassing final report"
date = 2018-08-13T14:22:32+05:30
slug = "gsoc-final"
tags = ["gsoc", "rtems"]
categories = ["tech"]
+++

Hi! This blog post acts as _the_ final report for GSoC, meant to summarize all
of my work in one convenient package.

# Intro

TL;DR: My GSoC proposal was to port [RTEMS](https://www.rtems.org/), a real-time
operating system, to the Intel/AMD x86-64 architecture.

(P.S. - [RTEMS was recently used on NASA's Parker Solar
Probe!](https://lists.rtems.org/pipermail/users/2018-August/032495.html))

# Code talks

If you're only looking for all the code that was written during this GSoC, the
links are here:

- https://gist.github.com/AmaanC/d7817809f2126a01104a2b15437cfc49

Read on for details that you probably don't understand that put that code in
context (feel free to email me if you're curious about any, though!).

# Getting the build-tools ready

RTEMS has specific GCC-targets available for every architecture it supports to
make development easier. The RTEMS x86-64 targets for GCC have specific switches
added to the GCC tool, and can be configured to build specific C-runtime
environment libraries and whatnot.

Some minor patches were sent to GCC to bring the same standardized switches to
the x86-64 target:

- [GCC patch #1](https://gcc.gnu.org/git/?p=gcc.git;a=commitdiff;h=602fa1e9d3ea5e87d4d6e17e3e91fc2647e42da3).

  Include a [standard file for RTEMS targets in GCC that defines specific
  `LIB_SPEC` syntax.](https://github.com/gcc-mirror/gcc/blob/f63400aa3858d8b8f2a3b3ba5d50808478eb292b/gcc/config/rtems.h#L40-L44)

- [GCC patch #2](https://gcc.gnu.org/git/?p=gcc.git;a=commitdiff;h=ab55f7db3694293e4799d58f7e1a556c0eae863a)

  Tell GCC to build C-runtime files such as `crti.o` and `crtn.o`, which provide
  symbols like `_init` and `_fini`, which are parts of the pathways that let a C
  program actually setup and reach the "entry point" (usually `int main`, but
  linkers can configure them).

The [RTEMS Source
Builder](https://docs.rtems.org/branches/master/rsb/configuration.html) makes
it easier to build these development tools with the same configurations - as
such, these GCC patches were also added to the RSB as backport patches, to be
used until the upstream GCC patches can be included in a release version. The
RSB patches are:

- [RSB patch #1](https://git.rtems.org/rtems-source-builder/commit/?id=defa958301215995b0fa41d8e65cb23c9a28a847)
- [RSB patch #2](https://git.rtems.org/rtems-source-builder/commit/?id=a3a6c34c150a357e57769a26a460c475e188438f)

# Stub port

[RTEMS' directory structure is detailed in their documentation
here](https://docs.rtems.org/branches/master/develenv/index.html) - in brief,
the way it works is that most of my work is to provide the hardware-specific
code for the higher-level executive to use. So for eg. I provide `_CPU_do_thing`
(which is how you do the thing on x86-64 specifically). This interface may be
standardized in the RTEMS executive through a public API `rtems_do_thing`.

A fair bit of time was spent figuring out which functions I needed to provide
for the executive to be happy - I called this the "stub port". None of the work
on the stub port was upstreamed because the functions a port provides depend
heavily on the architecture and tooling used (even though I do believe it ought
to be something maintained alongside RTEMS as a starting point for developers
looking to port RTEMS to a new architecture - RTEMS has a `no_cpu/no_bsp` stub
port which kind of fits the bill).

Perhaps in the future, I'll work on updating `no_cpu/no_bsp` to genuinely act as
the starting point for new ports.

# Boot method

A primary goal of this project was to not have to support legacy software that
the existing RTEMS i386 port was being dragged down by.

We intended to support UEFI instead of legacy BIOS setups. There have been a
fair number of discussions regarding what our options were, summarized in some
of my previous posts.

Initially, I worked on (and got pretty close to completing) a method in which
all of the RTEMS kernel + user application would be compiled as a dynamic ELF
(`.so` extension), which can then easily be converted to the
[PE format](https://en.wikipedia.org/wiki/Portable_Executable) that UEFI
requires - this resulted in a patch to Binutils so we could run a command like
`x86_64-rtems5-objcopy -j ... --target=efi-app-x86_64 ...` to convert ELF
dynamic libraries to PE files.

- [Binutils patch
  #1](https://sourceware.org/git/gitweb.cgi?p=binutils-gdb.git;a=commitdiff;h=421acf18739edb54111b64d2b328ea2e7bf19889)

I also had some WIP patches to GCC [built on top of a WIP patch Joel
shared](https://lists.rtems.org/pipermail/devel/2018-May/021587.html). My work
allowed the GCC to act sane when the `-fPIC -shared` options were used, but eventually,
we _didn't_ use this approach, so the patch isn't really useful unless that
approach is tried again in the future. The WIP patch is:

- [GCC patch #NaN](https://gist.github.com/AmaanC/7caf41f4d378767378b61c3e0f5f2aed#file-gcc-fpic-shared-patch-L59)

We settled on ripping the FreeBSD bootloader out and freeloading (hehe) off of
it for UEFI support - we basically replace the ELF FreeBSD kernel with our own
ELF RTEMS kernel. The bootloader sets paging up to map every 1GiB of virtual
memory to the first 1GiB of physical memory, and enters into long-mode (64-bit
mode), sets up some exception handlers, and jumps into the ELF64 kernel. (Our
kernel later overrides just about all of those settings.)

[This FreeBSD based approach is documented
here](http://web.archive.org/web/20180718114032/http://whatthedude.com/rtems/user/html/bsps/bsps-x86_64.html#boot-rtems-via-freebsd-s-bootloader) (as
an archive link because we'd prefer not to stick with the FreeBSD bootloader
forever given its forced use of the UFS filesystem). The documentation patches
are:

- [RTEMS Documentation patch #1](https://git.rtems.org/rtems-docs/commit/?id=4c2ca04c478b9c76932e9d87ca9a8b07354d4cf5)

# Context initialization and switching

RTEMS boots up and context-switches immediately to its entry-task - this means
that reaching a user's `Init` task needed context-initialization and switching
just about immediately.

- [RTEMS kernel patch to get to the `Init`
  task](https://git.rtems.org/rtems/commit/?id=76c03152e110dcb770253b54277811228e8f78df)

# Console driver a.k.a. `printf`!

The console driver used in the x86-64 port rely on the existing NS16550 UART
console driver that RTEMS already includes. The glue code is fairly simple, and
with it, RTEMS' testsuite's hello.exe test can pass.

- [RTEMS kernel patch for the console
  driver](https://git.rtems.org/rtems/commit/?id=cf811a4eb2358d66f403cd1397b29829e1827220)

# Paging

FreeBSD's bootloader sets paging up for us, which is good, but insufficient,
because [they set it up such that every 1GiB of virtual memory maps to the same
first 1 GiB of physical
memory](https://github.com/freebsd/freebsd/blob/aeea8c4eef503dcfc98025cc551e0faa2344d6c5/stand/efi/loader/arch/amd64/elf64_freebsd.c#L167-L184).
This _could_ have worked for us, except for the fact that for our clock driver,
we wanted to use the APIC timer - the APIC is generally located at physical
address `0xfee00000`, which is inaccessible through the FreeBSD paging
scheme. Initially, I tried simply relocating the APIC using the `wrmsr`
instruction for the `IA32_APIC_BASE_MSR` (`0x1b`) - this didn't work in QEMU
though (the MSR accepted my writes, but then using that address to initialize
the APIC wouldn't be reflected in QEMU's Monitor through the `info lapic`
command).

Eventually, I settled on adding static page tables with 1GiB super pages:

**XXX**: Replace with commit link once upstreamed

- [RTEMS kernel patch for paging support](https://lists.rtems.org/pipermail/devel/2018-August/022831.html)

# Interrupts

It took me a long time to understand that RTEMS had "RTEMS interrupts" and "raw
interrupts" - the latter are the architecture-specific interrupts. The former is
the name for generic interrupt vectors that RTEMS hooks - this means that a
generic handler (usually called `_ISR_Handler` in the RTEMS source) will:

- Handle interrupt nesting and thread-dispatch disable levels in a global state
  (`_Per_CPU_Information`)
- Save the caller-saved registers, because this generic handler wants to make
  calls to any user registered handlers in C (for eg. through the
  `rtems_interrupt_handler_install` API).
- Since this is a real-time operating system, interrupts also need to check if
  tasks need to be rescheduled or dispatched - this is usually done by checking
  the `dispatch_necessary` flag in the `_Per_CPU_Information` structure and then
  calling `_Thread_Dispatch` or `_Thread_Do_dispatch`.

As long as it took, the port does support both raw and RTEMS interrupts.

RTEMS interrupts are only hooked for IRQ0-32 (33 vectors in total), whereas raw
interrupts can be hooked for the full range of available vectors on the x86-64
architecture, whcih is 256 vectors (0-0xff).

The patch is:

**XXX**

- [RTEMS patch for interrupt support](https://lists.rtems.org/pipermail/devel/2018-August/022832.html)

# Clock driver (APIC timer, PIT, local APIC, and PIC come along for the ride)

Discussions long ago resulted in us deciding to use the APIC timer for the clock
driver. The APIC timer runs at the CPU bus frequency (which is not the same as
the CPU frequency!) - this means the timer needs to be calibrated as there's no
easy way to tell the frequency it's running at. I ended up using the
[PIT](https://wiki.osdev.org/PIT) to calibrate the APIC timer by running the PIT
for a fixed duration (since it runs at a fixed frequency, this is easy), and
seeing how many ticks had passed in the APIC timer. We can do this multiple
times to find an average for better calibration.

Since the APIC timer is a part of the [local APIC](https://wiki.osdev.org/APIC),
part of every CPU core, we need to enable the local APIC (this is part of why
paging support became a part of this GSoC).

We should also remap the PIC and then disable it since we'll be using the APIC
instead. (We need to remap before disabling for a funny reason - x86
architectures by default map their exceptions to IRQ0-32. The PIC maps external
interrupts to those same IRQ vectors. When the PIC is being used, it definitely
needs to be remapped, understandably, because if it isn't, all external
interrupts will look like exceptions to the kernel. The reason it _also_ needs
to be remapped even if the PIC is going to be disabled through masking is due to
"spurious interrupts" - these can occur on the PIC (at IRQ7) even if all
interrupts are masked).

Once the APIC timer is calibrated, we use the RTEMS configurable
`CONFIGURE_MICROSECONDS_PER_TICK` to set the APIC Timer to run at the frequency
such that it generates interrupts at that configured microsecond per tick rate.

**XXX**

- [RTEMS patch for the clock driver](https://lists.rtems.org/pipermail/devel/2018-August/022833.html)

There _may_ be a bug in the clock driver - ticker.exe seems to fail at
optimization level `-O2`. See this mailing list discussion for more:

- https://lists.rtems.org/pipermail/devel/2018-August/022825.html

# Future to-do

Despite having covered a _lot_ of ground this summer, there's a lot of work that
remains to be done on this project. Off the top of my head:

- Floating point support (MMX, XMM registers, and floating-point context
  switches)
- Default exception handlers which print the CPU state
- Interrupt-based console driver (currently uses the polled NS16550 driver)
- An alternative method to support UEFI (the FreeBSD bootloader is hard to use
  because it uses the UFS/ZFS filesystems, which most kernels don't support -
  this means that we have to use QEMU with FreeBSD to edit the filesystem and
  update our RTEMS kernel that the bootloader will load)
- RTEMS Source Builder recipes for:
  - OVMF UEFI firmware that can be used with QEMU
  - QEMU itself (RSB includes a recipe but it builds without graphics support,
    and is therefore useless here)
  - The bootloader (FreeBSD image, or preferably an easier alternative, or
    gnu-efi's build files, as apt)
- A way to easily run `rtems-test` (impossible now due to the FreeBSD bootloader
  blocker mentioned above)
- ACPI support so we can cleanly shutdown (right now, we just `while(1)`
  forever)
- SMP support
- Better APIC and I/O APIC support (to allow for interrupt redirections)
- SMP support
- Search for `XXX` in any of the `x86_64` directories for things that need
  improvement

# Elevator pitch

If you're even vaguely interested in systems software, I'd _highly_ recommend
RTEMS - it's a [great community with extremely helpful
people](https://lists.rtems.org/mailman/listinfo), software that is
quite widely used
([see!](https://devel.rtems.org/wiki/TBR/UserApp/RTEMSApplications#SpaceandAviation)),
and [very interesting challenges to solve](https://devel.rtems.org/query).

Their wiki is full of information and ways to get started:
https://devel.rtems.org/wiki/GSoC/GettingStarted

I'd also like to thank Joel Sherrill, Gedare Bloom, Chris Johns, Sebastian
Huber, and the countless other people on the mailing lists who've been patiently
helping me rubber-duck debug and providing me with information I didn't know I
needed all summer long. You're all amazing! :D

--------------------------------------------------------------------------------

Finito banana. I'm going to go stare at a wall for a while because GSoC's been
much harder and more stimulating than I expected. :P
