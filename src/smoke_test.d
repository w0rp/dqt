import dqt.qtcore;
import dqt.qtgui;

version(Windows) {
    pragma(lib, "smokebase_implib.lib");
    pragma(lib, "smoke_cwrapper_implib.lib");
}

int main() {
    import core.runtime;
    import std.stdio;

    auto cArgs = Runtime.cArgs;

    auto app = new QApplication(cArgs.argc, cArgs.argv);

    writeln("test");
    stdout.flush();

    auto x = "Hello World";

    auto label = new QLabel(x);

    label.show();

    return QApplication.exec();
}
