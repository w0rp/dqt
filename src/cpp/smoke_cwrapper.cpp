#include "smoke_cwrapper.h"
#include "smoke.h"
#include "qtcore_smoke.h"
#include "qtgui_smoke.h"

// We need our __declspec for function defintions, too.
#if defined(_WIN32)
    #define SMOKEC_EXPORT __declspec(dllexport)
#else
    #define SMOKEC_EXPORT
#endif

// The function definitions pretty much just
// cast things around and call the right methods.

SMOKEC_EXPORT void dqt_init_qtcore_Smoke() {
    init_qtcore_Smoke();
}

SMOKEC_EXPORT void dqt_delete_qtcore_Smoke() {
    delete_qtcore_Smoke();
}

SMOKEC_EXPORT void* dqt_fetch_qtcore_Smoke() {
    return qtcore_Smoke;
}

SMOKEC_EXPORT void dqt_init_qtgui_Smoke() {
    init_qtgui_Smoke();
}

SMOKEC_EXPORT void dqt_delete_qtgui_Smoke() {
    delete_qtgui_Smoke();
}

SMOKEC_EXPORT void* dqt_fetch_qtgui_Smoke() {
    return qtgui_Smoke;
}

SMOKEC_EXPORT void dqt_call_ClassFn(void* classFn, short method, void* obj, void* args) {
    static_cast<Smoke::ClassFn>(classFn)(method, obj, static_cast<Smoke::Stack>(args));
}

SMOKEC_EXPORT void* dqt_call_CastFn(void* castFn, void* obj, short from, short to) {
    return static_cast<Smoke::CastFn>(castFn)(obj, from, to);
}

SMOKEC_EXPORT void dqt_call_EnumFn(void* enumFn, int enumOperation, short index, void** ptrRef, long* longRef) {
    static_cast<Smoke::EnumFn>(enumFn)(
        static_cast<Smoke::EnumOperation>(enumOperation),
        index,
        *ptrRef,
        *longRef
    );
}

