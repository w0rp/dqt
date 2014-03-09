module dqt.qstring;

import smoke.smoke;

// Declare functions defined in C++.
extern(C) void* dqt_init_QString_utf16_reference(const(short)* data, int size);
extern(C) void* dqt_init_QString_utf8_copy(const(char)* data, int size);
extern(C) void dqt_delete_QString(void* qString);

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
