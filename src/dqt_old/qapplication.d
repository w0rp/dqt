module dqt.qapplication;

import dqt.global;
import dqt.qcoreapplication;
import dqt.qobject;

private:

MethodFunctor qApplicationCTOR;
MethodFunctor qApplicationDTOR;
MethodFunctor qApplicationExec;

shared static this() {
    auto cls = qtSmokeLoader.demandClass("QApplication");

    qApplicationCTOR = cls.demandMethod(
        "QApplication", "int&", "char**");
    qApplicationDTOR = cls.demandMethod("~QApplication");
    qApplicationExec = cls.demandMethod("exec");
}

public:

final class QApplication : QCoreApplication {
package:
    // Implemented purely so the no argument constructor can be skipped.
    this(Nothing nothing) {
        super(Nothing.init);
    }
public:
    static int exec() {
        return qApplicationExec(null).s_int;
    }

    this(ref int argc, char** argv) {
        this(Nothing.init);

        _data = qApplicationCTOR(null, &argc, argv).s_voidp;
    }

    ~this() {
        if (_data !is null) {
            qApplicationDTOR(_data);
            _data = null;
        }
    }
}
