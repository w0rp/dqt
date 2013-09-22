module dqt.qapplication;

import dqt.global;
import dqt.qcoreapplication;
import dqt.qobject;

private:

MethodFunctor qApplicationCTOR;
MethodFunctor qApplicationDTOR;
MethodFunctor qApplicationExec;

shared static this() {
    qApplicationCTOR = qtSmokeLoader.demandMethod(
        "QApplication", "QApplication", "int&", "char**");
    qApplicationDTOR = qtSmokeLoader.demandMethod(
        "QApplication", "~QApplication");
    qApplicationExec = qtSmokeLoader.demandMethod(
        "QApplication", "exec");
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
