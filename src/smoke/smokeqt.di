module smoke.smokeqt;

import smoke.smoke;

/// This global will contain all of the SMOKE data for QtCore.
extern(C) extern __gshared Smoke* qtcore_Smoke;

/// Call this function to load the qtcore global data.
extern(C) extern void init_qtcore_Smoke();

/// Call this function to delete the qtcore global data.
extern(C) extern void delete_qtcore_Smoke();

/// This global will contain all of the SMOKE data for QtCore.
extern(C) extern __gshared Smoke* qtgui_Smoke;

/// Call this function to load the qtgui global data.
extern(C) extern void init_qtgui_Smoke();

/// Call this function to delete the qtgui global data.
extern(C) extern void delete_qtgui_Smoke();
