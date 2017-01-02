import core.time;
import std.algorithm;
import std.string;
import std.array;
import std.stdio;

import smoke.smoke;
import smoke.smokeqt;
import smoke.smoke_container;
import smoke.smoke_generator;
import smoke.smoke_loader;

immutable(SmokeContainer) loadQtSmokeContainer() {
    init_qtcore_Smoke();
    scope(exit) delete_qtcore_Smoke();
    init_qtgui_Smoke();
    scope(exit) delete_qtgui_Smoke();

    return SmokeContainer.create(qtcore_Smoke, qtgui_Smoke);
}

void main() {
    writeln("Generating D source files...");

    immutable start = MonoTime.currTime();

    auto container = loadQtSmokeContainer();

    auto generatorBuilder = SmokeGeneratorBuilder();

    // A function for producing D types.
    generatorBuilder.basicDTypeFunc = (type) {
        string mappedType(string cppString) {
            if (cppString.startsWith("QFlags")) {
                return cppString[7 .. $ - 1];
            }

            switch (cppString) {
            case "QString":
                return "string";
            case "qint8":
                return "byte";
            case "qint16":
                return "short";
            case "qint32":
                return "int";
            case "qint64":
            case "qlonglong":
                return "long";
            case "qptrdiff":
                return "ptrdiff_t";
            case "qreal":
                // TODO: Build as float for ARM here somehow.
                return "double";
            case "quint8":
                return "ubyte";
            case "quint16":
                return "ushort";
            case "quint32":
                return "uint";
            case "quint64":
                return "ulong";
            case "quintptr":
                // FIXME: This actually needs to be uint on 32-bit.
                return "ulong";
            case "qulonglong":
                return "ulong";
            case "uchar":
                return "ubyte";
            default:
                return cppString;
            }
        }

        return mappedType(type.unqualifiedTypeString).replace("::", ".");
    };

    generatorBuilder.classBlacklistFunc = (cls) {
        switch (cls.name) {
        case "QIconEngineV2":
        case "QGraphicsLayout":
        case "QStringRef":
        // I don't know why this was broken.
        case "QPixmapCache":
        // TODO: These aren't working at the moment due to bugs
        // with generating abstract classes.
        case "QAbstractFileEngineIterator":
        case "QAccessibleInterfaceEx":
        case "QAccessibleTable2CellInterface":
        case "QAbstractProxyModel":
        case "QAbstractItemModel":
        case "QAbstractAnimation":
        case "QVariantAnimation":
        case "QFactoryInterface":
            return true;
        default:
            return false;
        }
    };

    generatorBuilder.blacklistFunc = (type) {
        string cppString = type.unqualifiedTypeString;

        switch (cppString) {
        case "QStringList":
        case "QStringRef":
        // TODO: This was broken
        case "QTextCodec":
        // TODO: This was broken
        case "QIODevice":
        case "FT_FaceRec_":
        case "_XDisplay":
        case "_XEvent":
        case "_XRegion":
        // This was just a problem.
        case "const QModelIndexList":
        // TODO: Handle QChar with a wrapper.
        case "QChar":
        // TODO: Write an implementation of this.
        case "QStyleOption":
        // TODO: These can't be generated at the moment because there isn't
        // any support for defining aliases.
        case "Qt::HitTestAccuracy":
        case "QGraphicsBlurEffect::BlurHints":
        case "QItemSelectionModel::SelectionFlags":
        case "QDockWidget::DockWidgetFeatures":
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

    generatorBuilder.importBlacklistFunc = (type) {
        string cppString = type.unqualifiedTypeString;

        switch (cppString) {
        case "QString":
        case "qreal":
            return true;
        default: break;
        }

        return false;
    };

    generatorBuilder.inputWrapperFunc = (type) {
        string cppString = type.unqualifiedTypeString;

        if (cppString == "QString") {
            return "QStringInputWrapper";
        }

        return "";
    };

    generatorBuilder.outputWrapperFunc = (type) {
        string cppString = type.unqualifiedTypeString;

        if (cppString == "QString") {
            return "qstringOutputWrapper";
        }

        return "";
    };

    generatorBuilder.moduleName = "dqt";

    auto generator = generatorBuilder.buildGenerator(container);

    generator.writeToDirectory(
        "generator/dqt_predefined",
        "source/dqt",
        CleanBuildDirectory.yes
    );

    auto timeElapsed = MonoTime.currTime() - start;
    writefln("Generation done in %d milliseconds.", timeElapsed.total!"msecs");
}
