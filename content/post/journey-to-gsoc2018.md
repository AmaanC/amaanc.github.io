+++
date = "2018-04-24"
title = "The Journey to GSoC 2018 - just the beginning"
slug = "journey-to-gsoc"
tags = ["gsoc", "rtems"]
categories = ["tech"]
+++

Here I'll document some of the preperatory tasks I undertook as part of my
proposal to [RTEMS](https://www.rtems.org/) (AN RTOS THAT'S BEEN TO
<b>_SPACE_</b>! [SPAAAAAAAAAACE!](https://www.youtube.com/watch?v=BVn1oQL9sWg)).

# The Hunt

To start at the beginning, I'm going to have to just say that finding an
organization that piques your interest _and_ needs a project that hits just the
sweet-spot in "I have most of the skills to do this, but I'll still need to
learn and grow a lot to bring it to fruition" is _hard_. I oscillated between
organizations and potential projects for a month easily, until I finally
stumbled upon RTEMS, at which point I yelled "I'm going to Mars!" repeatedly
while jumping around the house. (Contributing to anything that's even remotely
related to space-research has been a dream for years, and the fact that RTEMS
has such an incredible and approachable community has been incredibly exciting
to me! :D)

Despite the excitement, RTEMS intimidated me majorly - their build system (using
Autotools) is more complicated than any I've worked with before, and it all felt
like magic that _I_ definitely wasn't cut out
for:

{{< tweet 981246781102071808 >}}

# Rise from the ashes

I decided eventually that I'd rather suppress my fear of looking stupid and just
use the community's knowledge whenever I needed it, by asking questions and
learning instead of struggling in vain.

[This resulted in very productive discussion on the mailing
list](https://lists.rtems.org/pipermail/devel/2018-March/020370.html), and even
a [few upstreamed patches to the core repository (the first 4 commits
there)](https://git.rtems.org/rtems/log/?qt=author&q=Amaan), which let me
finally gain some momentum.

Given that I was still working part-time ([on this
holy-shit-how-can-you-do-that project](https://github.com/copy/v86))
and attending university, I decided I'd allot about 1 day per week to furthering
my familiarity with RTEMS and figure out which specific project I'd like to work
on.

This worked out surprisingly well! I started working towards my proposed phase 1
target of getting a new stub port for RTEMS (i.e. one that implements empty
function definitions as much as possible, just to get it linking with the core
of RTEMS, and therefore eventually all of the testsuite).

In the process of doing this, I came across a teeny tiny bug in
<span style="color:red">👏 G 👏 C 👏 C 👏</span>. That's right, I had the
opportunity to submit a teeny patch to GCC for the `x86_64-rtems-gcc` target to
allow it to include the standard RTEMS tools flags like `-qnolinkcmds`,
`-qrtems`, etc. through the GCC [spec
syntax](https://gcc.gnu.org/onlinedocs/gcc/Spec-Files.html).

[The patch that will let me die happily ever
after.](https://gcc.gnu.org/git/?p=gcc.git;a=commitdiff;h=602fa1e9d3ea5e87d4d6e17e3e91fc2647e42da3)

After that, I continued working on the stub port and got _some_ RTEMS tests
linking to my stub happily, but there's still _tons_ of work to be done. See
[my post detailing my GSoC 2018 proposal for more information on what's coming
next.]({{< relref "rtems-x86-64-port-intro" >}})
