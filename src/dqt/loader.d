
import smoke.smoke;
import smoke.smoke_cwrapper;

public import smoke.smoke_loader;

immutable(SmokeLoader) smokeLoader;

shared static this() {
    // Just create these and never delete them.
    // They will die when the program dies.
    dqt_init_qtcore_Smoke();
    dqt_init_qtgui_Smoke();

    smokeLoader = SmokeLoader.create(
        cast(Smoke*) dqt_fetch_qtcore_Smoke(),
        cast(Smoke*) dqt_fetch_qtgui_Smoke()
    );
}
