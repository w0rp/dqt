module smoke.smoke_container;

import std.stdio;
import std.array;
import std.exception;
import std.functional;

import smoke.smoke;
import smoke.smoke_cwrapper;
import smoke.smoke_util;
import smoke.string_util : toSlice;

@trusted
private long loadEnumValue(Smoke* smoke, Smoke.Method* smokeMethod) pure {
    Smoke.Class* smokeClass = smoke._classes + smokeMethod.classID;

    auto stack = createSmokeStack();

    // Cast this to pure. Sure the data is global, but screw it, make it pure.
    alias extern(C) void function(void*, short, void*, void*) pure PureFunc;

    (cast(PureFunc) &dqt_call_ClassFn)(
        smokeClass.classFn, smokeMethod.method, null, stack.ptr);

    // Get the long value back from the return value of calling a SMOKE
    // function. This is the enum value.
    return stack[0].s_long;
}

@trusted
private string namespaceForName(string name) {
    auto parts = name.split("::");

    if (parts.length > 1) {
        return parts[0 .. $ - 1].join("::");
    }

    return null;
}

/**
 * This class is a D representation of all of the data from a C++ Smoke struct.
 */
class SmokeContainer {
public:
    /**
     * Given a sequence of SMOKE data to load, create a SmokeContainer
     * containing information copied from the SMOKE data.
     */
    static immutable(SmokeContainer) create(Smoke*[] smokeList ...) pure {
        auto container = new SmokeContainer();

        foreach (smoke; smokeList) {
            container.loadData(smoke);
        }

        container.finalize();

        return container;
    }

    /**
     * This class is a D representation of a type in C++, taken from Smoke.
     */
    class Type {
    private:
        string _typeString;
        Smoke.TypeFlags _flags;
        Class _cls;
        bool _isPrimitive;

        @safe pure nothrow
        this(string typeString, Smoke.TypeFlags flags, Class cls) {
            _typeString = typeString;
            _flags = flags;
            _cls = cls;
        }

        /**
         * Returns: The type ID for the item, matching type of thing
         * to pick out of the smoke stack.
         */
        @safe pure nothrow
        @property Smoke.TypeId typeID() inout {
            return cast(Smoke.TypeId)(_flags & Smoke.TypeFlags.tf_elem);
        }
    public:
        /**
         * Returns: The full string spelling out this type in C++.
         */
        @safe pure nothrow
        @property string typeString() inout {
            return _typeString;
        }

        /**
         * Returns: The string spelling out this type in C++, without
         * any qualifiers.
         *
         * Note: 'void*' will be returned as 'void', as will 'void**'
         */
        @safe pure nothrow
        @property string unqualifiedTypeString() inout {
            // FIXME: This might be broken for types like this
            // char * const;
            int front = isConst * 6;
            int end = front;

            // Scan forwards till we hit a non-identifier character.
            // Spaces are included for things like 'unsigned char'
            // Trailing spaces shouldn't be set by SMOKE.
            for (; end < _typeString.length; ++end) {
                if (_typeString[end] == '*'
                || _typeString[end] == '&'
                || _typeString[end] == '(') {
                    break;
                }
            }

            return _typeString[front .. end];
        }

        /**
         * Returns: The class associated with this type, null if no class.
         */
        @safe pure nothrow
        @property inout(Class) cls() inout {
            return _cls;
        }

        /**
         * Returns: true if this type is a pointer type.
         */
        @safe pure nothrow
        @property bool isPointer() inout {
            return (_flags & Smoke.TypeFlags.tf_ptr) != 0;
        }

        /**
         * Returns: The dimensionality of this type is a pointer.
         *
         * T has a dimensionality of 0.
         * T* is 1.
         * T** is 2.
         * T*** is 3.
         */
        @safe pure nothrow
        @property int pointerDimension() inout {
            int pointerCount = 0;

            // We have to search the entire string because C++ pointers can be
            // like this ...
            // void**
            // ... but they can also be like this...
            // const int* const*
            foreach(character; _typeString) {
                if (character == '*') {
                    ++pointerCount;
                } else if (character == '(') {
                    // This is a function pointer.
                    return 1;
                }
            }

            return pointerCount;
        }

