+++
title = "gnu-efi integration: kernel.so or loader.so+kernel.elf"
date = 2018-06-02T12:24:39+05:30
slug = "gnu-efi-kernel-so"
tags = ["gsoc", "rtems"]
categories = ["tech"]
+++

In this post, we'll discuss the 2 possible methods of integrating `gnu-efi` into
your project to make your kernel / OS "UEFI-aware" (i.e. capable of booting
through UEFI firmware).

[Other options (without using `gnu-efi`) are laid out in my previous blog post
on the topic.]({{< relref "rtems-uefi-application-options" >}})

# Relevant context

`gnu-efi` has one key constraint that requires our project's files to be built
as shared libraries when linked with `libefi` and `libgnuefi`. Namely, from the
`gnu-efi` project's README:

>  (2) EFI binaries should be relocatable.

>   Since EFI binaries are executed in physical mode, EFI cannot
    guarantee that a given binary can be loaded at its preferred
    address.  EFI does _try_ to load a binary at it's preferred
    address, but if it can't do so, it will load it at another
    address and then relocate the binary using the contents of the
    .reloc section.

And:

> The approach to building relocatable binaries in the GNU EFI build
environment is to:

> (a) build an ELF shared object

> (b) link it together with a self-relocator that takes care of
     applying the dynamic relocations that may be present in the
     ELF shared object

> \(c) convert the resulting image to an EFI binary

### Prerequisite reading

If you're unfamiliar with what load-time relocation is, or what PIC
(position-independent code) is, read the following:

- https://eli.thegreenplace.net/2011/08/25/load-time-relocation-of-shared-libraries/
- https://eli.thegreenplace.net/2011/11/03/position-independent-code-pic-in-shared-libraries/
- https://eli.thegreenplace.net/2011/11/11/position-independent-code-pic-in-shared-libraries-on-x64

If you're unsure of how `gnu-efi` works or how we convert its shared/dynamic
library into a relocatable PE, read this section from my previous post:

