#include <QtGui/QLabel>
#include <QtCore/QString>

#include "dqt_qlabel.h"

void* dqt_QLabel_ctor_QWidget_WindowType(void* parent, int f) {
    return new QLabel(
        static_cast<QWidget*>(parent),
        static_cast<Qt::WindowType>(f)
    );
}

void* dqt_QLabel_ctor_QString_QWidget_WindowType(
    const char * characters, size_t characterLength, void* parent, int f) {
    return new QLabel(
        QString::fromUtf8(characters, characterLength),
        static_cast<QWidget*>(parent),
        static_cast<Qt::WindowType>(f)
    );
}

