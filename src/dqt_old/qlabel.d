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
    auto cls = qtSmokeLoader.demandClass("QLabel");

    qLabelCTOR = cls.demandMethod("QLabel", "const QString&",
        "QWidget*", "QFlags<Qt::WindowType>");
    qLabelDTOR = cls.demandMethod("~QLabel");
}

public:

class QLabel : QFrame {
private:
    this(QStringHandle text, QWidget parent = null, WindowType f = WindowType.Widget) {
        this(Nothing.init);

        _data = qLabelCTOR(null, text.ptr,
            parent.dataOrNull, cast(int) f).s_voidp;
    }
package:
    this(Nothing nothing) {
        super(Nothing.init);
    }
public:
    this(wstring text, QWidget parent = null, WindowType f = WindowType.Widget) {
        this(QStringHandle(text), parent, f);
    }

    this(string text, QWidget parent = null, WindowType f = WindowType.Widget) {
        this(QStringHandle(text), parent, f);
    }

    ~this() {
        if (_data !is null) {
            qLabelDTOR(_data);
            _data = null;
        }
    }
}
