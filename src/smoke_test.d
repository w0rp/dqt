import dqt.smoke.all;
import dqt.smoke.smoke_cwrapper;

pragma(lib, "smokebase_implib.lib");
pragma(lib, "smoke_cwrapper_implib.lib");

int main() {
    import core.runtime;
    import std.stdio;
    import std.string;

    auto loader = SmokeLoader(QtLibraryFlag.all);

    auto appCtor = loader.demandMethod(
        "QApplication", "QApplication", "int&", "char**");

    auto appExec = loader.demandMethod(
        "QApplication", "exec");

    auto labelCtor = loader.demandMethod("QLabel", "QLabel",
       "const QString&", "QWidget*", "QFlags<Qt::WindowType>");

    auto showMethod = loader.demandMethod("QWidget", "show");

    auto cArgs = Runtime.cArgs;

    auto app = appCtor(null, &cArgs.argc, cArgs.argv).s_voidp;

    wstring hello = "Hello DQT!";

    auto helloQString = dqt_init_QString_reference(
        cast(const(short)*) hello.ptr, hello.length);

    scope(exit)
        dqt_delete_QString_reference(helloQString);

    auto label = labelCtor(null, helloQString, null, 0).s_voidp;

    showMethod(label);

    return appExec(null).s_int;
}
