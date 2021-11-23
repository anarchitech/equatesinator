# This Fork

This is forked from https://github.com/nimblemachines/kinetis-chip-equates.  The name has been changed to protect the diginity of the daf from the
doodlings of the doof.  For now I've kept the original README below, although that optimistic section "What if my chip is missing?" and the MCUXpresso SDK Builder 
should be ignored. I feel like it's a bit misleading; the only focus of that weird online SDK seems to be NXP products. 

You're far better off just copying Makefile_original and hacking it. It's pretty obvious, just make sure that your source file is NAME.svd 
as opposed to, say, esp8266.base.svd.  That one broke the lua script. (You can also look at the Makefile_esp and novectors_print-regs-generic.lua
to see what I had tweak to handle a less than complete svd file.)

One change is that there will likely be multiple Makefiles to handle certain differences in svd's. I'd rather do that than watch a damn Makefile grow into some
peristaltically convulsing gluttonous Mr Creosote. There are svd's out there for the ESP8266, for example, that are ... less than complete, shall we say.  

Hence, in this repo you'll find Makefile_original and Makefile_esp and original_print-regs-generic.lua and novectors_print-regs-generic.lua

## Warning
This code, whether this fork or the original is currently brittle and has multiple issues handling svd files that don't fit its expectations.  As work on 
origin/master is low priority at the moment, you're on your own.  Expect things to break, expect to dive in and get your hands dirty if you're trying extract
equates from something. **Inclusion of an SVD in the [muforth-anarchitech](https://github.com/anarchitech/muforth-anarchitech) fork is not a guarantee that it will work
OOTB with The Equatesinator!** For example, this morning during testing we're finding that esp32.svd and esp32_base.svd are flailing badly.

### Example: Build esp8266.mu4
```
cd equatesinator
cp Makefile_esp Makefile
cp novectors_print-regs-generic.lua print-regs-generic.lua
make update
make esp8266.mu4
```
If you have an svd that has Vectors in it (rp2040,stm,nxp; here we generate for the rp2040):
```
cp Makefile_original Makefile
cp original_print-regs-generic.lua print-regs-generic.lua
make update
make rp2040.mu4
```
Always keep the Makefile_original in its original state.

I'm not going to spend many cycles improving this thing.  If you need it, you need it, if you don't, you don't.  It's very muforth specific.

### A Brief Note on Building The Equatesinator

Every damn system has a different idea about what to call lua. Use which or whereis; some default installs have it as lua, some as luaXX, some 
as luaX.X  We highly recommend mkdir bin in your home directory and ln -s /wherever/the/hell/your/real/lua/is lua. The Equatesinator will thank you.

You need to use [GNUmake](https://github.com/nimblemachines/kinetis-chip-equates/issues/1)

------------------------------------------------------------------------------------------------------------------------------------------------

(Original README)

# Why?

One of the issues with rolling your own language &ndash; especially if, like [muforth](https://muforth.nimblemachines.com/), it is a cross-compiler that targets microcontrollers &ndash; is that you need to find or create, for every chip you care about, "equates" files that describe the i/o registers, their memory addresses, and their bit definitions.

It's a lot of work &ndash; and error-prone &ndash; to type these in by hand. For the Freescale S08 and the Atmel AVR I was able to get pretty good results by "scraping" the PDF files by hand (yes, by hand, with a mouse), pasting the results into a file, and then running code that processed the text into a useful form.

For the STM32 ARM microcontrollers I wrote code that shoddily "parses" the .h files (which I found in their "Std Periph Lib" and STM32Cube zip files &ndash; I tried both) and prints out muforth code.

When I went looking for something similar for Freescale's Kinetis microcontrollers, I found the "Kinetis SDK", but was unable to find a recent (2.0) version that had definitions for all their chips. It doesn't seem to exist for 2.0. All I could find is the 1.3 version, which seems pretty old (it's from 2015).

In the 662 MiB zip file (!!) that I downloaded, I found the gold mine. In

    KSDK_1.3.0/platform/devices/

there is a directory for each chip, and in that directory is a [CMSIS-SVD file &ndash; a gawdawful XML file that describes all the registers and register fields](http://www.keil.com/pack/doc/CMSIS/SVD/html/). I've included all of the CMSIS-SVD files here, in the directory `SVD/`.

These files got me started, but since then I've discovered Keil's [CMSIS-Pack](http://www.keil.com/pack/doc/CMSIS/Pack/html/index.html) project and their [meta-repository](http://www.keil.com/pack/doc/CMSIS/Pack/html/packIndexFile.html). The idea is that vendors can make available &ndash; via a simple web API &ndash; updated "packs" that describe a chip or a board. By downloading [Keil's pack index](http://www.keil.com/pack/index.pidx) it's easy to find what packs each vendor makes available.

[Getting Started with MCUXpresso SDK CMSIS Packs](https://www.nxp.com/docs/en/user-guide/MCUXSDKPACKSGSUG.pdf) &ndash; a document from November 2017 &ndash; talks about "CMSIS packs downloaded from MCUXpresso packs repository", including "Device Family Packs", which contain the following:

* Device header files and system initialization modules
* Startup files
* Linker files
* SVD files
* Flash drivers (for some of the development tools)
* SDK drivers and utilities
* SDK project templates

Sounds perfect, right? There are a bunch of NXP DFP packs in [Keil's pack index](http://www.keil.com/pack/index.pidx), and I've added [Lua code to parse the index](https://github.com/nimblemachines/kinetis-chip-equates/blob/master/parse-pack-index.lua), and a [Makefile](https://github.com/nimblemachines/kinetis-chip-equates/blob/master/Makefile) target to download and unzip the likely culprits.

I'm not the only one with this problem. Even the [Zephyr project](https://github.com/zephyrproject-rtos/zephyr/) is struggling with [getting up-to-date header files for NXP/Freescale chips](https://github.com/zephyrproject-rtos/hal_nxp/tree/master/mcux).

# How do I use this?

First you need to run

    make update

This will download the current index of CMSIS-Pack files from Keil, then download a bunch of "device family pack" (DFP) files from NXP and populate the `SVD/NXP_DFP/` directory with the SVD files found therein (these have a .xml extension, unlike the files from the Kinetis SDK which have a .svd extension.)

I wrote two Lua scripts: 

* [`parse-svd.lua`](https://github.com/nimblemachines/kinetis-chip-equates/blob/master/parse-svd.lua) &ndash; parses the SVD file's XML into a big Lua table and prints it out
* [`print-regs.lua`](https://github.com/nimblemachines/kinetis-chip-equates/blob/master/print-regs.lua) &ndash; slurps in that big Lua table and prints out register (and register field) definitions, and the interrupt vector table, in a form that muforth can understand.

The default Makefile target builds a "FRDM boards" subset of the chips. Running

    make

will process the SVD files for this subset, first by generating a Lua representation of the SVD file, and then reading that in and generating a muforth (.mu4) file. By combining the downloaded DFP files with the Kinetis SDK files, I'm able to generate `.mu4` files for 23 of the 25 FRDM boards that are shown on the [MCUXpresso SDK Builder](https://mcuxpresso.nxp.com/).

    make kl

will process all the Kinetis L SVD files into `.mu4` files; and

    make everything

will process *all* the SVD files into `.mu4` files, but it's also *much* slower.

# What if my chip is missing from the list?

It's possible to use the [MCUXpresso SDK Builder](https://mcuxpresso.nxp.com/) to build and download a "custom" SDK. After untarring or unzipping you'll find the SVD file for your chip in the `./devices/<chip>/<chip>.xml` file.)

Copy the `<chip>.xml` file to `SVD/custom/` and type

    make <chip>.mu4

It should generate first a Lua file and then your `.mu4` file!

# What else can I do?

The infrastructure is there to generate *any* kind of output from the Lua-fied SVD files. If you have a favorite language that needs "equates" files for a Kinetis microcontroller, go forth and modify!

# BSD-licensed!

See the `LICENSE` file for details.
