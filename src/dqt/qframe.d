module dqt.qframe;

import dqt.global;
import dqt.qtguienum;
import dqt.qobject;
import dqt.qwidget;

private:

MethodFunctor qFrameCTOR;
MethodFunctor qFrameDTOR;

shared static this() {
    auto cls = qtSmokeLoader.demandClass("QFrame");

    qFrameCTOR = cls.demandMethod("QFrame",
        "QWidget*", "QFlags<Qt::WindowType>");
    qFrameDTOR = cls.demandMethod("~QFrame");
}

public:

class QFrame : QWidget {
package:
    this(Nothing nothing) {
        super(Nothing.init);
    }
public:
    this(QWidget parent = null, WindowType f = WindowType.Widget) {
        this(Nothing.init);

        _data = qFrameCTOR(null, parent.dataOrNull, cast(int) f).s_voidp;
    }

    ~this() {
        if (_data !is null) {
            qFrameDTOR(_data);
            _data = null;
        }
    }
}
