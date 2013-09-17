module dqt.qwidget;

import dqt.cppwrapper.qwidget;

import dqt.qobject;
import dqt.qpaintdevice;
import dqt.qtguienum;

class QWidget : QObject, QPaintDevice {
package:
    this() {}
public:
    this(QWidget parent = null, WindowType f = WindowType.Widget) {
        _data = dqt_QWidget_ctor_QWidget_WindowType(
            parent._safeData, f);
    }

    final void show() {
        dqt_QWidget_show(_data);
    }
}
