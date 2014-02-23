module smoke.smoke_generator;

import std.exception;
import std.stdio;
import std.path;
import std.file;
import std.array;
import std.algorithm;
import std.range;

import smoke.smoke_container;
import smoke.string_util;

private alias Type = immutable(SmokeContainer.Type);
private alias Class = immutable(SmokeContainer.Class);
private alias Enum = immutable(SmokeContainer.Enum);
private alias Method = immutable(SmokeContainer.Method);

private string baseNameCPP(string qualifiedName) {
    auto parts = qualifiedName.split("::");

    if (parts.length > 1) {
        return parts[$ - 1];
    }

    return qualifiedName;
}

private string topNameD(string qualifiedName) {
    if (qualifiedName.length == 0) {
        return "";
    }

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
     * This delegate will be called if set to blacklist classes.
     *
     * If this delegate returns true for a class, the class will no be
     * generated, subclasses will not be generated, methods with the class
     * mentioned in arguments will not be generated, etc.
     *
     * This should only be used when SMOKE just generates rubbish for a class.
     */
    bool delegate(Class cls) classBlackListFunc;

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

        if (cls.isAbstract) {
            file.write("abstract ");
        }

        // Always write 'static', if it's redundant the compiler
        // will just ignore it.
        file.writef("static class %s", baseNameCPP(cls.name));

        if (cls.parentClassList.length > 0) {
            file.writef(" : %s",
                cls.parentClassList[0]
                .name.replace("::", ".")
            );
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

        if (method.isAbstract) {
            file.write(" = 0");
        }

        file.write(";\n");
    }

    void writeDType
    (ref File file, Type type, ReturnType returnType) const {
        if (!returnType && type.isReference && !type.isPrimitive) {
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

        auto pointerCount = type.pointerDimension;

        if (pointerCount && !type.isPrimitive && !type.isEnum) {
            // Use one less pointer for class types, as the classes
            // will be a type of pointer themselves in D.
            --pointerCount;
        }

        file.write(repeat('*').take(pointerCount));
    }

    void writeOpenMethod(ref File file, Method method, int indent,
    AbstractImpl isAbstractImpl) const {
        // When debugging, print the method signature and everything
        // just like it was in C++.
        debug writeCPPMethodCommentLine(file, method, indent);

        writeIndent(file, indent);

        if (method.isDestructor) {
            // Just print this and be done with it for destructors.
            file.write("~this() \n");
            return;
        }

        if (method.isProtected) {
            file.write("protected ");
        }

        if (method.isStatic) {
            file.write("static ");
        } else if (!method.isVirtual
        || method.isConstructor
        || isAbstractImpl) {
            //file.write("final ");
        } else if (method.isAbstract) {
            file.write("abstract ");
        }

        if (!method.isStatic && method.isOverride) {
            //file.write("override ");
        }

        if (method.isConstructor) {
            file.write("this(");
        } else{
            writeDType(file, method.returnType, ReturnType.yes);

            file.write(' ');

            // TODO: Inject operator handling here.

            file.write(method.name);

            switch (method.name) {
            case "abstract":
            case "alias":
            case "align":
            case "asm":
            case "assert":
            case "cast":
            case "cdouble":
            case "cent":
            case "cfloat":
            case "creal":
            case "dchar":
            case "debug":
            case "delegate":
            case "foreach":
            case "foreach_reverse":
            case "idouble":
            case "ifloat":
            case "immutable":
            case "import":
            case "inout":
            case "interface":
            case "invariant":
            case "ireal":
            case "is":
            case "lazy":
            case "macro":
            case "mixin":
            case "module":
            case "pure":
            case "scope":
            case "shared":
            case "synchronized":
            case "typeid":
            case "typeof":
            case "ubyte":
            case "ucent":
            case "uint":
            case "ulong":
            case "unittest":
            case "ushort":
            case "version":
            case "volatile":
            case "with":
                // Write a trailing underscore for method names which are also
                // D keywords.
                file.write('_');
            break;
            default: break;
            }

            file.write('(');
        }

        foreach(i, type; method.argumentTypeList) {
            if (i > 0) {
                file.write(", ");
            }

            writeDType(file, type, ReturnType.no);
            file.writef(" x%d", i);
        }

        file.write(')');

        if (method.isConst && !method.isStatic) {
            file.write(" const");
        }
    }

    void writeMethodBody
    (ref File file, Method method, size_t methodIndex, int indent) const {
        // Write aliases so the rest of generation is easy.
        writeIndent(file, indent);
        file.write("alias cls = ");
        writeMetaClassName(file, method.cls);
        file.write(";\n");

        writeIndent(file, indent);
        file.write("alias methPtr = ");
        writeMethodPtrName(file, methodIndex, method);
        file.write(";\n\n");

        if (method.isDestructor) {
            // Destructors are very simple to bind.
            writeIndent(file, indent);
            file.write("auto stack = createSmokeStack();\n\n");

            writeIndent(file, indent);

            file.write("dqt_call_ClassFn("
                ~ "cast(void*) cls.smokeClass.classFn, "
                ~ "methPtr.method, "
                ~ "cast(void*) _data, "
                ~ "cast(void*) stack.ptr);");

            return;
        }

        if (method.isConstructor && method.cls.parentClassList.length > 0) {
            // Write the super call at the start of constructors.
            writeSuperLine(file, method.cls, indent);
        }

        foreach(index, type; method.argumentTypeList) {
            if (type.isPrimitive || type.isEnum) {
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
                file.writef("auto x%d_mapped = x%d_wrapped._data;\n",
                    index, index);
            }
        }

        writeIndent(file, indent);
        file.write("auto stack = createSmokeStack(");

        foreach(index, type; method.argumentTypeList) {
            if (index > 0) {
                file.writef(", ");
            }

            file.writef("x%d_mapped", index);
        }

        file.write(");\n");

        writeIndent(file, indent);
        file.write("dqt_call_ClassFn("
            ~ "cast(void*) cls.smokeClass.classFn, "
            ~ "methPtr.method, ");

        if (method.isStatic) {
            // The static methods don't have the data pointer.
            file.write("null");
        } else {
            file.write("cast(void*) _data");
        }

        file.write(", cast(void*) stack.ptr);\n");

        if (method.isConstructor) {
            // Constructors have to set a binding with SMOKE so
            // virtual methods can be called, etc.
            writeIndent(file, indent);
            file.write("dqt_bind_instance("
                ~ "cls.smokeClass.classFn, "
                ~ "stack[0].s_voidp);\n\n");

            // For constructors, don't return anything and just.
            // set the data pointer to the result.
            writeIndent(file, indent);
            file.write("_data = stack[0].s_voidp;\n");
        } else if (method.returnType.typeString != "void") {
            writeIndent(file, indent);

            if (method.returnType.isPrimitive) {
                file.writef("return cast(typeof(return)) stack[0].%s;\n",
                    method.returnType.stackItemEnumName,
                );
            } else if (method.returnType.isEnum) {
                // Cast enum values to the right type.
                file.write("return cast(typeof(return)) stack[0].s_enum;\n");
            } else {
                string wrapper = outputWrapper(method.returnType);

                if (wrapper.length > 0) {
                    file.writef("return %s(stack[0]);\n",
                        wrapper);
                } else if (method.returnType.cls !is null
                && method.returnType.cls.isAbstract) {
                    file.write(
                        "return new "
                        ~ method.returnType.cls.name.replace("::", ".")
                        ~ ".Impl(Nothing.init, stack[0].s_voidp);\n"
                    );
                } else {
                    file.write(
                        "return new typeof(return)"
                        ~ "(Nothing.init, stack[0].s_voidp);\n"
                    );
                }
            }
        }
    }

    void writeOpenEnum(ref File file, Enum enm, int indent) const {
        writeIndent(file, indent);
        file.writef("enum %s", baseNameCPP(enm.name));

        bool asLong = false;

        foreach(pair; enm.itemList) {
            if (pair.value > int.max) {
                asLong = true;
                break;
            }
        }

        if (asLong) {
            file.write(" : long ");
        }

        file.write( "{\n");
    }

    void writeEnum(ref File file, Enum enm, int indent) const {
        writeOpenEnum(file, enm, indent);

        foreach(pair; enm.itemList) {
            writeIndent(file, indent + 1);
            file.writef("%s = %d,\n", pair.name, pair.value);
        }

        writeClose(file, indent);
    }

    void writeMetaClassName(ref File file, Class cls) const {
        file.write("cls_");

        foreach(character; cls.name) {
            switch (character) {
            case '0': .. case '9':
            case 'a': .. case 'z':
            case 'A': .. case 'Z':
                file.write(character);
            break;
            default:
                file.write('_');
            break;
            }
        }
    }

    void writeMethodPtrName
    (ref File file, size_t index, Method method) const {
        file.write("ptr_");
        writeMetaClassName(file, method.cls);
        file.write("_");

        foreach(character; method.name) {
            switch (character) {
            case '0': .. case '9':
            case 'a': .. case 'z':
            case 'A': .. case 'Z':
                file.write(character);
            break;
            default:
                file.write('_');
            break;
            }
        }

        file.write(index);
    }

    enum AbstractImpl { no, yes }

    void writeStaticDeclarations(ref File file, Class cls) const {
        foreach(index, method; cls.methodList) {
            if (isBlacklisted(method)) {
                continue;
            }

            file.write("package immutable(Smoke.Method*) ");
            writeMethodPtrName(file, index, method);
            file.write(";\n");
        }

        // Write the class loader.
        file.write("package immutable(ClassData) ");
        writeMetaClassName(file, cls);
        file.write(";\n");

        foreach(nestedClass; cls.nestedClassList) {
            writeStaticDeclarations(file, nestedClass);
        }
    }

    void writeStaticAssignments(ref File file, Class cls) const {
        writeIndent(file, 1);
        // Write the class loader.
        writeMetaClassName(file, cls);

        file.writef(
            " = %s.demandClass(\"%s\");\n\n",
            _loaderName,
            cls.name
        );

        foreach(index, method; cls.methodList) {
            if (isBlacklisted(method)) {
                continue;
            }

            writeIndent(file, 1);
            writeMethodPtrName(file, index, method);
            file.write(" = ");
            writeMetaClassName(file, cls);
            file.writef(".demandMethod(\"%s\"", method.name);

            foreach(type; method.argumentTypeList) {
                file.writef(", \"%s\"", type.typeString);
            }

            file.write(");\n");
        }

        foreach(nestedClass; cls.nestedClassList) {
            writeStaticAssignments(file, nestedClass);
        }
    }

    void writeSuperLine(ref File file, Class cls, int indent) const {
        writeIndent(file, indent);
        file.write("super(Nothing.init);\n");
    }

    void writeSpecialConstructors
    (ref File file, Class cls, int indent, AbstractImpl isAbstractImpl) const {
        // Write a do nothing constructor for the benefit of skipping
        // constructors in subclasses.
        file.write('\n');
        writeIndent(file, indent + 1);
        file.write("package this(Nothing nothing) {\n");

        if (cls.parentClassList.length > 0) {
            writeSuperLine(file, cls, indent + 2);
        }

        writeIndent(file, indent + 1);
        file.write("}\n\n");

        // Write a special hidden constructor the generator call use to return
        // types returned back from C++.
        // The type signature won't clash with another because it contains
        // our special Nothing type.
        writeIndent(file, indent + 1);
        file.write("package this(Nothing nothing, void* data) {\n");

        if (cls.parentClassList.length > 0) {
            writeSuperLine(file, cls, indent + 2);
        }

        file.write("_data = data;");
        file.write("}\n");
    }

    void writeAbstractClassImpl(ref File file, Class cls, int indent) const {
        writeIndent(file, indent);

        file.write("package final static class Impl : this {\n");

        writeSpecialConstructors(file, cls, indent, AbstractImpl.yes);

        void writeAbstractMethodFromClass(Class cls) {
            foreach(index, method; cls.methodList) {
                if (isBlacklisted(method) || !method.isAbstract) {
                    continue;
                }

                writeOpenMethod(file, method, indent + 1, AbstractImpl.yes);
                file.write(" {\n");
                writeMethodBody(file, method, index, indent + 2);
                writeClose(file, indent + 1);
            }

            if (cls.parentClassList.length > 0) {
                // FIXME: Account for multiple inheritance and fixes here.
                writeAbstractMethodFromClass(cls.parentClassList[0]);
            }
        }

        writeAbstractMethodFromClass(cls);

        writeIndent(file, indent);
        file.write("}\n");
    }

    void writeClass(ref File file, Class cls, int indent) const {
        if (isBlacklisted(cls)) {
            return;
        }

        writeOpenClass(file, cls, indent);

        if (cls.parentClassList.length == 0) {
            // Write the data pointer variable into root classes.
            writeIndent(file, indent + 1);
            file.write("package void* _data;\n");
        }

        writeSpecialConstructors(file, cls, indent, AbstractImpl.no);

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

            writeOpenMethod(file, method, indent + 1, AbstractImpl.no);

            if (method.isPureVirtual) {
                // Pure virtual methods have no body, etc.
                file.write(";\n");
                continue;
            }

            file.write(" {\n");
            writeMethodBody(file, method, index, indent + 2);
            writeClose(file, indent + 1);
        }

        if (cls.isAbstract) {
            writeAbstractClassImpl(file, cls, indent + 1);
        }

        writeClose(file, indent);
    }

    void writeImports(ref File file, Class cls) const {
        bool[string] nameSet;

        void considerType(Type type) {
            if (type.isPrimitive) {
                return;
            }

            if (isImportBlacklisted(type)) {
                return;
            }

            // Add this one to the set.
            string name = topNameD(basicDTypeFunc(type));
            nameSet[name] = true;
        }

        void searchForTypesInMethod(Method method) {
            if (isBlacklisted(method)) {
                // If the method is not going to be generated, we shouldn't
                // consider any types from it for imports at all.
                return;
            }

            considerType(method.returnType);

            foreach(type; method.argumentTypeList) {
                considerType(type);
            }
        }

        void searchForTypesInClass(Class cls) {
            foreach(method; cls.methodList) {
                searchForTypesInMethod(method);
            }

            foreach(parentClass; cls.parentClassList) {
                // Add this one to the set.
                string name = topNameD(parentClass.name);
                nameSet[name] = true;
            }

            foreach(nestedClass; cls.nestedClassList) {
                searchForTypesInClass(nestedClass);
            }

            if (cls.isAbstract && cls.parentClassList.length > 0) {
                // FIXME: Account for multiple inheritance here.
                searchForTypesInClass(cls.parentClassList[0]);
            }
        }

        void removeClassesDefinedHere(Class cls) {
            nameSet.remove(topNameD(cls.name));

            foreach(nestedClass; cls.nestedClassList) {
                removeClassesDefinedHere(nestedClass);
            }
        }

        searchForTypesInClass(cls);
        removeClassesDefinedHere(cls);

        // This C types will be needed for generated code.
        file.write("import core.stdc.config : c_long, c_ulong;\n");
        // Import smoke types, as they will be needed.
        file.write("import smoke.smoke;\n");
        file.write("import smoke.smoke_util;\n");
        file.write("import smoke.smoke_cwrapper;\n");
        // Write the module prefix import line.
        file.writef("import %s.prefix;\n", _moduleName);
        file.writef(
            "import %s._static_%s;\n",
            _moduleName,
            cls.name.toLowerASCII
        );

        foreach(name, _; nameSet) {
            file.writef("import %s.%s;\n", _moduleName, name.toLowerASCII);
        }

        if (nameSet.length >= 1) {
            file.write('\n');
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

    bool isBlacklisted(Class cls) const {
        if (classBlackListFunc !is null && classBlackListFunc(cls)) {
            return true;
        }

        // See if what we inherit was blacklisted. If something we inherit
        // is blacklisted, this class will not be generated.
        foreach(parent; cls.parentClassList) {
            if (isBlacklisted(parent)) {
                return true;
            }
        }

        return false;
    }

    bool isBlacklisted(Method method) const {
        if (isBlacklisted(method.returnType)) {
            return true;
        }

        // FIXME: Handle operator overloads.
        if (method.name.startsWith("operator")) {
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
        if (type.cls !is null && isBlacklisted(type.cls)) {
            return true;
        }

        return blackListFunc !is null && blackListFunc(type);
    }

    bool isImportBlacklisted(Type type) const {
        return importBlacklistFunc !is null && importBlacklistFunc(type);
    }

    void writeModuleLine(ref File file, string baseName) const {
        file.writef("module %s.%s;\n\n", _moduleName, baseName);
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

        string staticFilenameForTypename(string name) {
            return buildPath(directory, "_static_" ~ name.toLowerASCII ~ ".d");
        }

        string filenameForTypename(string name) {
            return buildPath(directory, name.toLowerASCII ~ ".d");
        }

        foreach(cls; container.topLevelClassList) {
            if (isBlacklisted(cls)) {
                continue;
            }

            File file = File(staticFilenameForTypename(cls.name), "w");
            writeModuleLine(file, file.name.baseName.stripExtension);

            file.write("import smoke.smoke;\n");
            file.write("import smoke.smoke_loader;\n");
            // Write the module prefix import line.
            file.writef("import %s.prefix;\n\n", _moduleName);

            writeStaticDeclarations(file, cls);

            file.write("\nshared static this() {\n");

            writeStaticAssignments(file, cls);

            file.write('}');
        }

        foreach(cls; container.topLevelClassList) {
            if (isBlacklisted(cls)) {
                continue;
            }

            File file = File(filenameForTypename(cls.name), "w");
            writeModuleLine(file, file.name.baseName.stripExtension);

            writeImports(file, cls);

            writeClass(file, cls, 0);
        }

        foreach(enm; container.topLevelEnumList) {
            File file = File(filenameForTypename(enm.name), "w");
            writeModuleLine(file, file.name.baseName.stripExtension);

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
