TEMPLATE=lib

SOURCES += ../src/cpp/*.cpp
HEADERS += ../src/cpp/*.h
DEFINES += QTD_DLL_WRAPPER_BUILD
DESTDIR = ../bin

win32 {
    # On Windows, we need to convert the lib file so DMC can use it.
    QMAKE_POST_LINK += ..\\tool\\coffimplib.exe -f ..\\bin\\dqt_cpp_wrapper.lib
}
