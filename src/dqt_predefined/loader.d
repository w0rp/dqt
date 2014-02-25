module dqt.loader;

import smoke.smoke;
import smoke.smokeqt;

public import smoke.smoke_loader;

package immutable(SmokeLoader) smokeLoader;

shared static this() {
    // Just create these and never delete them.
    // They will die when the program dies.
    init_qtcore_Smoke();
    init_qtgui_Smoke();

    smokeLoader = SmokeLoader.create(qtcore_Smoke, qtgui_Smoke);
}
