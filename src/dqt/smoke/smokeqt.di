module dqt.smoke.smokeqt;

import dqt.smoke.smoke;

// Qt base.

// This and other globals are declared like so:
// SMOKE_EXPORT Smoke* qt_Smoke;
extern(C) Smoke qt_Smoke;
extern(C) void init_qt_Smoke();
extern(C) void delete_qt_Smoke();

// QtCore

extern(C) Smoke qtcore_Smoke;
extern(C) void init_qtcore_Smoke();
extern(C) void delete_qtcore_Smoke();

// QtGUI

extern(C) Smoke qtgui_Smoke;
extern(C) void init_qtgui_Smoke();
extern(C) void delete_qtgui_Smoke();
