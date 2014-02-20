module smoke.smoke_generator;

import std.exception;
import std.stdio;
import std.path;
import std.file;
import std.string;
import std.array;
import std.algorithm;
import std.range;

import smoke.smoke_container;

private string baseNameCPP(string qualifiedName) {
    auto parts = qualifiedName.split("::");

    if (parts.length > 1) {
        return parts[$ - 1];
    }

    return qualifiedName;
}

private string topNameD(string qualifiedName) {
    return qualifiedName.split(".")[0];
}

/**
 * A SMOKE generator. Requiring input from a SmokeContainer and some
 * additional customisation, including external source files for adding
 * in special hooks and setting up a SmokeLoader, this class will generate
 * D code from SMOKE data. SmokeGenerator can be used to generate D bindings
 * for C++ libraries in this manner.
 */
struct SmokeGenerator {
private:
    string _moduleName;
    string _sourceDirectory;
    string _loaderName = "smokeLoader";
public:
    alias Type = immutable(SmokeContainer.Type);
    alias Class = immutable(SmokeContainer.Class);
    alias Enum = immutable(SmokeContainer.Enum);
    alias Method = immutable(SmokeContainer.Method);

    /**
     *
     */
    string delegate(Type type) basicDTypeFunc;

    /**
     * This delegate will be called if set to blacklist types.
     *
     * No methods will be generated which mention a blacklisted type.
     */
    bool delegate(Type type) blackListFunc;

    /**
     * This delegate will be called if set to generate the names
     * of wrapper functions to use for passing types to C++. The input
     * wrapper function will take the type as it is specified in the
     * argument list of a method.
     *
     * The wrapper function should probably be defined in the prefix.d file.
     *
     * The result of calling the wrapper function must contain a property
     * ._data for accessing some data to pass to C++.
     *
     * The wrapper should return an empty string to ignore the type.
     */
    string delegate(Type type) inputWrapperFunc;

    /**
     * This delegate will be called if set to generate the names
     * of wrapper functions to use for converting types from a
     * Smoke.StackItem to some D type.
     *
     * The wrapper function should probably be defined in the prefix.d file.
     *
     * The wrapper should return an empty string to ignore the type.
     */
    string delegate(Type type) outputWrapperFunc;

    bool delegate(Type type) importBlacklistFunc;
private:
    enum ReturnType : bool { no, yes }

    void writeIndent(ref File file, int size) const {
        if (size == 0) {
            return;
        }

        for (int i = 0; i < size; ++i) {
            file.write("    ");
        }
    }

    void writeClose(ref File file, int indent) const {
        writeIndent(file, indent);
        file.write("}\n");
    }

