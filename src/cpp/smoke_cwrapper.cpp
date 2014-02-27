#include <QString>

#include "smoke_cwrapper.h"

// We need our __declspec for function defintions, too.
#if defined(_WIN32)
    #define SMOKEC_EXPORT __declspec(dllexport)
#else
    #define SMOKEC_EXPORT
#endif

SMOKEC_SPEC void* dqt_init_QString_utf16_reference(const short* data, int size) {
    // fromRawData creates a QString from UTF-16 data without copying it.
    // QString(const QString&) creates a QString without copying the data.
    // We put this non-copy on the heap so D can use it.

    return new QString(
        QString::fromRawData(reinterpret_cast<const QChar*>(data), size));
}

SMOKEC_SPEC void* dqt_init_QString_utf8_copy(const char* data, int size) {
    return new QString(
        QString::fromUtf8(data, size));
}

SMOKEC_SPEC void dqt_delete_QString(void* qString) {
    delete static_cast<QString*>(qString);
}
