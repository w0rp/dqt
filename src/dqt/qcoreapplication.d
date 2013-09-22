module dqt.qcoreapplication;

import dqt.global;
import dqt.qobject;

private:

MethodFunctor qCoreApplicationCTOR;
MethodFunctor qCoreApplicationDTOR;
MethodFunctor qCoreApplicationExec;

shared static this() {
    auto cls = qtSmokeLoader.demandClass("QCoreApplication");

    qCoreApplicationCTOR = cls.demandMethod(
        "QCoreApplication", "int&", "char**");
    qCoreApplicationDTOR = cls.demandMethod(
        "~QCoreApplication");
    qCoreApplicationExec = cls.demandMethod(
        "exec");
}

public:

class QCoreApplication : QObject {
package:
    // Implemented purely so the no argument constructor can be skipped.
    this(Nothing nothing) {
        super(Nothing.init);
    }
public:
    static int exec() {
        return qCoreApplicationExec(null).s_int;
    }

    this(ref int argc, char** argv) {
        this(Nothing.init);

        _data = qCoreApplicationCTOR(null, &argc, argv).s_voidp;
    }

    ~this() {
        if (_data !is null) {
            qCoreApplicationDTOR(_data);
            _data = null;
        }
    }
}
