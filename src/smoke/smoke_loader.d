module smoke.smoke_loader;

import std.algorithm;
import std.array;
import std.typecons;
import std.stdio;

import smoke.smoke;
import smoke.smoke_util;
import smoke.string_util;
import smoke.smoke_cwrapper;

pure @safe nothrow
private ref V1 setDefault(K, V1, V2)(ref V1[K] map, K key, lazy V2 def)
if (is(V2 : V1)) {
    V1* valPtr = key in map;

    if (valPtr != null) {
        return *valPtr;
    }

    map[key] = def();

    return map[key];
}

private extern(C++) class SmokeClassBinding : SmokeBinding {
    ClassLoader _loader;

    pure @safe nothrow
    this (ClassLoader loader) in {
        assert(loader !is null);
    } body {
        _loader = loader;
    }

    extern(C++) override void deleted(Smoke.Index classID, void* obj) {
        _loader.objectDeleted(obj);
    }

    extern(C++) override bool callMethod(Smoke.Index methodIndex, void* obj,
    void* args, bool isAbstract= false) body {
        Smoke.Method* method = _loader._smoke._methods + methodIndex;

        Smoke.StackItem[] argumentList = null;

        if (args) {
            argumentList = (cast(Smoke.StackItem*) args)[0 .. method.numArgs];
        }

        return _loader.methodCall(obj, method, argumentList, isAbstract);
    }

    extern(C++) override char* className(Smoke.Index classID) {
        return null;
    }

    extern(C++) override void __padding() {}
}

/**
 * This class represents a wrapper around SMOKE data for loading
 * and calling function pointers quickly for a given class.
 */
final class ClassLoader {
private:
    Smoke* _smoke;
    Smoke.Class* _cls;
    SmokeClassBinding _binding;
    // We'll pack some methods in here, which may have many overloads.
    const(Smoke.Method*)[][string] _overloadedMethodMap;

    pure @safe nothrow
    this(Smoke* smoke, Smoke.Class* cls)
    in {
        assert(smoke !is null);
        assert(cls !is null);
    } body {
        _smoke = smoke;
        _cls = cls;

        _binding = new SmokeClassBinding(this);
    }

    pure @safe nothrow
    void addMethod(string methodName, const(Smoke.Method*) method) {
        _overloadedMethodMap.setDefault(methodName, null) ~= method;
    }

    pure @safe nothrow
    const(Smoke.Method*)[] methodMatches(string methodName) const {
        auto ptr = methodName in _overloadedMethodMap;

        return ptr !is null ? *ptr : null;
    }

    void objectDeleted (void* object) {
        // TODO: Handle object deleted signals here.
    }

    bool methodCall(void* object, Smoke.Method* method,
    ref const(Smoke.StackItem[]) argumentList, bool isAbstract) {
        // TODO: Handle method calls here.

        return false;
    }
public:
    /**
     * Call a constructor for a class with a method index and some
     * arguments.
     *
     * Returns: The pointer to the object which was constructed.
     */
    @trusted
    void* callConstructor(A...)(Smoke.Index methodIndex, A a) const {
        static if (A.length == 0) {
            // If we have a constructor of zero arguments, create a stack
            // with enough space for passing the binding.
            Smoke.StackItem[2] stack;
        } else {
            auto stack = createSmokeStack(a);
        }

        _cls.classFn(methodIndex, null, stack.ptr);

        // If calling a constructor, re-use the stack to pass the binding.
        stack[1].s_voidp = cast(void*) _binding;
        _cls.classFn(0, stack[0].s_voidp, stack.ptr);

        return stack[0].s_voidp;
    }

    /**
     * Call a method for a class with a method index and some arguments.
     *
     * Returns: A union type representing the return value.
     */
    @trusted
    Smoke.StackItem callMethod(A...)
    (Smoke.Index methodIndex, void* object, A a) const {
        auto stack = createSmokeStack(a);

        _cls.classFn(methodIndex, object, stack.ptr);

        return stack[0];
    }

    /**
     * Search for a method with a given name and list of argument types.
     * The types must be specified exactly as they are in C++.
     */
    @trusted pure nothrow
    immutable(Smoke.Index) findMethodIndex
    (string methodName, string[] argumentTypes ...) const {
        import std.c.string;

        methLoop: foreach(meth; methodMatches(methodName)) {
            if (meth.numArgs != argumentTypes.length) {
                continue;
            }

            // Slice the argument index list out.
            auto argIndexList = _smoke._argumentList[
                meth.args .. meth.args + meth.numArgs];

            foreach(i, argIndex; argIndexList) {
                // Skip to the type pointer.
                auto type = _smoke._types + argIndex;

                // FIXME: This is probably buggy, use a safer comparison
                // function.
                if (strcmp(argumentTypes[i].ptr, type.name)) {
                    continue methLoop;
                }
            }

            return meth.method;
        }

        return 0;
    }

    /**
     * Search for a method with a given name and list of argument types.
     * The types must be specified exactly as they are in C++.
     *
     * If the method cannot be found, throw an exception.
     */
    @trusted pure
    immutable(Smoke.Index) demandMethodIndex
    (string methodName, string[] argumentTypes ...) const {
        import std.exception;

        auto index = findMethodIndex(methodName, argumentTypes);

        enforce(
            index != 0,
            "Demanded method not found!"
            ~ "\nMethod was: " ~ methodName
        );

        return index;
    }
}

struct SmokeLoader {
private:
    ClassLoader[string] _classMap;

    @trusted pure
    void loadClassMethodData(Smoke* smoke) {
        auto classList = smoke.classList;
        auto methNameList = smoke.methodNameList;

        // Copy out all of the class names up front, we'll need them.
        auto classNameList = classList
        .map!(x => x.className.toSlice.idup)
        .array;

        foreach(const ref meth; smoke.methodList) {
            // TODO: Filter fields and signals out? Are they in there?

            // Smoke "Methods" aren't *just* methods, they can be many things.
            if (meth.name >= methNameList.length
            || meth.classID >= classList.length) {
                continue;
            }

            // Reference our previous copy to get the class name as a string.
            string className = classNameList[meth.classID];

            if (className.length == 0) {
                continue;
            }

            // get/create class data for the class for this method.
            ClassLoader classData = _classMap.setDefault(className,
                // Skip to the class pointer directly.
                new ClassLoader(smoke, smoke._classes + meth.classID)
            );

            string methodName = methNameList[meth.name].toSlice.idup;

            classData.addMethod(methodName, &meth);
        }
    }

public:
    @trusted pure
    static immutable(SmokeLoader) create(Smoke*[] smokeList ...) {
        SmokeLoader loader;

        foreach(smoke; smokeList) {
            loader.loadClassMethodData(smoke);
        }

        // FIXME: This cast shouldn't be needed.
        return cast(immutable) loader;
    }

    @disable this(this);

    pure @trusted
    immutable(ClassLoader) findClass(string className) const {
        return cast(immutable) _classMap.get(className, null);
    }

    pure @trusted
    immutable(ClassLoader) demandClass(string className) const {
        import std.exception;

        auto cls = findClass(className);

        enforce(
            cls !is null,
            "Demanded class not found!"
            ~ "\nClass was: " ~ className
        );

        return cls;
    }
}

/// A meaningless value used for skipping constructors in generated files.
enum Nothing : byte { nothing }
