module dqt.global;

import dqt.smoke.all;

package:

public import dqt.smoke.smokeqt_loader : MethodFunctor, QStringHandle;

SmokeLoader qtSmokeLoader;

class Nothing {}

shared static this() {
    qtSmokeLoader = SmokeLoader(QtLibraryFlag.all);
}
