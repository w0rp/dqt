module dqt.qwidget;

import dqt.global;
import dqt.qtguienum;
import dqt.qobject;
import dqt.qpaintdevice;

private:

MethodFunctor qWidgetCTOR;
MethodFunctor qWidgetDTOR;
MethodFunctor qWidgetShow;

shared static this() {
    qWidgetCTOR = qtSmokeLoader.demandMethod("QWidget", "QWidget",
        "QWidget*", "QFlags<Qt::WindowType>");
    qWidgetDTOR = qtSmokeLoader.demandMethod("QWidget", "~QWidget");
    qWidgetShow = qtSmokeLoader.demandMethod("QWidget", "show");
}

public:

class QWidget : QObject, QPaintDevice {
package:
    this(Nothing nothing) {
        super(Nothing.init);
    }
public:
    this(QWidget parent = null, WindowType f = WindowType.Widget) {
        this(Nothing.init);

        _data = qWidgetCTOR(null, parent.dataOrNull, cast(int) f).s_voidp;
    }

    ~this() {
        if (_data !is null) {
            qWidgetDTOR(_data);
            _data = null;
        }
    }

    final void show() {
        qWidgetShow(_data);
    }
}
