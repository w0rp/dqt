DQt
===

This package offers Qt bindings for D, and depends heavily on DSMOKE.


## Updates

Check out [the wiki](https://github.com/w0rp/dqt/wiki) for a summary of project status, what I'm working on, etc.

## Quick Start

The project structure isn't configured in a great way quite yet, so do this.

```sh
# Build with DUB, which will generate the source files.
dub build
# ... Okay now do it again because DUB didn't detect the source files.
dub build
```

After that, supposing dsmoke is in the parent directory of dqt, and your
machine is a Linux machine configured like mine is, you can run a Hello World
with this.

```
# You will need Qt4 headers and such for this.
# It's probably bust to just open this script up and tweak it to
# get it running for now.
examples/run_hello_world
```