        /**
         * Returns: true if this type is a C++ reference type.
         */
        @safe pure nothrow
        @property bool isReference() inout {
            return (_flags & Smoke.TypeFlags.tf_ref) != 0;
        }

        /**
         * Returns: true if this type is a C++ const type.
         */
        @safe pure nothrow
        @property bool isConst() inout {
            return (_flags & Smoke.TypeFlags.tf_const) != 0;
        }

        /**
         * Returns: true if this is a primitive type.
         */
        @safe pure nothrow
        @property bool isPrimitive() inout {
            // Despite my best efforts to check == "void" once early on
            // it just wouldn't work, so here it is jammed in this method.
            return _isPrimitive || _typeString == "void";
        }

        /**
         * Returns: true if this is an enum type.
         */
        @safe pure nothrow
        @property bool isEnum() inout {
            return typeID == Smoke.TypeId.t_enum;
        }

        /**
         * Returns: A string representing the primitive D type matching
         *     this type. This will be the type without any pointers, etc.,
         *     so "void*" will be written as "void".
         */
        @safe pure nothrow
            @property string primitiveTypeString() inout {
            assert(
                isPrimitive,
                "primtiveTypeString called for non primitive!"
            );

            switch (unqualifiedTypeString) {
            case "void":
                return "void";
            case "signed char":
                return "byte";
            case "unsigned char":
                return "ubyte";
            case "char":
                return "char";
            case "wchar_t":
                return "dchar";
            case "short":
                return "short";
            case "unsigned short":
                return "ushort";
            case "int":
                return "int";
            case "unsigned":
            case "unsigned int":
                return "uint";
            case "long":
                return "c_long";
            case "unsigned long":
                return "c_ulong";
            case "long long":
                return "long";
            case "unsigned long long":
                return "ulong";
            case "float":
                return "float";
            case "double":
                return "double";
            case "long double":
                return "real";
            case "size_t":
                return "size_t";
            case "ptrdiff_t":
                return "ptrdiff_t";
            case "bool":
                return "bool";
            default:
                assert(0, "Unhandled C++ type: " ~ unqualifiedTypeString);
            }
        }

        /**
         * Returns: The name of the property that should be used for
         *     taking the value out of the Smoke.StackItem union.
         */
        @safe pure nothrow
        @property string stackItemEnumName() inout {
            if (isPointer) {
                return "s_voidp";
            }

            switch (unqualifiedTypeString) {
            case "signed char":
                return "s_char";
            case "unsigned char":
                return "s_uchar";
            case "char":
                return "s_char";
            case "wchar_t":
                return "s_int";
            case "short":
                return "s_short";
            case "unsigned short":
                return "s_ushort";
            case "int":
                return "s_int";
            case "unsigned":
            case "unsigned int":
                return "s_uint";
            case "long":
                return "s_long";
            case "unsigned long":
                return "s_ulong";
            case "long long":
                return "s_long";
            case "unsigned long long":
                return "s_ulong";
            case "float":
                return "s_float";
            case "double":
            case "long double":
                return "s_double";
            case "size_t":
                return "s_ulong";
            case "bool":
                return "s_bool";
            default:
                return "s_voidp";
            }
        }
    }

    /**
     * This class is a representation of a C++ method, taken from Smoke.
     */
    class Method {
    private:
        string _name;
        Class _cls;
        Type _returnType;
        Type[] _argumentTypeList;
        Smoke.MethodFlags _flags;
        bool _isOverride;

        @safe pure nothrow
        this() {}
    public:
        /**
         * Returns: true if this method is an override.
         */
        @safe pure nothrow
        @property bool isOverride() inout {
            return _isOverride;
        }

        /**
         * Returns: The name of this method or function as it is in C++.
         */
        @safe pure nothrow
        @property string name() inout {
            return _name;
        }

        /**
         * Returns: The class object for this method. null if no class.
         */
        @safe pure nothrow
        @property inout(Class) cls() inout {
            return _cls;
        }

