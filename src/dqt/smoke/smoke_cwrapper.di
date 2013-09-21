module dqt.smoke.smoke_cwrapper;

import core.stdc.config : c_long, c_ulong;

import dqt.smoke.smoke;

// Declare C wrapper functions.

// QtCore

extern(C) extern __gshared void dqt_init_qtcore_Smoke();
extern(C) extern __gshared void dqt_delete_qtcore_Smoke();
extern(C) extern __gshared void* dqt_fetch_qtcore_Smoke();

// QtGUI

extern(C) extern __gshared void dqt_init_qtgui_Smoke();
extern(C) extern __gshared void dqt_delete_qtgui_Smoke();
extern(C) extern __gshared void* dqt_fetch_qtgui_Smoke();

// In case calling conventions fail us, we can call these functions.

extern(C) extern __gshared void dqt_call_ClassFn(
    void* classFn, short method, void* obj, void* args);
extern(C) extern __gshared void* dqt_call_CastFn(
    void* castFn, void* obj, short from, short to);
extern(C) extern __gshared void dqt_call_EnumFn(
    void* enumFn, int enumOp, short index, void** ptrRef, c_long* longRef);

extern(C) extern __gshared void dqt_bind_instance(void* classFn, void* object);
