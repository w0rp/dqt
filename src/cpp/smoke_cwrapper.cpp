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
        return 0;
    }
};

SMOKEC_EXPORT void dqt_bind_instance(void* classFn, void* object) {
    Smoke::StackItem bindingStack[2];

    bindingStack[1].s_voidp = &NullBinding::getInstance();

    return reinterpret_cast<Smoke::ClassFn>(classFn)(0, object, bindingStack);
}

SMOKEC_SPEC void* dqt_init_QString_utf16_reference(const short* data, int size) {
    // fromRawData creates a QString from UTF-16 data without copying it.
    // QString(const QString&) creates a QString without copying the data.
    // We put this non-copy on the heap so D can use it.

    return new QString(
        QString::fromRawData(reinterpret_cast<const QChar*>(data), size));
}

SMOKEC_SPEC void* dqt_init_QString_utf8_copy(const char* data, int size) {
    return new QString(
        QString::fromUtf8(data, size));
}

SMOKEC_SPEC void dqt_delete_QString(void* qString) {
    delete static_cast<QString*>(qString);
}
