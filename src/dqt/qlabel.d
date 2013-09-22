module dqt.qlabel;

import dqt.global;
import dqt.qobject;
import dqt.qwidget;
import dqt.qframe;
import dqt.qtguienum;

private:

MethodFunctor qLabelCTOR;
MethodFunctor qLabelDTOR;

shared static this() {
    qLabelCTOR = qtSmokeLoader.demandMethod("QLabel", "QLabel",
       "const QString&", "QWidget*", "QFlags<Qt::WindowType>");
    qLabelDTOR = qtSmokeLoader.demandMethod("QLabel", "~QLabel");
}

public:

class QLabel : QFrame {
package:
    this(Nothing nothing) {
        super(Nothing.init);
    }
public:
    this(wstring text, QWidget parent = null, WindowType f = WindowType.Widget) {
        this(Nothing.init);

        auto textQString = QStringHandle(text);

        _data = qLabelCTOR(null, textQString.ptr,
            parent.dataOrNull, cast(int) f).s_voidp;
    }

    ~this() {
        if (_data !is null) {
            qLabelDTOR(_data);
            _data = null;
        }
    }
}
