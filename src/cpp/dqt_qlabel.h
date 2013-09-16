#ifndef __DQT_QLABEL_H_
#define __DQT_QLABEL_H_

#include "dqt_common.h"

extern "C" {

DQT_DECL void* dqt_QLabel_ctor_QWidget_WindowType(void* parent, int f);
DQT_DECL void* dqt_QLabel_ctor_QString_QWidget_WindowType(
    const char * characters, size_t characterLength, void* parent, int f);

}

#endif

