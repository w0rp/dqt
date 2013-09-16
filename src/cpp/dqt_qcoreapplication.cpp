#include <QtCore/QCoreApplication>

#include "dqt_qcoreapplication.h"

#include <iostream>

void* dqt_QCoreApplication_ctor_int_charSS(int* argc, char** argv) {
    std::cout << "Calling QCoreApplication ctor!" << std::endl;

    return new QCoreApplication(*argc, argv);
}

void dqt_QCoreApplication_exit(int returnCode) {
    qApp->exit(returnCode);
}

int dqt_QCoreApplication_exec() {
    return qApp->exec();
}

