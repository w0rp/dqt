import dqt.qtcore;
import dqt.qtgui;

pragma(lib, "smokebase_implib.lib");
pragma(lib, "smoke_cwrapper_implib.lib");

int main() {
    import core.runtime;

    auto cArgs = Runtime.cArgs;

    auto app = new QApplication(cArgs.argc, cArgs.argv);

    auto label = new QLabel("Hello DQt!");

    label.show();

    return QApplication.exec();
}
