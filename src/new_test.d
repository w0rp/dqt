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

            if (cppString == "QString") {
                return "string";
            }

            return cppString;
        }

        return mappedType(type.unqualifiedTypeString).replace("::", ".");
    };

    generator.classBlackListFunc = (cls) {
        switch (cls.name) {
        case "QIconEngineV2":
        case "QGraphicsLayout":
            return true;
        default:
            return false;
        }
    };

    generator.blackListFunc = (type) {
        string cppString = type.unqualifiedTypeString;

        switch (cppString) {
        case "QStringList":
        case "FT_FaceRec_":
        case "_XDisplay":
        case "_XEvent":
        case "_XRegion":
        // TODO: Handle QChar with a wrapper.
        case "QChar":
        // TODO: Write an implementation of this.
        case "QStyleOption":
        // TODO: These were just missing...
        case "Qt::HitTestAccuracy":
        case "QGraphicsScene::SceneLayers":
            return true;
        default: break;
        }

        // Filter out template types
        if (cppString.countUntil("<") >= 0) {
            return true;
        }

        // FIXME: Filter out function pointer types until we fix them...
        if (cppString.countUntil("(") >= 0) {
            return true;
        }

        return false;
    };

    generator.importBlacklistFunc = (type) {
        string cppString = type.unqualifiedTypeString;

        if (cppString == "QString") {
            return true;
        }

        return false;
    };

    generator.inputWrapperFunc = (type) {
        string cppString = type.unqualifiedTypeString;

        if (cppString == "QString") {
            return "QStringInputWrapper";
        }

        return "";
    };

    generator.outputWrapperFunc = (type) {
        string cppString = type.unqualifiedTypeString;

        if (cppString == "QString") {
            return "qstringOutputWrapper";
        }

        return "";
    };

    generator.moduleName = "dqt";
    generator.sourceDirectory = "dqt_predefined";

    generator.writeToDirectory(container, "dqt");
}
