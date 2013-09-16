#include <QtGui/QFrame>

#include "dqt_qframe.h"

void* dqt_QFrame_ctor_QWidget_WindowType(void* parent, int f) {
    return new QFrame(
        static_cast<QWidget*>(parent),
        static_cast<Qt::WindowType>(f)
    );
}

