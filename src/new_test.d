import dqt.smoke.smoke;
import dqt.smoke.smoke_cwrapper;
import dqt.smoke.smoke_container;

import std.stdio;
import std.path;
import std.file;
import std.string;
import std.array;

alias Class = SmokeContainer.Class;
alias Enum = SmokeContainer.Enum;
alias Method = SmokeContainer.Method;

string baseName(string qualifiedName) {
    auto parts = qualifiedName.split("::");

    if (parts.length > 1) {
        return parts[$ - 1];
    }

    return qualifiedName;
}

struct SmokeGenerator {
    void writeIndent(ref File file, int size) {
        if (size == 0) {
            return;
        }

        for (int i = 0; i < size; ++i) {
            file.write("    ");
        }
    }

    void writeClose(ref File file, int indent) {
        writeIndent(file, indent);
        file.write("}\n");
    }

    void writeOpenClass(ref File file, const Class cls, int indent) {
        writeIndent(file, indent);
        file.writef("class %s", baseName(cls.name));

        if (cls.parentClassList.length > 0) {
            file.writef(" : %s", cls.parentClassList[0].name);
        }

        file.write(" {\n");

        if (cls.parentClassList.length > 1) {
            writefln("`%s` has more than one parent class and we only "
                ~ "picked the first one! That 'aint right!", cls.name);
        }
    }

    void writeOpenMethod(ref File file, const Method method, int indent) {
        writeIndent(file, indent);
        file.writef("%s %s(", method.returnType.typeString, method.name);

        foreach(i, type; method.argumentTypeList) {
            if (i > 0) {
                file.write(", ");
            }

            file.writef("%s x%d", type.typeString, i);
        }

        file.write(") {\n");
    }

    void writeOpenEnum(ref File file, const Enum enm, int indent) {
        writeIndent(file, indent);
        file.writef("enum %s {\n", baseName(enm.name));
    }

    void writeEnum(ref File file, const Enum enm, int indent) {
        writeOpenEnum(file, enm, indent);

        foreach(pair; enm.itemList) {
            writeIndent(file, indent + 1);
            file.writef("%s = %d;\n", pair.name, pair.value);
        }

        writeClose(file, indent);
    }

    void writeClass(ref File file, const Class cls, int indent) {
        writeOpenClass(file, cls, indent);

        foreach(nestedClass; cls.nestedClassList) {
            writeClass(file, nestedClass, indent + 1);
        }

        foreach(nestedEnum; cls.nestedEnumList) {
            writeEnum(file, nestedEnum, indent + 1);
        }

        foreach(method; cls.methodList) {
            writeOpenMethod(file, method, indent + 1);
            writeClose(file, indent + 1);
        }

        writeClose(file, indent);
    }
}


void main() {

    dqt_init_qtcore_Smoke();
    scope(exit) dqt_delete_qtcore_Smoke();
    dqt_init_qtgui_Smoke();
    scope(exit) dqt_delete_qtgui_Smoke();

    auto container = new SmokeContainer();

    container.loadData(cast(Smoke*) dqt_fetch_qtcore_Smoke());
    container.loadData(cast(Smoke*) dqt_fetch_qtgui_Smoke());
    container.finalize();

    auto generator = SmokeGenerator();

    if (!exists("output")) {
        mkdir("output");
    }

    foreach(cls; container.topLevelClassList) {
        File file = File(buildPath("output", cls.name.toLower ~ ".d"), "w");

        generator.writeClass(file, cls, 0);
    }

    foreach(enm; container.topLevelEnumList) {
        File file = File(buildPath("output", enm.name.toLower ~ ".d"), "w");

        generator.writeEnum(file, enm, 0);
    }
}