    void writeOpenClass(ref File file, Class cls, int indent) const {
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
    (ref File file, Method method, int indent) const {
        writeIndent(file, indent);

        file.write("// ");

        if (method.isProtected) {
            file.write("protected ");
        } else {
            file.write("public ");
        }

        if (method.isStatic) {
            file.write("static ");
        } else if (method.isVirtual && !method.isConstructor) {
            file.write("virtual ");
        }

        file.writef("%s %s(", method.returnType.typeString, method.name);

        foreach(i, type; method.argumentTypeList) {
            if (i > 0) {
                file.write(", ");
            }

            file.writef("%s x%d", type.typeString, i);
        }

        file.write(")");

        if (method.isConst) {
            file.write(" const");
        }

        if (method.isPureVirtual) {
            file.write(" = 0");
        }

        file.write(";\n");
    }

    void writeDType
    (ref File file, Type type, ReturnType returnType) const {
        if (!returnType && type.isReference) {
            // D has no reference types, so only write ref
            // for types when they are arguments.
            file.write("ref ");
        }

        if (type.isConst) {
            file.write("const(");
        }

        if (type.isPrimitive) {
            file.write(type.primitiveTypeString);
        } else {
            file.write(basicDTypeFunc(type));
        }

        if (type.isConst) {
            file.write(")");
        }

        file.write(repeat('*').take(type.pointerDimension));
    }

    void writeOpenMethod
    (ref File file, Method method, int indent) const {
        // When debugging, print the method signature and everything
        // just like it was in C++.
        debug writeCPPMethodCommentLine(file, method, indent);

        writeIndent(file, indent);

        if (method.isDestructor) {
            // Just print this and be done with it for destructors.
            file.writeln("~this() {");
            return;
        }

        if (method.isProtected) {
            file.write("protected ");
        }

        if (method.isStatic) {
            file.write("static ");
        } else if (method.isPureVirtual) {
            file.write("abstract ");
        } else if (!method.isVirtual && !method.isConstructor) {
            file.write("final ");
        }

        if (!method.isStatic && method.isOverride) {
            file.write("override ");
        }

        if (method.isConstructor) {
            file.write("this(");
        } else{
            writeDType(file, method.returnType, ReturnType.yes);
            file.writef(" %s(", method.name);
        }

        foreach(i, type; method.argumentTypeList) {
            if (i > 0) {
                file.write(", ");
            }

            writeDType(file, type, ReturnType.no);
            file.writef(" x%d", i);
        }

        file.write(')');

        if (method.isConst) {
            file.write(" const");
        }

        if (method.isPureVirtual) {
            file.write(";\n");
        } else {
            file.write(" {\n");
        }
    }

    void writeMethodBody
    (ref File file, Method method, int indent) const {
        if (method.isConstructor) {
            // Write the super call at the start of constructors.
            writeSuperLine(file, method.cls, indent);
        }

        foreach(index, type; method.argumentTypeList) {
            if (type.isPrimitive) {
                writeIndent(file, indent);
                file.writef("alias x%d_mapped = x%d;\n", index, index);
            } else {
                string wrapper = inputWrapper(type);

                writeIndent(file, indent);

                if (wrapper.length > 0) {
                    // RAII types will be held till scope exit.
                    file.writef("auto x%d_wrapped = %s(x%d);\n",
                        index, wrapper, index);
                } else {
                    file.writef("alias x%d_wrapped = x%d;\n", index, index);
                }

                writeIndent(file, indent);
                file.writef("alias x%d_mapped = x%d_wrapped._data;\n",
                    index, index);
            }
        }

        writeIndent(file, indent);
        file.write("auto stackResult = cls.callMethod(methPtr, _data");

        foreach(index, type; method.argumentTypeList) {
            file.writef(", x%d_mapped", index);
        }

        file.write(");\n");

        if (method.isConstructor) {
            // For constructors, don't return anything and just.
            // set the data pointer to the result.
            writeIndent(file, indent);
            file.write("_data = stackResult.void_p;");
        } else if (method.returnType.typeString != "void") {
            if (method.returnType.isEnum) {
                // Cast enum values to the right type.
                writeIndent(file, indent);
                file.write("auto finalValue = cast(");
                writeDType(file, method.returnType, ReturnType.yes);
                file.write(") stackResult.s_enum;\n");
            } else {
                string wrapper = outputWrapper(method.returnType);

                if (wrapper.length > 0) {
                    writeIndent(file, indent);
                    file.writef("auto finalValue = %s(stackResult);",
                        wrapper);
                } else {
                    writeIndent(file, indent);
                    file.writef("alias finalValue = stackResult.%s;\n",
                        method.returnType.stackItemEnumName,
                    );
                }
            }

            file.write("\n");

            writeIndent(file, indent);
            file.write("return finalValue;");
        }

        file.write('\n');
    }

    void writeOpenEnum(ref File file, Enum enm, int indent) const {
        writeIndent(file, indent);
        file.writef("enum %s {\n", baseNameCPP(enm.name));
    }

    void writeEnum(ref File file, Enum enm, int indent) const {
        writeOpenEnum(file, enm, indent);

        foreach(pair; enm.itemList) {
            writeIndent(file, indent + 1);
            file.writef("%s = %d;\n", pair.name, pair.value);
        }

        writeClose(file, indent);
    }

    void writeMethodPtrName
    (ref File file, size_t index, Method method) const {
        // TODO: Write a more descriptive name here instead.
        file.writef("ptr_%d", index);
    }

    void writeStaticClassConstructor
    (ref File file, Class cls, int indent) const {
        // Write the declarations first.
        writeIndent(file, indent);
        file.writeln("private static immutable(ClassData) cls;");

        foreach(index, method; cls.methodList) {
            if (isBlacklisted(method)
            || method.isPureVirtual) {
                continue;
            }

            writeIndent(file, indent);
            file.write("private static immutable(Smoke.Method*) ");
            writeMethodPtrName(file, index, method);
            file.writeln(";");
        }

        file.writeln();

        writeIndent(file, indent);
        file.writeln("static shared this() {");

        // Write out loading the class loader.
        writeIndent(file, indent + 1);
        file.writef(
            "cls = %s.demandClass(\"%s\");\n\n",
            _loaderName,
            cls.name
        );

        foreach(index, method; cls.methodList) {
            if (isBlacklisted(method)) {
                continue;
            }

            writeIndent(file, indent + 1);
            writeMethodPtrName(file, index, method);
            file.writef(" = cls.demandMethod(\"%s\"", method.name);

            foreach(type; method.argumentTypeList) {
                file.writef(", \"%s\"", type.typeString);
            }

            file.writeln(");");
        }

        writeIndent(file, indent);
        file.writeln("}");
    }

    void writeSuperLine(ref File file, Class cls, int indent) const {
        if (cls.parentClassList.length > 0) {
            writeIndent(file, indent);
            file.writeln("super(Nothing.init);");
        }
    }

    void writeClass(ref File file, Class cls, int indent) const {
        writeOpenClass(file, cls, indent);

        writeStaticClassConstructor(file, cls, indent + 1);

        if (cls.parentClassList.length == 0) {
            // Write the data pointer variable into root classes.
            writeIndent(file, indent + 1);
            file.writeln("package void* _data;");
        }

        // Write a do nothing constructor for the benefit of skipping
        // constructors in subclasses.
        file.writeln();

        writeIndent(file, indent + 1);
        file.writeln("package this(Nothing nothing) {");

        writeSuperLine(file, cls, indent + 2);

        writeIndent(file, indent + 1);
        file.writeln("}");

        foreach(nestedClass; cls.nestedClassList) {
            writeClass(file, nestedClass, indent + 1);
        }

        foreach(nestedEnum; cls.nestedEnumList) {
            writeEnum(file, nestedEnum, indent + 1);
        }

        foreach(index, method; cls.methodList) {
            if (isBlacklisted(method)) {
                continue;
            }

            writeOpenMethod(file, method, indent + 1);

            if (method.isPureVirtual) {
                // Pure virtual methods have no body, etc.
                continue;
            }

            // Write an alias so the rest of generation is easy.
            writeIndent(file, indent + 2);
            file.write("alias methPtr = ");
            writeMethodPtrName(file, index, method);
            file.write(";\n\n");

            if (method.isDestructor) {
                // Destructors are very simple to bind.
                writeIndent(file, indent + 2);
                file.write("cls.callMethod(methPtr, _data);\n");
            } else {
                writeMethodBody(file, method, indent + 2);
            }

            writeClose(file, indent + 1);
        }

        writeClose(file, indent);
    }

    void writeImports(ref File file, Class cls) const {
        bool[string] nameSet;

        // TODO: Inject global imports here with a function.

        void considerType(Type type) {
            if (type.isPrimitive) {
                return;
            }

            if (isImportBlacklisted(type)) {
                return;
            }

            string name = topNameD(basicDTypeFunc(type));

            // Add this one to the set.
            nameSet[name] = true;
        }

        foreach(method; cls.methodList) {
            if (isBlacklisted(method)) {
                // If the method is not going to be generated, we shouldn't
                // consider any types from it for imports at all.
                continue;
            }

            considerType(method.returnType);

            foreach(type; method.argumentTypeList) {
                considerType(type);
            }
        }

        // Remove this type as a consideration.
        nameSet.remove(cls.name);

        // This C types will be needed for generated code.
        file.writeln("import core.stdc.config : c_long, c_ulong");
        // Import smoke types, as they will be needed.
        file.writeln("import smoke.smoke;");
        file.writeln("import smoke.smoke_loader;");
        // Write the module prefix import line.
        file.writefln("import %s.prefix;", _moduleName);

        foreach(name, _; nameSet) {
            file.writefln("import %s.%s;", _moduleName, name.toLower);
        }

        if (nameSet.length >= 1) {
            file.writeln();
        }
    }

    string inputWrapper(Type type) const {
        if (inputWrapperFunc) {
            return inputWrapperFunc(type);
        }

        return "";
    }

    string outputWrapper(Type type) const {
        if (outputWrapperFunc) {
            return outputWrapperFunc(type);
        }

        return "";
    }

    bool isBlacklisted(Method method) const {
        if (isBlacklisted(method.returnType)) {
            return true;
        }

        foreach(type; method.argumentTypeList) {
            if (isBlacklisted(type)) {
                return true;
            }
        }

        return false;
    }

    bool isBlacklisted(Type type) const {
        return blackListFunc !is null && blackListFunc(type);
    }

    bool isImportBlacklisted(Type type) const {
        return importBlacklistFunc !is null && importBlacklistFunc(type);
    }

    void writeModuleLine(ref File file) const {
        file.writef(
            "module %s.%s;\n\n",
            _moduleName,
            // Take the end of the module name from the filename
            file.name.baseName.stripExtension
        );
    }
public:
    /**
     * Returns: The module name currently set for this generator.
     */
    @safe pure
    @property
    void moduleName(string name) {
        // TODO: Check format of name with regex here.

        _moduleName = name;
    }

    /**
     * Set the module name for this generator.
     *
     * Before generating source files, this value must be set, as it
     * will be used as the module name for all generated files.
     */
    @safe pure nothrow
    @property
    string moduleName() const {
        return _moduleName;
    }

    @safe pure
    @property
    void sourceDirectory(string value) {
        _sourceDirectory = value;
    }

    @safe pure nothrow
    @property
    string sourceDirectory() const {
        return _sourceDirectory;
    }

    /**
     * Given some SmokeContainer data, generate D source files in a given
     * directory.
     *
     * Params:
     *     container = A SmokeContainer containing SMOKE data.
     *     directory = A directory to write the source files to.
     */
    @trusted
    void writeToDirectory
    (immutable(SmokeContainer) container, string directory) const {
        enforce(basicDTypeFunc !is null, "You must set basicDTypeFunc!");
        enforce(_moduleName.length > 0, "You must set moduleName!");
        enforce(_sourceDirectory.length > 0, "You must set sourceDirectory!");
        enforce(exists(_sourceDirectory) && isDir(_sourceDirectory),
            "sourceDirectory does not point to a valid directory!");

        if (!exists(directory)) {
            mkdir(directory);
        }

        string filenameForTypename(string name) {
            return buildPath(directory, name ~ ".d");
        }

        foreach(cls; container.topLevelClassList) {
            File file = File(filenameForTypename(cls.name.toLower), "w");

            writeModuleLine(file);

            writeImports(file, cls);

            writeClass(file, cls, 0);
        }

        foreach(enm; container.topLevelEnumList) {
            File file = File(filenameForTypename(enm.name.toLower), "w");

            writeModuleLine(file);

            writeEnum(file, enm, 0);
        }

        // Copy .d files to the output directory from the source directory.
        foreach(inName; dirEntries(_sourceDirectory, "*.d", SpanMode.shallow)) {
            if (isFile(inName)) {
                copy(inName, buildPath(directory, baseName(inName)));
            }
        }
    }
}
