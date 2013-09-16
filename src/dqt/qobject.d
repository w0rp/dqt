module dqt.qobject;

import dqt.cppwrapper.qobject;

class QObject {
    package void* _data;
    private bool _unmanaged;

package:
    this() {}
public:
    @safe pure nothrow
    package this(void* data) {
        _data = data;
        _unmanaged = true;
    }

    this(QObject parent = null) {
        _data = dqt_QObject_ctor_QObject(parent._safeData);
    }

    ~this() {
        if (!_unmanaged && _data !is null) {
            dqt_delete(_data);
        }
    }
}

@safe pure nothrow
package void* _safeData(QObject object) {
    return object !is null ? object._data : null;
}

package class Nothing {}
