#include <QtCore/QObject>

#include "dqt_qobject.h"

void* dqt_QObject_ctor_QObject(void* parent) {
    return new QObject(static_cast<QObject*>(parent));
}

void dqt_delete(void* object) {
    QObject* obj = static_cast<QObject*>(object);

    delete obj;
}

