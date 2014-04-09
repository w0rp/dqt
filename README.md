DQt
===

This package offers Qt bindings for D, and depends heavily on DSMOKE.

## Updates

Check out [the wiki](https://github.com/w0rp/dqt/wiki) for a summary of project status, what I'm working on, etc.

## Dependencies

In order to build this project, you will need the following.

1. DMD and a recent version of GCC or similar.
2. A recent Qt 4 version, like Qt 4.8
2. A smokeqt version matching the Qt version will need to be installed.
3. *dub* will be needed for building parts of the library.
3. [dstruct](https://github.com/w0rp/dstruct)
4. [dsmoke](https://github.com/w0rp/dsmoke)

## Quick Start

If you want to get up and running with the latest code, do this.

```sh
# Assume Qt4, smokeqt, dub, and other build tools are installed.

cd some_directory_you_want

git clone git@github.com:w0rp/dsmoke.git
git clone git@github.com:w0rp/dstruct.git
git clone git@github.com:w0rp/dqt.git

cd dqt
```

Now you should hopefully have everything you need to build the library.

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
