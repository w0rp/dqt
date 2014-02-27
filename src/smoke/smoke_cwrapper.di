module smoke.smoke_cwrapper;

import core.stdc.config : c_long, c_ulong;

import smoke.smoke;

extern(C) extern void* dqt_init_QString_utf16_reference(const(short)* data, int size);
extern(C) extern void* dqt_init_QString_utf8_copy(const(char)* data, int size);
extern(C) extern void dqt_delete_QString(void* qString);
