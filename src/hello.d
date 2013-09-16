import dqt.qtcore;
import dqt.qtgui;

pragma(lib, "dqt_cpp_wrapper.lib");

int main() {
    auto app = new QApplication();

    auto label = new QLabel("Hello World!");

    label.show();

    return app.exec();
}
