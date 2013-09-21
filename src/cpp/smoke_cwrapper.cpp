#include <QString>

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

class NullBinding : public SmokeBinding {
private:
    NullBinding() : SmokeBinding(NULL) {}
    NullBinding(const NullBinding &);
    void operator=(const NullBinding &);
public:
    static NullBinding& getInstance() {
        static NullBinding instance;

        return instance;
    }

    virtual void deleted(Smoke::Index classId, void *obj)  {}

    virtual bool callMethod(Smoke::Index method, void *obj, Smoke::Stack args,
    bool isAbstract = false) {
        return false;
    }

    virtual char* className(Smoke::Index classId) {
        return "";
    }
};

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

SMOKEC_EXPORT void dqt_call_ClassFn(void* classFn, short method, void* obj,
void* args) {
    static_cast<Smoke::ClassFn>(classFn)(
        method, obj, static_cast<Smoke::Stack>(args));
}

SMOKEC_EXPORT void* dqt_call_CastFn(void* castFn, void* obj, short from,
short to) {
    return static_cast<Smoke::CastFn>(castFn)(obj, from, to);
}

SMOKEC_EXPORT void dqt_call_EnumFn(void* enumFn, int enumOperation,
short index, void** ptrRef, long* longRef) {
    static_cast<Smoke::EnumFn>(enumFn)(
        static_cast<Smoke::EnumOperation>(enumOperation),
        index,
        *ptrRef,
        *longRef
    );
}

SMOKEC_EXPORT void dqt_bind_instance(void* classFn, void* object) {
    Smoke::StackItem bindingStack[2];

    bindingStack[1].s_voidp = &NullBinding::getInstance();

    return static_cast<Smoke::ClassFn>(classFn)(0, object, bindingStack);
}

SMOKEC_SPEC void* dqt_init_QString_reference(const short* data, int size) {
    // fromRawData creates a QString from UTF-16 data without copying it.
    // QString(const QString&) creates a QString without copying the data.
    // We put this non-copy on the heap so D can use it.

    return new QString(
        QString::fromRawData(reinterpret_cast<const QChar*>(data), size));
}

SMOKEC_SPEC void dqt_delete_QString_reference(void* qString) {
    delete static_cast<QString*>(qString);
}

