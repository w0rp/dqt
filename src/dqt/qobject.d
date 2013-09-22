module dqt.qobject;

import dqt.global;

private:

MethodFunctor qObjectCTOR;
MethodFunctor qObjectDTOR;
MethodFunctor qObjectParent;

shared static this() {
    auto cls = qtSmokeLoader.demandClass("QObject");

    qObjectCTOR = cls.demandMethod("QObject", "QObject*");
    qObjectDTOR = cls.demandMethod("~QObject");
    qObjectParent = cls.demandMethod("parent");
}

package:

@safe pure nothrow
package void* dataOrNull(QObject object) {
    return object !is null ? object._data : null;
}

public:

class QObject {
package:
    void* _data;

    this(Nothing nothing) {}
public:
    this(QObject parent = null) {
        _data = qObjectCTOR(null, parent.dataOrNull).s_voidp;
    }

    ~this() {
        if (_data !is null) {
            qObjectDTOR(_data);
            _data = null;
        }
    }

    @property
    QObject parent() {
        void* parent = qObjectParent(_data).s_voidp;

        if (parent == null) {
            return null;
        }

        // TODO: Object identity problem is created here.
        // the is operator won't work properly!
        QObject parentObject = new QObject();
        parentObject._data = parent;

        return parentObject;
    }

}
