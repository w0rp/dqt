import dqt.smoke.all;

pragma(lib, "smokebase_implib.lib");
pragma(lib, "smoke_cwrapper_implib.lib");

int main() {
    import core.runtime;
    import std.stdio;

    auto loader = SmokeLoader(QtLibraryFlag.all);

    auto appCtor = loader.demandMethod(
        "QApplication", "QApplication", "int&", "char**");

    auto appExec = loader.demandMethod(
        "QCoreApplication", "exec");

    auto widgetCtor = loader.demandMethod("QWidget", "QWidget",
       "QWidget*", "QFlags<Qt::WindowType>");

    auto showMethod = loader.demandMethod("QWidget", "show");

    auto cArgs = Runtime.cArgs;

    writeln(appCtor.method.flags);
    writeln(appCtor.method.numArgs);
    writeln(appCtor.name);

    auto app = appCtor(null, &cArgs.argc, cArgs.argv).s_voidp;

    auto widget = widgetCtor(null, null, 0).s_voidp;

    showMethod(widget);

    // Almost works...

    appExec(null);

    return 0;
}
