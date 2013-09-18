w0rp's Visual Studio smokeqt build guide
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

Special thanks to burel on IRC
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

Install the latest Qt 4.8 (or whatever you want) for Windows (VS 2010) ::
    https://qt-project.org/downloads

Put the Qt bin directory in your PATH.

Install msbuild.exe, or Visual Studio, 2010 or above.

Install CMake.

Clone the smoke repositories ::
    git clone git://anongit.kde.org/smokegen
    git clone git://anongit.kde.org/smokeqt

Use CMake to set up smokegen ::
    cd smokegen
    cmake .

Build the project for Release with msbuild (or use Visual Studio) ::
    msbuild smokegenerator.sln /p:Configuration=Release

Now install everything that was built (Run as admin) ::
    cmake -P cmake_install.cmake

Run cmake again in the smokeqt directory, pointing at smokegen's files ::
    cd ..\smokeqt
    cmake -DSmoke_DIR=<put your absolute path here>\smokegen\cmake .

Build the project for Release with msbuild (or use Visual Studio) ::
    msbuild SMOKEQT4.sln /p:Configuration=Release

Now install the smokeqt stuff ::
    cmake -P cmake_install.cmake

The above install command will dump it to the root directory of the drive
you are on, but you can go ahead and move that into the same place
smokegen installed to in Program Files.

