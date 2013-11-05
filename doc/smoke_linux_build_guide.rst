w0rp's Linux GCC smokeqt build guide
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

Install the latest Qt 4.8 (or whatever you want) via your package manager.

Install CMake.

You'll be running dealing with libraries you compiled yourself, so
make sure that the directory is in your path, e.g. ::
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib"

Clone the smoke repositories ::
    git clone git://anongit.kde.org/smokegen
    git clone git://anongit.kde.org/smokeqt

Build smokegen ::
    cd smokegen
    cmake .
    make

Now install everything that was built (Run as root) ::
    make install

Run cmake again in the smokeqt directory ::
    cd ..\smokeqt
    cmake .
    make

If you get an error about cppwrapper.so being missing, that means
you need to update your *LD_LIBRARY_PATH* to include it. Look at the
output of *make install* for smokegen to find out where it puts it.

Now install everything that was built. ::
    make install

