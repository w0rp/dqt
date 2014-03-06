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


/**
 * Stored in a maximum of 128-bits of space,
 * this object represents an array of bits up to a maximum of 64 bits.
 *
 * Index 0 represents the least significant bit (2 ^^ 0),
 * the last valid index being the most significant bit.
 */
private struct BitArray64 {
private:
    ulong _data;
    size_t _length;
public:
    @safe pure nothrow
    this(ulong data, size_t length) {
        _data = data;
        _length = length;
    }

    @safe pure nothrow
    @property
    size_t length() const {
        return _length;
    }

    @safe pure nothrow
    bool opIndex(size_t index) const
    in {
        assert(index < _length);
    } body {
        return cast(bool)(_data & (1 << index));
    }

    @safe pure nothrow
    void opIndexAssign(bool value, size_t index)
    in {
        assert(index < _length);
    } body {
        if (value) {
            // Set the bit to 1.
            _data |= 1 << index;
        } else {
            // Set the bit to 0.
            _data &= ~(1 << index);
        }
    }

    int opApply(int delegate(ref size_t, ref bool) dg) {
        int result = 0;

        for (size_t index = 0; index < _length; ++index) {
            bool value = this[index];
            bool originalValue = value;

            result = dg(index, value);

            if (value != originalValue) {
                this[index] = value;
            }

            if (result) {
                break;
            }
        }

        return result;
    }

    int opApplyReverse(int delegate(ref size_t, ref bool) dg) {
        int result = 0;

        size_t index = _length - 1;

        while (true) {
            bool value = this[index];
            bool originalValue = value;

            result = dg(index, value);

            if (value != originalValue) {
                this[index] = value;
            }

            if (!index || result) {
                break;
            }

            --index;
        }

        return result;
    }

    @safe pure nothrow
    string toString() {
        string str = "[";

        for (size_t index = 0; index < _length; ++index) {
            bool val = this[index];

            if (index > 0) {
                str ~= ", ";
            }

            if (val) {
                str ~= '1';
            } else {
                str ~= '0';
            }
        }

        str ~= ']';

        return str;
    }
}

/**
 * This object represents a range which outputs the Cartesian product
 * of the binary numbers (0, 1) with itself a given n-many times.
 *
 * This can be used to generated all possible sequences of a collection
 * of switches being on or off. Sequences will be generated from the smallest
 * binary number to the largest. (All 0s first, all 1s last)
 */
private struct BinaryCartesianProduct {
private:
    ulong _number;
    ubyte _power;
public:
    this(ubyte power) in {
        assert(power < 64);
    } body {
        _power = power;
    }

    @safe pure nothrow
    @property
    bool empty() {
        return _number >= 2 ^^ _power;
    }

    @safe pure
    BitArray64 front() {
        enforce(!empty);

        return BitArray64(_number, _power);
    }

