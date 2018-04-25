+++
title = "Introduction to my GSoC project: An RTEMS x86-64 port"
date = 2018-04-25T20:08:56+05:30
slug = "rtems-x86-64-port-intro"
tags = ["gsoc", "rtems"]
categories = ["tech"]
+++

RTEMS is an RTOS which can run on tons of architectures and processor families
within those architectures.

However, the modern Intel `x86-64` / `AMD64` is not one of the currently
supported architectures.

`<infomerical time>`

_Have you ever wanted to try a new operating system for your project, but all
the emulators for your target processor support a limited number of features,
and you **really** don't want to have to test it all on your hardware?_

`</infomercial time>`

To be fair, RTEMS _does_ target the i386, but that involves maintaining a lot of
legacy code which the community would really rather not do.

This is where my proposal comes in - it targets modern, off-the-shelf hardware,
like the x86-64 processors most of us use day-to-day, supporting only the modern
non-legacy features (such as UEFI only, not BIOS).

If you want to dig into the nitty-gritty, [have a look at my project
proposal](https://docs.google.com/document/d/1X79Yj0DNqvaDFqpJMUX4gF3WC550GDvVDS5QufvAnFE/),
and the [project page on RTEMS' Wiki, which will act as an evolving document as
the project continues.](https://devel.rtems.org/wiki/GSoC/2018/x86_64_BSP)
