import dqt.qtcore;
import dqt.qtgui;

int main() {
    import core.runtime;

    auto cArgs = Runtime.cArgs;

    auto app = new QApplication(cArgs.argc, cArgs.argv);

    auto x = "Hello World";

    auto label = new QLabel(x);

    label.show();

    return QApplication.exec();
}
