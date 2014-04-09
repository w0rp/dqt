DQt
===

This package offers Qt bindings for D, and depends heavily on DSMOKE.

## Updates

Check out [the wiki](https://github.com/w0rp/dqt/wiki) for a summary of project status, what I'm working on, etc.

## Quick Start

The project can be built with its own build script, assuming both
*dstruct* and *dsmoke* are available in the parent directory of dqt, and
dub is also installed.

```sh
rdmd build.d
```

After that, you can run a Hello World example with a provided Bash script,
which as of the time of this writing (2014-05-09) currently subverts
the build process somewhat.

```
# You will need Qt4 headers and such for this.
# It's probably best to just open this script up and tweak it to
# get it running for now.
examples/run_hello_world
```