    @safe pure
    void popFront() {
        enforce(!empty);

        ++_number;
    }
}

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
    enum RemoveRef : bool { no, yes }

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
        } else {
            // If this is a root generated class, insert the interface here.
            file.writef(" : GeneratedSmokeWrapper");
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
    (ref File file, Type type, RemoveRef removeRef) const {
        if (!removeRef
        && type.isReference
        // Don't take primitive types by const ref, we just don't need to
        // and it makes things more complicated.
        && !(type.isConst && type.isPrimitive)) {
            // D has no reference types, so only write ref
            // for types when they are arguments.
            file.write("ref ");
        }

        // We won't write const() for primitive types, to make things
        // simpler.
        if (type.isConst && !type.isPrimitive) {
            file.write("const(");
        }

        if (type.isPrimitive) {
            file.write(type.primitiveTypeString);
        } else {
            file.write(basicDTypeFunc(type));
        }

        if (type.isConst && !type.isPrimitive) {
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

    void writeMethodName(ref File file, Method method) const {
        if (method.isConstructor) {
            file.write("this");
            return;
        }

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
    }

    void writeOpenMethodPrefix(ref File file, Method method,
    AbstractImpl isAbstractImpl) const {
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

        if (!method.isConstructor) {
            writeDType(file, method.returnType, RemoveRef.yes);
            file.write(' ');
        }

        writeMethodName(file, method);

        file.write('(');
    }

    void writeOpenMethodSuffix(ref File file, Method method) const {
        file.write(')');

        if (method.isConst && !method.isStatic) {
            file.write(" const");
        }
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

        writeOpenMethodPrefix(file, method, isAbstractImpl);

        foreach(i, type; method.argumentTypeList) {
            if (i > 0) {
                file.write(", ");
            }

            writeDType(file, type, RemoveRef.no);
            file.writef(" x%d", i);
        }

        writeOpenMethodSuffix(file, method);
    }

    void writeMethodBody
    (ref File file, Method method, size_t methodIndex, int indent) const {
        if (method.isConstructor && method.cls.parentClassList.length > 0) {
            // Write the super call at the start of constructors.
            writeSuperLine(file, method.cls, indent);
        }

        // Write aliases so the rest of generation is easy.
        writeIndent(file, indent);
        file.write("alias cls = ");
        writeMetaClassName(file, method.cls);
        file.write(";\n");

        writeIndent(file, indent);
        file.write("alias methIndex = ");
        writeMethodIndexName(file, methodIndex, method);
        file.write(";\n\n");

        // TODO: We could write the destructor only in the top-most
        // class instead and avoid the null checks.
        if (method.isDestructor) {
            // Destructors are very simple to bind.

            // We'll check for null so the bottom-most desructor
            // does actual work and the ones above do nothing.
            writeIndent(file, indent);
            file.write("if (_data is null) return;\n\n");

            // Call the C++ destructor if this class is marked as being
            // responsible for doing so.
            writeIndent(file, indent);
            file.write("if ((_flags & SmokeObjectFlags.unmanaged) == 0) "
                ~ "cls.callMethod(methIndex, _data);\n\n");

            // Remove the mappings from the C++ class pointer back to this
            // object.
            writeIndent(file, indent);
            file.write("deleteSmokeMapping(_data);\n\n");

            // Set null for reasons above.
            writeIndent(file, indent);
            file.write("_data = null;\n");

            return;
        }

        foreach(index, type; method.argumentTypeList) {
            if (type.isPrimitive || type.isEnum) {
                writeIndent(file, indent);

                if (type.isReference) {
                    // References need to be forwarded to C++ by
                    // passing the address of the ref parameter.
                    file.writef("auto x%d_mapped = &x%d;\n", index, index);
                } else {
                    file.writef("alias x%d_mapped = x%d;\n", index, index);
                }
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

        if (method.isConstructor) {
            file.write("_data = cls.callConstructor(methIndex");

        } else {
            file.write("auto retVal = cls.callMethod(methIndex, ");

            if (method.isStatic) {
                // The static methods don't have the data pointer.
                file.write("null");
            } else {
                file.write("cast(void*) _data");
            }
        }

        foreach(index, type; method.argumentTypeList) {
            file.writef(", x%d_mapped", index);
        }

        file.write(");\n");

        if (method.isConstructor) {
            // In constructors, we need to store a reference to the pointer
            // to the object back to this object.
            writeIndent(file, indent);
            file.write("storeSmokeMapping(_data, this);\n");
        }

        if (method.isConstructor
        || method.returnType.typeString == "void") {
            // We're done here, we don't have to deal with return values.
            return;
        }

        if (method.returnType.isPrimitive) {
            writeIndent(file, indent);
            file.writef("return cast(typeof(return)) retVal.%s;\n",
                method.returnType.stackItemEnumName,
            );
        } else if (method.returnType.isEnum) {
            // Cast enum values to the right type.
            writeIndent(file, indent);
            file.write("return cast(typeof(return)) retVal.s_enum;\n");
        } else {
            string wrapper = outputWrapper(method.returnType);

            if (wrapper.length > 0) {
                writeIndent(file, indent);
                file.writef("return %s(retVal);\n",
                    wrapper);
            } else {
                // If the pointer is null on the C++ side, return null from
                // D and stop here.
                writeIndent(file, indent);
                file.write("if (retVal.s_voidp is null) return null;\n");

                // Try to get a pre-existing wrapper first.
                // Write a cast here to check if we have an object of the
                // right type to begin with.
                //
                // This will make our internal functions raise assertion
                // errors if something went seriously wrong.
                writeIndent(file, indent);
                file.write("auto object = cast(typeof(return)) "
                    ~ "loadSmokeMapping(retVal.s_voidp);\n\n");

                writeIndent(file, indent);
                file.write("if (object !is null) return object;\n");

                // If getting the wrapper fails, we'll create a fresh object.
                writeIndent(file, indent + 1);
                file.write("auto flags = SmokeObjectFlags.unmanaged;\n\n");

                if (method.returnType.cls !is null
                && method.returnType.cls.isAbstract) {
                    writeIndent(file, indent + 1);
                    file.write(
                        "return cast(typeof(return)) new "
                        ~ method.returnType.cls.name.replace("::", ".")
                        ~ ".Impl(flags, retVal.s_voidp);\n"
                    );
                } else {
                    writeIndent(file, indent + 1);
                    file.write(
                        "return new typeof(return)"
                        ~ "(flags, retVal.s_voidp);\n"
                    );
                }
            }
        }
    }

    /**
     * Write a series of overloads removing 'ref' from 'ref const(T)' methods
     * in every possible combination to make taking r-values just work.
     */
    void writeConstRefOverloads
    (ref File file, Method method, int indent) const {
        size_t[size_t] indexMap;

        foreach(index, type; method.argumentTypeList) {
            if (type.isConst
            && !type.isPrimitive
            && type.isReference) {
                size_t bitIndex = indexMap.length;
                indexMap[index] = bitIndex;
            }
        }

        if (indexMap.length == 0) {
            return;
        }

        assert (indexMap.length <= 64);

        ubyte product_size = cast(ubyte) indexMap.length;

        foreach(array; BinaryCartesianProduct(product_size).dropOne()) {
            // First, write a new method overload.
            file.write('\n');
            writeIndent(file, indent);

            writeOpenMethodPrefix(file, method, AbstractImpl.yes);

            foreach(index, type; method.argumentTypeList) {
                if (index > 0) {
                    file.write(", ");
                }

                auto removeRef = RemoveRef.no;

                if (auto bitIndexPtr = index in indexMap) {
                    removeRef = cast(RemoveRef) array[*bitIndexPtr];
                }

                writeDType(file, type, removeRef);
                file.writef(" x%d", index);
            }

            writeOpenMethodSuffix(file, method);

            // Now write the method body as a delegate to the original method.
            file.write("{\n");
            writeIndent(file, indent + 1);

            if (!method.isConstructor
            && method.returnType.typeString != "void") {
                // We must return the same argument.
                file.write("return ");
            }

            writeMethodName(file, method);
            file.write('(');

            foreach(index, type; method.argumentTypeList) {
                if (index > 0) {
                    file.write(", ");
                }

                file.writef("x%d", index);
            }

            file.write(");\n");
            writeIndent(file, indent);
            file.write("}\n");
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

    void writeMethodIndexName
    (ref File file, size_t index, Method method) const {
        file.write("meth_");
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
        if (cls.methodList.length > 0) {
            foreach(index, method; cls.methodList) {
                if (isBlacklisted(method)) {
                    continue;
                }

                file.write("package immutable(Smoke.Index) ");
                writeMethodIndexName(file, index, method);
                file.write(";\n");
            }

            // Write the class loader.
            file.write("package immutable(ClassLoader) ");
            writeMetaClassName(file, cls);
            file.write(";\n");
        }

        foreach(nestedClass; cls.nestedClassList) {
            writeStaticDeclarations(file, nestedClass);
        }
    }

    void writeStaticAssignments(ref File file, Class cls) const {
        if (cls.methodList.length > 0) {
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
                writeMethodIndexName(file, index, method);
                file.write(" = ");
                writeMetaClassName(file, cls);
                file.writef(".demandMethodIndex(\"%s\"", method.name);

                foreach(type; method.argumentTypeList) {
                    file.writef(", \"%s\"", type.typeString);
                }

                file.write(");\n");
            }
        }

        foreach(nestedClass; cls.nestedClassList) {
            writeStaticAssignments(file, nestedClass);
        }
    }

    void writeSuperLine(ref File file, Class cls, int indent) const {
        writeIndent(file, indent);
        file.write("super(Nothing.init);\n");
    }

    void writeSpecialMethods
    (ref File file, Class cls, int indent, AbstractImpl isAbstractImpl) const {
        // Write a do nothing constructor for the benefit of skipping
        // constructors in subclasses.
        file.write('\n');
        writeIndent(file, indent);
        file.write("package this(Nothing nothing) {\n");

        if (cls.parentClassList.length > 0) {
            writeSuperLine(file, cls, indent + 1);
        }

        writeIndent(file, indent);
        file.write("}\n\n");

        // Write a special hidden constructor the generator call use to return
        // types returned back from C++.
        //
        // This method accepts flags for controlling the object's behaviour.
        writeIndent(file, indent);
        file.write("package this(SmokeObjectFlags flags, void* data) {\n");

        if (cls.parentClassList.length > 0) {
            writeSuperLine(file, cls, indent + 1);
        }

        file.write("_flags = flags;\n");
        file.write("_data = data;\n");

        // Keep a weak reference to this new wrapper object we are
        // creating, so we don't create multiple wrappers to the same
        // object.
        writeIndent(file, indent + 1);
        file.write("storeSmokeMapping(_data, this);\n");

        writeIndent(file, indent);
        file.write("}\n");

        writeIndent(file, indent);
        file.write("@system void disableGC() {\n");

        writeIndent(file, indent + 1);
        file.write("storeStrongSmokeMapping(_data, this); \n");

        writeIndent(file, indent);
        file.write("}\n");
    }

    void writeAbstractClassImpl(ref File file, Class cls, int indent) const {
        writeIndent(file, indent);

        file.write("package final static class Impl : this {\n");

        writeSpecialMethods(file, cls, indent + 1, AbstractImpl.yes);

        void writeAbstractMethodFromClass(Class cls) {
            foreach(index, method; cls.methodList) {
                if (isBlacklisted(method) || !method.isAbstract) {
                    continue;
                }

                writeOpenMethod(file, method, indent + 1, AbstractImpl.yes);
                file.write(" {\n");
                writeMethodBody(file, method, index, indent + 2);
                writeClose(file, indent + 1);

                writeConstRefOverloads(file, method, indent + 1);
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

            // Write the flags too.
            writeIndent(file, indent + 1);
            file.write("package SmokeObjectFlags _flags;\n");
        }

        writeSpecialMethods(file, cls, indent + 1, AbstractImpl.no);

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

            if (method.isAbstract) {
                // Abstract methods have no body, etc.
                file.write(";\n");
                continue;
            }

            file.write(" {\n");
            writeMethodBody(file, method, index, indent + 2);
            writeClose(file, indent + 1);

            writeConstRefOverloads(file, method, indent + 1);
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