        /**
         * Returns: The return type for this method.
         */
        @safe pure nothrow
        @property inout(Type) returnType() inout {
            return _returnType;
        }

        /**
         * Returns: The list of argument types for this method,
         *   which may be empty.
         */
        @safe pure nothrow
        @property inout(Type[]) argumentTypeList() inout {
            return _argumentTypeList;
        }

        /**
         * Returns: True if this method is static.
         */
        @safe pure nothrow
        @property bool isStatic() inout {
            return (_flags & Smoke.MethodFlags.mf_static) != 0;
        }

        /**
         * Returns: True if this method is a constructor.
         */
        @safe pure nothrow
        @property bool isConstructor() inout {
            return (_flags & Smoke.MethodFlags.mf_ctor) != 0;
        }

        /**
         * Returns: True if this method is a copy constructor.
         */
        @safe pure nothrow
        @property bool isCopyConstructor() inout {
            return (_flags & Smoke.MethodFlags.mf_copyctor) != 0;
        }

        /**
         * Returns: True if this method is an explicit constructor.
         */
        @safe pure nothrow
        @property bool isExplicitConstructor() inout {
            return (_flags & Smoke.MethodFlags.mf_explicit) != 0;
        }

        /**
         * Returns: True if this method is a destructor.
         */
        @safe pure nothrow
        @property bool isDestructor() inout {
            return (_flags & Smoke.MethodFlags.mf_dtor) != 0;
        }

        /**
         * Returns: True if this method is virtual.
         */
        @safe pure nothrow
        @property bool isVirtual() inout {
            // I do not trust SMOKE one bit to get this right.
            if (isPureVirtual) {
                return true;
            }

            return (_flags & Smoke.MethodFlags.mf_virtual) != 0;
        }

        /**
         * Returns: True if this method is pure virtual.
         */
        @safe pure nothrow
        @property bool isPureVirtual() inout {
            return (_flags & Smoke.MethodFlags.mf_purevirtual) != 0;
        }

        alias isAbstract = isPureVirtual;

        /**
         * Returns: True if this method is a protected method.
         */
        @safe pure nothrow
        @property bool isProtected() inout {
            return (_flags & Smoke.MethodFlags.mf_protected) != 0;
        }

        /**
         * Returns: True if this method is const.
         */
        @safe pure nothrow
        @property bool isConst() inout {
            return (_flags & Smoke.MethodFlags.mf_const) != 0;
        }

        /**
         * Returns: True if this method is a Qt signal.
         */
        @safe pure nothrow
        @property bool isSignal() inout {
            return (_flags & Smoke.MethodFlags.mf_signal) != 0;
        }

        /**
         * Returns: True if this method is a Qt slot.
         */
        @safe pure nothrow
        @property bool isSlot() inout {
            return (_flags & Smoke.MethodFlags.mf_slot) != 0;
        }
    }

    /**
     * This class is a representation of a C++ class, taken from Smoke.
     */
    class Class {
    private:
        Class[] _parentClassList;
        string _name;
        Method[] _methodList;
        Class[] _nestedClassList;
        Enum[] _nestedEnumList;
        bool _isAbstract;

        @safe pure nothrow
        this() {}

        @safe pure nothrow
        this(string name) {
            _name = name;
        }
    public:
        /**
         * Returns: true if this class is an abstract class.
         */
        @safe pure nothrow
        @property inout(bool) isAbstract() inout {
            return _isAbstract;
        }

        /**
         * Because the class comes from C++, the class can have
         * multiple parents through multiple inheritance.
         *
         * Returns: A list of parent classes for this class.
         */
        @safe pure nothrow
        @property inout(Class[]) parentClassList() inout {
            return _parentClassList;
        }

        /**
         * Returns: A list of classes nested in this class.
         */
        @safe pure nothrow
        @property inout(Class[]) nestedClassList() inout {
            return _nestedClassList;
        }

        /**
         * Returns: A list of enums nested in this class.
         */
        @safe pure nothrow
        @property inout(Enum[]) nestedEnumList() inout {
            return _nestedEnumList;
        }

