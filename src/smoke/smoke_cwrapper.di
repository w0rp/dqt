module smoke.smoke_cwrapper;

import core.stdc.config : c_long, c_ulong;

import smoke.smoke;

// Declare C wrapper functions.

// QtCore

extern(C) extern __gshared void dqt_init_qtcore_Smoke();
extern(C) extern __gshared void dqt_delete_qtcore_Smoke();
extern(C) extern __gshared void* dqt_fetch_qtcore_Smoke();

// QtGUI

extern(C) extern __gshared void dqt_init_qtgui_Smoke();
extern(C) extern __gshared void dqt_delete_qtgui_Smoke();
extern(C) extern __gshared void* dqt_fetch_qtgui_Smoke();

extern(C) extern __gshared void dqt_bind_instance(void* classFn, void* object);

extern(C) extern __gshared void* dqt_init_QString_utf16_reference(const(short)* data, int size);
extern(C) extern __gshared void* dqt_init_QString_utf8_copy(const(char)* data, int size);
extern(C) extern __gshared void dqt_delete_QString(void* qString);
