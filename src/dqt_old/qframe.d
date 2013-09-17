module dqt.qframe;

import dqt.cppwrapper.qframe;

import dqt.qobject;
import dqt.qwidget;
import dqt.qtguienum;

class QFrame : QWidget {
package:
    this() {}
public:
    this(QWidget parent = null, WindowType f = WindowType.Widget) {
        _data = dqt_QFrame_ctor_QWidget_WindowType(
            parent._safeData, f);
    }
}
