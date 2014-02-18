module dqt.qstring;

import smoke.smoke_cwrapper;

struct QStringHandle {
private:
    void* _ptr;
public:
    @property @safe nothrow
    void* ptr() {
        return _ptr;
    }

    @disable this();
    @disable this(this);

    this(wstring text) {
        _ptr = dqt_init_QString_utf16_reference(
            cast(const(short*)) text.ptr, cast(int) text.length);
    }

    this(string text) {
        _ptr = dqt_init_QString_utf8_copy(text.ptr, cast(int) text.length);
    }

    ~this() {
        dqt_delete_QString(_ptr);
    }
}
