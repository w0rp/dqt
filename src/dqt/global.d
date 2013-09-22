module dqt.global;

import dqt.smoke.all;

package:

public import dqt.smoke.smokeqt_loader :
    MethodFunctor, ClassData, QStringHandle;

SmokeLoader qtSmokeLoader;

enum Nothing : byte { nothing }

shared static this() {
    qtSmokeLoader = SmokeLoader(QtLibraryFlag.all);
}
