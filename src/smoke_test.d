import dqt.smoke.all;

pragma(lib, "smokebase_implib.lib");
pragma(lib, "smoke_cwrapper_implib.lib");

int main() {
    smokeqtLoad();

    scope(exit) smokeqtUnload();

    return 0;
}
