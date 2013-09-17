module dqt.qcoreapplication;

import dqt.cppwrapper.qcoreapplication;

import dqt.qobject;

class QCoreApplication : QObject {
package:
    // Implemented purely so the no argument constructor can be skipped.
    this(Nothing nothing) {}
public:
    this(int* argc, char** argv) {
        _data = dqt_QCoreApplication_ctor_int_charSS(argc, argv);
    }

    this() {
        import core.runtime;

        CArgs args = Runtime.cArgs;

        this(&args.argc, args.argv);
    }


    final void exit(int returnCode = 0) {
        dqt_QCoreApplication_exit(returnCode);
    }

    final int exec() {
        return dqt_QCoreApplication_exec();
    }
}
