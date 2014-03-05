import dqt.qtcore;
import dqt.qtgui;

int main() {
    import core.runtime;

    auto cArgs = Runtime.cArgs;

    auto app = new QApplication(cArgs.argc, cArgs.argv);

    auto label = new QLabel("Hello World");

    label.show();

    return QApplication.exec();
}