        /**
         * Returns: The name of this class.
         */
        @safe pure nothrow
        @property string name() inout {
            return _name;
        }

        /**
         * Returns: The list of methods for this class.
         */
        @safe pure nothrow
        @property inout(Method[]) methodList() inout {
            return _methodList;
        }
    }

    class Enum {
    public:
        struct Pair {
        private:
            string _name;
            long _value;
        public:
            /**
             * Returns: The name for this enum value.
             */
            @safe pure nothrow
            @property string name() inout {
                return _name;
            }

            /**
             * Return: The numerical value for this enum value.
             */
            @safe pure nothrow
            @property long value() inout {
                return _value;
            }
        }
    private:
        string _name;
        Pair[] _itemList;

        @safe pure nothrow
        this() {}

        @safe pure nothrow
        this(string name) {
            _name = name;
        }
    public:
        /**
         * Returns: The name of this enum.
         */
        @safe pure nothrow
        @property string name() inout {
            return _name;
        }

        /**
         * Returns: A list of pairs for this enum.
         */
        @safe pure nothrow
        @property inout(Pair[]) itemList() inout {
            return _itemList;
        }
    }

    /**
     * Load data from a Smoke structure. All information will be copied into
     * this container, so the this container is not dependant on the lifetime
     * of the Smoke structure.
     */
    @trusted
    void loadData(Smoke* smoke) pure {
        for (int i = 0; i < smoke._numMethods; ++i) {
            Smoke.Method* smokeMethod = smoke._methods + i;

            if (smokeMethod.flags & Smoke.MethodFlags.mf_enum) {
                // This is an enum value.
                Enum enm = this.getOrCreateEnum(smoke, smokeMethod.ret);

                enm._itemList ~= Enum.Pair(
                    smoke._methodNames[smokeMethod.name].toSlice.idup,
                    loadEnumValue(smoke, smokeMethod)
                );
            } else if (smokeMethod.name >= 0
            && smokeMethod.name < smoke._numMethodNames
            && smokeMethod.classID >= 0
            && smokeMethod.classID < smoke._numClasses) {
                // This is a class method.

                // Get the class for this method, create it if needed.
                Class cls = this.getOrCreateClass(smoke, smokeMethod.classID);

                // Create this method.
                Method method = this.createMethod(cls, smoke, smokeMethod);

                // Add the method to the list of methods in the class.
                cls._methodList ~= method;
            }
        }
    }
private:
    class SmokeMetadata {
        Class[Smoke.Index] _classMap;
        Enum[Smoke.Index] _enumMap;
        Type[Smoke.Index] _typeMap;
    }

    Class[] _topLevelClassList;
    Enum[] _topLevelEnumList;
    SmokeMetadata[Smoke*] _metadataMap;

    @trusted pure
    void loadParentClassesIntoClass
    (Class cls, Smoke* smoke, Smoke.Class* smokeClass) {
        Smoke.Index inheritanceIndex = smokeClass._parents;

        if (inheritanceIndex <= 0) {
            return;
        }

        while (true) {
            Smoke.Index index = smoke._inheritanceList[inheritanceIndex++];

            if (!index) {
                break;
            }

            cls._parentClassList ~= this.getOrCreateClass(smoke, index);
        }
    }

    @safe pure nothrow
    SmokeMetadata getOrCreateMetadata(Smoke* smoke) {
        auto metaPtr = smoke in _metadataMap;

        if (metaPtr) {
            return *metaPtr;
        }

        return _metadataMap[smoke] = new SmokeMetadata();
    }

    @trusted pure
    Class getOrCreateClass(Smoke* smoke, Smoke.Index index) {
        auto metadata = getOrCreateMetadata(smoke);

        Class* ourClassPointer = index in metadata._classMap;

        if (ourClassPointer) {
            return *ourClassPointer;
        }

        Smoke.Class* smokeClass = smoke._classes + index;

        Class cls = metadata._classMap[index] = new Class(
            smokeClass.className.toSlice.idup
        );

        this.loadParentClassesIntoClass(cls, smoke, smokeClass);

        return cls;
    }

