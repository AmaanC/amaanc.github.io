+++
title = "Options for creating a UEFI application image"
date = 2018-05-18T14:54:32+05:30
slug = "uefi-app-options"
tags = ["gsoc", "rtems"]
categories = ["tech"]
+++

# Context

This post is about some of the ways in which an operating system / kernel can be
made to boot as a UEFI application image (through UEFI firmware).

To be clear, let's make sure we have our definitions straight:

- **UEFI firmware**: The vendor firmware itself, which may or may not support
  legacy BIOS options. On the OSDev side, we won't really have control over
  this. For emulation, I'll be using [TianoCore's
  OVMF](https://github.com/tianocore/tianocore.github.io/wiki/How-to-build-OVMF)
  (OvmfPkgX64) specifically. [More setup instructions
  here.](https://devel.rtems.org/wiki/Developer/Simulators/QEMU#QEMUandUEFIusingOVMFEDKII)
- **UEFI application image**: A relocatable `PE/COFF` executable file which the
  UEFI firmware loads through a FAT partition, usually the file
  `/EFI/BOOT/BOOTX64.EFI` on the filesystem.

With RTEMS, we use a cross-compiler toolchain (for eg. `x86_64-rtems5-gcc`,
instead of the host computer's `gcc`). The toolchain is built automatically by
the [RTEMS Source Builder (RSB)](http://git.rtems.org/rtems-source-builder),
which does cool things like pull in a release version of the various tools,
backports patches that the RTEMS community may need (that are not in a release
version yet), and compiles the entire toolchain. These tools (`gcc`, `binutils`,
etc.) are then used to compile all of the RTEMS kernel, link the kernel to user
applications, the testsuite, etc.

# Options

### Simplest: Use `gnu-efi`, then use `objcopy` to convert ELF to PEI

Likely the simplest option, and the [one used by
FreeBSD](https://github.com/freebsd/freebsd/blob/996b0b6d81cf31cd8d58af5d8b45f0b4945d960d/stand/efi/loader/Makefile#L98-L119)
as well, and [documented on the OSDev
Wiki](https://wiki.osdev.org/UEFI#Developing_with_GNU-EFI), is to:

- Build an ELF64 shared library including an `elf_main` function
- Link it with `gnu-efi`'s libraries and `crt0` runtime
- Use `objcopy` with the `--target=efi-app-x86_64` / `--target=pei-x86-64`
  - `x86_64-rtems5-objcopy` doesn't support the `pei-x86-64` target at the
    moment, but this is easy to add with [this patch to bfd](https://gist.github.com/AmaanC/aa7145e631e9f20e35f9b133386d11c8#file-rtems-binutils-objcopy-pei-target-patch)
- Put the PE image file on a FAT partition. [Here's a quick script I used.](https://gist.github.com/AmaanC/aa7145e631e9f20e35f9b133386d11c8#file-make-img-sh)
- Boot the PE image with UEFI firmware now
- [ALL GLORY TO THE HYPNOTOAD!](http://r33b.net/)

I've tested this process with a "hello world" UEFI image using the
`x86_64-rtems5-*` toolchain and confirmed it works in QEMU.

(Reproduction steps:

- Use the RSB with my bfd patch to add the `pei-x86-64` target to
  `x86_64-rtems5-objcopy`. (I'll try to have this upstreamed based on
  discussions on the RTEMS developers mailing list.)
- Download gnu-efi
- Run `make CC=x86_64-rtems5-gcc OBJCOPY=x86_64-rtems5-objcopy ARCH=x86_64`
  within the project
- Run the `make-img.sh` script with the the path to the `t.efi` test file
  (within `gnu-efi-3.0.8/x86_64/apps/` at the moment)
- Run `qemu-system-x86_64 --bios /path/to/OVMF.fd -net none -cpu qemu64 -drive file=/path/to/uefi.img,if=ide`)

**Note:** This will involve making `gnu-efi` a part of the RTEMS build
process. I'm not sure where this will fit in yet and if there might be license
incompatibility issues here.

### Use a tool such as `iPXE`'s `elf2efi` utility

The iPXE bootloader includes a utility that can convert an existing ELF to an
EFI bootable image. I haven't explored this option much since the one using
`objcopy` seemed more standardized and one that would need less maintenance
overall to me. There would also be licensing considerations, and we would have
to confirm that the tool runs on all hosts that RTEMS intends to support for
development.

https://github.com/joyent/ipxe/blob/master/src/util/elf2efi.c

### Use an assembly-generated PE header for a "chimera" ELF?

The `wimboot` project associated with `iPXE` includes a [`prefix.S` file which
seems to generate the PE header
table](https://github.com/ipxe/wimboot/blob/master/src/prefix.S) automagically
in assembly, allowing us to possibly create a chimeric file which can act like a
PE - I'm not sure about the differences between ELF and PE and how compatible
they are, so I can't speak to how viable this method is, but it seems like
something that _has_ worked for some in the past; namely the Linux kernel uses a
technique called the EFI boot stub (or EFISTUB for short), using a [`header.S`
file to masquerade itself as a PE/COFF
image](https://github.com/torvalds/linux/blob/master/arch/x86/boot/header.S). This
is [documented here](https://www.kernel.org/doc/Documentation/efi-stub.txt) and
on the [Arch Wiki here](https://wiki.archlinux.org/index.php/EFISTUB) as well.

Given the possible license incompatibilities with the RTEMS project and the need
to shave a PE file-format yak, I'm leaning away from this method.

--------------------------------------------------------------------------------

P.S. - I'd like to say thanks to Chris Johns for helping me discover that the
last 2 options were even a possibility. Thank you! :D

--------------------------------------------------------------------------------


Conclusion: I'm leaning towards the first method, but I'd love to hear what you
think about the options I've laid out, and for any others I may have missed. Hit
me up! The [RTEMS mailing list discussion thread for this blog post is
here](https://lists.rtems.org/pipermail/devel/2018-May/021622.html).

--------------------------------------------------------------------------------

## Important resources:

- https://wiki.osdev.org/UEFI
- https://wiki.osdev.org/UEFI_Bare_Bones
- http://sourceforge.net/projects/gnu-efi/
- https://github.com/joyent/ipxe/blob/master/src/util/elf2efi.c
- https://github.com/ipxe/wimboot/blob/master/src/prefix.S
- https://github.com/torvalds/linux/blob/master/arch/x86/boot/header.S
- https://www.kernel.org/doc/Documentation/efi-stub.txt
