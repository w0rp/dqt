module dqt.qapplication;

import dqt.cppwrapper.qapplication;

import dqt.qcoreapplication;
import dqt.qobject;

final class QApplication : QCoreApplication {
    this(int* argc, char** argv) {
        // Skip the no argument super constructor.
        super(cast(Nothing) null);

        _data = dqt_QApplication_ctor_int_charSS(argc, argv);
    }

    this () {
        super(cast(Nothing) null);

        import core.runtime;

        CArgs args = Runtime.cArgs;
        _data = dqt_QApplication_ctor_int_charSS
            (&args.argc, args.argv);
    }
}
