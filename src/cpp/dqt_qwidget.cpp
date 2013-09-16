#include <QtGui/QWidget>

#include "dqt_qwidget.h"

void* dqt_QWidget_ctor_QWidget_WindowType(void* parent, int f) {
    return new QWidget(
        static_cast<QWidget*>(parent),
        static_cast<Qt::WindowType>(f)
    );
}

void dqt_QWidget_show(void* qwidget) {
    static_cast<QWidget*>(qwidget)->show();
}

