module dqt.qlabel;

import dqt.cppwrapper.qlabel;

import dqt.qobject;
import dqt.qwidget;
import dqt.qframe;
import dqt.qtguienum;

class QLabel : QFrame {
package:
    this() {}
public:
    this(QWidget parent = null, WindowType f = WindowType.Widget) {
        _data = dqt_QLabel_ctor_QWidget_WindowType(
            parent._safeData, f);
    }

    this(string text, QWidget parent = null, WindowType f = WindowType.Widget) {
        _data = dqt_QLabel_ctor_QString_QWidget_WindowType(
            text.ptr, text.length, parent._safeData, f);
    }
}