    @trusted pure
    Type getOrCreateType(Smoke* smoke, Smoke.Index index) {
        if (index == 0) {
            return new Type("void", cast(Smoke.TypeFlags) 1, null);
        }

        auto metadata = getOrCreateMetadata(smoke);

        Type* ourTypePointer = index in metadata._typeMap;

        if (ourTypePointer) {
            return *ourTypePointer;
        }

        Smoke.Type* smokeType = smoke._types + index;

        return metadata._typeMap[index] = new Type(
            smokeType.name.toSlice.idup,
            cast(Smoke.TypeFlags) smokeType.flags,
            smokeType.classId >= 0
                ? this.getOrCreateClass(smoke, smokeType.classId)
                : null
        );
    }

    @trusted pure
    Enum getOrCreateEnum(Smoke* smoke, Smoke.Index typeIndex) {
        auto metadata = getOrCreateMetadata(smoke);

        Enum* ourEnumPointer = typeIndex in metadata._enumMap;

        if (ourEnumPointer) {
            return *ourEnumPointer;
        }

        Smoke.Type* smokeEnum = smoke._types + typeIndex;

        return metadata._enumMap[typeIndex] = new Enum(
            smokeEnum.name.toSlice.idup
        );
    }

    @trusted pure
    Method createMethod(Class cls, Smoke* smoke, Smoke.Method* smokeMethod) {
        Method method = new Method();

        method._flags = cast(Smoke.MethodFlags) smokeMethod.flags;
        method._name = smoke._methodNames[smokeMethod.name].toSlice.idup;
        method._cls = cls;
        method._returnType = this.getOrCreateType(smoke, smokeMethod.ret);

        if (smokeMethod.numArgs < 1) {
            return method;
        }

        // Load all the argument types into the method object.
        for (int i = 0; i < smokeMethod.numArgs; ++i) {
            Smoke.Index typeIndex = smoke._argumentList[smokeMethod.args + i];

            method._argumentTypeList ~= this.getOrCreateType(smoke, typeIndex);
        }

        return method;
    }

