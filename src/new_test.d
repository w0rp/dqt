import dqt.smoke.smoke;
import dqt.smoke.smoke_cwrapper;
import dqt.smoke.smoke_container;

import std.exception;
import std.stdio;
import std.path;
import std.file;
import std.string;
import std.array;
import std.algorithm;
import std.range;

private alias Class = SmokeContainer.Class;
private alias Enum = SmokeContainer.Enum;
private alias Method = SmokeContainer.Method;
private alias Type = SmokeContainer.Type;

string baseNameCPP(string qualifiedName) {
    auto parts = qualifiedName.split("::");

    if (parts.length > 1) {
        return parts[$ - 1];
    }

    return qualifiedName;
}

string topNameD(string qualifiedName) {
    return qualifiedName.split(".")[0];
}

struct SmokeGenerator {
private:
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
        file.writef("class %s", baseNameCPP(cls.name));

        if (cls.parentClassList.length > 0) {
            file.writef(" : %s", cls.parentClassList[0].name);
        }

        file.write(" {\n");

        if (cls.parentClassList.length > 1) {
            writefln("`%s` has more than one parent class and we only "
                ~ "picked the first one! That 'aint right!", cls.name);
        }
    }

    void writeCPPMethodCommentLine
    (ref File file, const(Method) method, int indent) {
        writeIndent(file, indent);
        file.writef("// %s %s(", method.returnType.typeString, method.name);

        foreach(i, type; method.argumentTypeList) {
            if (i > 0) {
                file.write(", ");
            }

            file.writef("%s x%d", type.typeString, i);
        }

        file.write(") {\n");
    }

    void writeDType(ref File file, const(Type) type) {
        // TODO: Replace function used here with injected method.
        file.write(basicDTypeFunc(type));
        file.write(repeat('*').take(type.pointerDimension + type.isReference));
    }

    void writeOpenMethod(ref File file, const(Method) method, int indent) {
        // When debugging, print the method signature and everything
        // just like it was in C++.
        debug writeCPPMethodCommentLine(file, method, indent);

        writeIndent(file, indent);

        if (method.isDestructor) {
            // Just print this and be done with it for destructors.
            file.writeln("~this() {");
            return;
        }

        if (method.isConstructor) {
            file.write("this(");
        } else{
            writeDType(file, method.returnType);
            file.writef(" %s(", method.name);
        }

        foreach(i, type; method.argumentTypeList) {
            if (i > 0) {
                file.write(", ");
            }

            writeDType(file, type);
            file.writef(" x%d", i);
        }

        file.write(") {\n");
    }

    void writeOpenEnum(ref File file, const Enum enm, int indent) {
        writeIndent(file, indent);
        file.writef("enum %s {\n", baseNameCPP(enm.name));
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


    void writeImports(ref File file, const(Class) cls) {
        bool[string] nameSet;

        // TODO: Inject global imports here with a function.

        void considerType(const(Type) type) {
            string name = topNameD(basicDTypeFunc(type));

            switch (name) {
            case "void":
            case "bool":
            case "int":
            case "uint":
            case "long":
            case "ulong":
            case "double":
            case "char":
            break;
            default:
                // Add this one to the set.
                nameSet[name] = true;
            break;
            }
        }

        foreach(method; cls.methodList) {
            considerType(method.returnType);

            foreach(type; method.argumentTypeList) {
                considerType(type);
            }
        }

        // Remove this type as a consideration.
        nameSet.remove(cls.name);

        foreach(name, _; nameSet) {
            file.writefln("import %s;", name.toLower);
        }

        if (nameSet.length >= 1) {
            file.writeln();
        }
    }

    string delegate(const(Type) type) basicDTypeFunc;
public:
    @trusted
    void writeToDirectory
    (immutable(SmokeContainer) container, string directory) {
        enforce(basicDTypeFunc !is null, "You must set basicDTypeFunc!");

        if (!exists(directory)) {
            mkdir(directory);
        }

        string filenameForTypename(string name) {
            return buildPath(directory, name ~ ".d");
        }

        foreach(cls; container.topLevelClassList) {
            File file = File(filenameForTypename(cls.name.toLower), "w");

            writeImports(file, cls);

            writeClass(file, cls, 0);
        }

        foreach(enm; container.topLevelEnumList) {
            File file = File(filenameForTypename(enm.name.toLower), "w");

            writeEnum(file, enm, 0);
        }
    }
}

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

    generator.writeToDirectory(container, "output");
}