- ["Options for creating a UEFI application image"]({{< relref
  "rtems-uefi-application-options"
  >}}#simplest-use-gnu-efi-then-use-objcopy-to-convert-elf-to-pei)

--------------------------------------------------------------------------------

# The bundled approach

To be able to compile the entire RTEMS kernel as a shared library, we'll need to
handle a few issues:

- RTEMS uses Newlib, which is currently compiled as a static libc.a archive -
  this will cause us problems at link-time (if we use the `-shared` flag)
  because it'll include incompatible relocation entries such as `R_X86_64_32`.
  - Fortunately, [Sebastian had a simple but brilliant idea to solving this
    issue on the mailing
    list](https://lists.rtems.org/pipermail/devel/2018-June/021883.html). I
    could simply add `-fPIC` as a default option to GCC's configuration, and
    since the `RTEMS source builder` builds GCC, then compiles Newlib with
    this version of GCC, Newlib's `libc.a` will contain no incompatible
    relocation entries.
  - [This patch to configure GCC was fairly
    simple.](https://github.com/AmaanC/gcc/pull/1/commits/5f7531f9b9f72fcbd2738e535a2a18f2c706212f)
    (I may not submit it upstream because we may end up going with something
    closer to the FreeBSD approach below instead.)
- GCC provides us with `crtbegin.o` and `crtend.o`, both of which also contain
  the incompatible `R_X86_64_32` entries.
  - We can just ask GCC to build the shared variants of these files,
    `crtbeginS.o` and `crtendS.o`, and have GCC use them whenever the `-shared`
    flag is used.
  - [Relevant patch to GCC to handle this.](https://github.com/AmaanC/gcc/pull/1/commits/e3b6fe9d2073debcfccb26cb1513c5209aeccbe0)
- We'll need to figure out a way to have _RTEMS_ itself compile itself with
  `-fPIC` and build shared libraries.
  - Fortunately, even this is fairly simple because RTEMS uses the idea of a
    `bsp.cfg` file which can customize compiler flags, and we can simply add the
    relevant flags to our port's specific `amd64.cfg` file.
  - [Relevant RTEMS
    patch.](https://github.com/AmaanC/rtems-gsoc18/commit/547ef85a7f176046b2cb06a34b1e312c4986e97f)

Obviously, this approach is fairly simple and would let us just package all of
RTEMS neatly into a relocatable PE very easily.

But what are the downsides of this approach?

- We may be _special-casing_ the build system for UEFI beyond recognition, tying
  ourselves in too deeply to easily adapt to a different one, such as Multiboot
  support. This may not be as big a deal, but it's a concern to keep in mind.
- We have no real reason to use `-fPIC` and the GOT/PLT it brings with it in
  RTEMS, since it _will_ be fully resolved, and in theory, we could figure out a
  way to make the linker fill in the relative-addressing relocations without
  needing a runtime GOT/PLT method.
- RTEMS _is_ a kernel, involving interrupt-handling, context-switching,
  etc. It's entirely possible that this method has unintended consequences on
  how such code is generated later, when we start to actually use it. Chris
  Johns (one of this project's GSoC mentors) means to look into this.

# The FreeBSD way

FreeBSD takes a different approach. They have a multi-stage loading
process. In brief:

- They build a two-stage bootloader for EFI, called boot1.efi and
  [loader.efi](https://www.freebsd.org/cgi/man.cgi?loader(8)).
- loader.efi is an interactive prompt which may autoboot, or a `boot kernelImg`
  command can be used to load the actual kernel.
- The kernel is loaded as an ELF through helper functions. The [`command_boot`
function](https://github.com/freebsd/freebsd/blob/433bd38e3a0349f9f89f9d54594172c75b002b74/stand/common/boot.c#L53)
    drives this:
  - In brief, through calls go through:
  - `command_boot -> mod_loadkld -> file_load ->
file_formats[i]->l_load` (actually the `loadfile` function in
[`load_elf.c`](https://github.com/freebsd/freebsd/blob/d8596f6f687a64b994b065f3058155405dfc39db/stand/common/load_elf.c#L150))
  - The `loadfile` function parses the program and section headers of the ELF
    file (through more function detours that are not really important).
  - Once the ELF has been loaded into memory at the correct `entry_addr` that it
    expects to be loaded at in memory, the
    [`l_exec`](https://github.com/freebsd/freebsd/blob/433bd38e3a0349f9f89f9d54594172c75b002b74/stand/common/boot.c#L107)
    function is called, which is actually [`elf64_exec` in
    `elf64_freebsd.c`](https://github.com/freebsd/freebsd/blob/d8596f6f687a64b994b065f3058155405dfc39db/stand/efi/loader/arch/amd64/elf64_freebsd.c#L93),
    at which hopefully through trampolining magic, the control flow will
    transfer to the kernel or ELF module.

TL;DR: FreeBSD's kernel is loaded as an ELF file into memory and then executed
through trampolining magic.

The benefits of this approach are:

- We'd have a proper ELF loader in RTEMS, so the kernel changing over time
  doesn't mean needing to be concerned with how the UEFI build system may break
  because of it (for eg. how is handwritten assembly handled in terms of a
  relocatable shared library?).
- Our choice to support UEFI doesn't affect how the _entire_ system is built -
  it only affects the codebase in terms of needing to add the ELF loader.

Downsides:

- The loader may be a lot of complicated code, increasing the size and
  complexity of RTEMS and its images for x86-64.
- We'd need to figure out a way to have a `loader.efi` which uses whatever UEFI
  boot services it needs to, and then calls into an ELF loader to load the
  actual ELF - the location of this ELF could be read from a configuration file
  or be based on convention. This isn't a downside as much as it is a thing
  worth noting.

--------------------------------------------------------------------------------

Finito.
