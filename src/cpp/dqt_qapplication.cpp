#include <QApplication>

#include "dqt_qapplication.h"

void* dqt_QApplication_ctor_int_charSS(int* argc, char** argv) {
    return new QApplication(*argc, argv);
}

