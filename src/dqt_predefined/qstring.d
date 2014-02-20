module dqt.qstring;

import smoke.smoke;
import smoke.smoke_cwrapper;

package struct QStringInputWrapper {
    void* _data;

    @disable this();
    @disable this(this);

    this(ref const(string) text) {
        _data = dqt_init_QString_utf8_copy(text.ptr, cast(int) text.length);
    }

    ~this() {
        dqt_delete_QString(_data);
    }
}

package string qstringOutputWrapper(Smoke.StackItem) {
    return "";
}
