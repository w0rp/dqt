import smoke.smoke;
import smoke.smoke_cwrapper;
import smoke.smoke_container;
import smoke.smoke_generator;
import smoke.smoke_loader;

import std.algorithm;
import std.string;
import std.array;

immutable(SmokeContainer) loadQtSmokeContainer() {
    dqt_init_qtcore_Smoke();
    scope(exit) dqt_delete_qtcore_Smoke();
    dqt_init_qtgui_Smoke();
    scope(exit) dqt_delete_qtgui_Smoke();

    return SmokeContainer.create(
        cast(Smoke*) dqt_fetch_qtcore_Smoke(),
        cast(Smoke*) dqt_fetch_qtgui_Smoke()
    );
}

void main() {
    auto container = loadQtSmokeContainer();

    auto generator = SmokeGenerator();

    // A function for producing D types.
    generator.basicDTypeFunc = (type) {
        string mappedType(string cppString) {
            if (cppString.startsWith("QFlags")) {
                return cppString[7 .. $ - 1];
            }

            return cppString;
        }

        return mappedType(type.unqualifiedTypeString).replace("::", ".");
    };

    generator.blackListFunc = (type) {
        string cppString = type.unqualifiedTypeString;

        // Don't generate anything mentioning QList, we will have to handle
        // QList specially as it's a template class.
        if (cppString.countUntil("QList") >= 0) {
            return true;
        }

        return false;
    };

    generator.moduleName = "dqt";

    generator.writeToDirectory(container, "output");
}
