#ifndef __DQT_QCOREAPPLICATION_H_
#define __DQT_QCOREAPPLICATION_H_

#include "dqt_common.h"

extern "C" {

DQT_DECL void* dqt_QCoreApplication_ctor_int_charSS(int* argc, char** argv);
DQT_DECL void dqt_QCoreApplication_exit(int returnCode);
DQT_DECL int dqt_QCoreApplication_exec();

}

#endif