    /**
     * Finalize the Smoke container. This method must be called after loading
     * all of the smoke data required.
     */
    @trusted pure
    void finalize() {
        Class[string] namedClassMap;
        Enum[string] namedEnumMap;
        Method[][string][Class] classMethodMap;
        bool[Type] checkedTypes;
        bool[Class] abstractCache;

        @safe nothrow
        bool tryNestInClass(T)(string namespace, T value) {
            Class* contPtr = namespace in namedClassMap;

            if (contPtr) {
                static if (is(T == Class)) {
                    contPtr._nestedClassList ~= value;
                } else static if (is(T == Enum)) {
                    contPtr._nestedEnumList ~= value;
                } else {
                    static assert(false);
                }

                return true;
            }

            return false;
        }

        pure @safe nothrow
        bool isReallyPrimitive(const(Type) type) {
            with(Smoke.TypeId) switch (type.typeID) {
            case t_enum:
            case t_class:
            case t_last:
                return false;
            default:
            }

            // Okay, so SMOKE is telling us it's supposed to be
            // a primitive type. This can be a complete lie, so let's check.
            // We'll use the version of the type string without any pointers,
            // references, etc.
            switch (type.unqualifiedTypeString) {
            // Some of these are probably never used, but who knows?
            case "void":
            case "bool":
            case "char":
            case "signed char":
            case "unsigned char":
            case "short":
            case "unsigned short":
            case "short int":
            case "unsigned short int":
            case "int":
            case "unsigned int":
            case "long":
            case "unsigned long":
            case "long long":
            case "unsigned long long":
            case "float":
            case "double":
            case "long double":
            case "size_t":
            case "wchar_t":
                return true;
            default:
                return false;
            }
        }

        @safe nothrow
        void setFinalMethodFlags
        (Method method, ref bool[Method] redundantSet) {
            if (method._cls._parentClassList.length == 0) {
                return;
            }

            foreach(cls; method._cls._parentClassList) {
                Method[]* matchListPtr = method.name in classMethodMap[cls];

                if (matchListPtr is null) {
                    // We didn't find any method with this name in the
                    // parent class, so just skip it.
                    continue;
                }

                // Search all methods with the same name.
                methodLoop: foreach(otherMethod; *matchListPtr) {
                    if (method._argumentTypeList.length
                    != otherMethod._argumentTypeList.length) {
                        // Different number of arguments, carry on.
                        continue;
                    }

                    foreach(i, type; method._argumentTypeList) {
                        auto otherType = otherMethod._argumentTypeList[i];

                        if (type._typeString != otherType._typeString) {
                            // Argument types don't match, carry on.
                            continue methodLoop;
                        }
                    }

                    if (!otherMethod.isVirtual) {
                        // This is supposed to be an override of a non-virtual
                        // method, so that's nonsense. Get rid of it later.
                        redundantSet[method] = true;
                    }

                    // We got this far, it's definitely a match.
                    method._isOverride = true;
                    return;
                }
            }
        }

        // Run through everything once to collect it all.
        foreach(_0, metadata; _metadataMap) {
            foreach(_1, cls; metadata._classMap) {
                namedClassMap[cls.name] = cls;

                Method[][string] methodMap = null;

                foreach(method; cls._methodList) {
                    Method[]* arrayPtr = method.name in methodMap;

                    if (arrayPtr) {
                        (*arrayPtr) ~= method;
                    } else {
                        methodMap[method.name] = [method];
                    }
                }

                classMethodMap[cls] = methodMap;
            }

            foreach(_1, enm; metadata._enumMap) {
                namedEnumMap[enm.name] = enm;
            }
        }

        // Now we have everything, run again to build a nested structure.
        foreach(_0, metadata; _metadataMap) {
            // Run through types to set the isPrimitive flag.
            // We have to do this because the enum
            foreach(_1, type; metadata._typeMap) {
                if (type in checkedTypes) {
                    continue;
                }

                checkedTypes[type] = true;

                type._isPrimitive = isReallyPrimitive(type);
            }

            foreach(_1, cls; metadata._classMap) {
                string namespace = namespaceForName(cls.name);

                if (namespace.length > 0) {
                    // Nest this class inside a namespace.
                    tryNestInClass(namespace, cls);
                } else {
                    // Put this class at the top level.
                    _topLevelClassList ~= cls;
                }

                bool[Method] redundantSet = null;

                foreach(method; cls._methodList) {
                    setFinalMethodFlags(method, redundantSet);

                    if (method.isAbstract) {
                        // Mark the class as being an abstract class
                        // if it contains at least one abstract method.
                        cls._isAbstract = true;
                    }
                }

                if (redundantSet.length > 0) {
                    // We had some redundant methods, so we have to replace
                    // the method list with another which doesn't
                    // contain those redundant methods.
                    auto newMethodList = new Method[
                        cls._methodList.length - redundantSet.length
                    ];

                    size_t newIndex = 0;

                    foreach(method; cls._methodList) {
                        if (method !in redundantSet) {
                            newMethodList[newIndex++] = method;
                        }
                    }

                    cls._methodList = newMethodList;
                }
            }

            foreach(_1, enm; metadata._enumMap) {
                string namespace = namespaceForName(enm.name);

                if (namespace.length > 0) {
                    // Nest this enum inside a namespace.
                    tryNestInClass(namespace, enm);
                } else {
                    // Put this enum at the top level.
                    _topLevelEnumList ~= enm;
                }
            }
        }

        // Throw the metadata at the garbage collector, we're done.
        _metadataMap = null;
    }
public:
    /**
     * Returns: The list of top level classes contained in this container.
     */
    @safe pure nothrow
    @property inout(Class[]) topLevelClassList() inout {
        return _topLevelClassList;
    }

    /**
     * Returns: The list of top level enums contained in this container.
     */
    @safe pure nothrow
    @property inout(Enum[]) topLevelEnumList() inout {
        return _topLevelEnumList;
    }
}
