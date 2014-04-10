import dqt.qtcore;
import dqt.qtgui;

int main() {
    import core.runtime;
    import std.stdio;

    auto cArgs = Runtime.cArgs;
    auto app = new QApplication(cArgs.argc, cArgs.argv);

    QMainWindow mainWindow = new QMainWindow();

    auto mainWidget = new QWidget(mainWindow);
    mainWindow.setCentralWidget(mainWidget);

    auto layout = new QGridLayout(mainWidget);

    auto addButton(string label, int row, int column) {
        auto button = new QPushButton(label);

        layout.addWidget(button, row, column);

        return button;
    }

    addButton("7", 0, 0);
    addButton("8", 0, 1);
    addButton("9", 0, 2);
    addButton("4", 1, 0);
    addButton("5", 1, 1);
    addButton("6", 1, 2);
    addButton("1", 2, 0);
    addButton("2", 2, 1);
    addButton("3", 2, 2);

    mainWindow.show();

    return QApplication.exec();
}
