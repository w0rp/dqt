module smoke.smoke_loader;

import std.algorithm;
import std.array;
import std.typecons;
import std.stdio;

import smoke.smoke;
import smoke.smoke_util;
import smoke.smoke_cwrapper;

// These functions are very general, and belong elsewhere.
pure @system nothrow
private inout(char)[] toSlice(inout(char)* cString) {
    import std.c.string;

    return cString == null ? null : cString[0 .. strlen(cString)];
}

pure @safe nothrow
private bool isEmptyString(inout(char*) cString) {
    return cString == null || cString[0] == '\0';
}

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

/**
 * This class represents a wrapper around SMOKE data for loading
 * and calling function pointers quickly for a given class.
 */
final class ClassData {
private:
    const(Smoke*) _smoke;
    const(Smoke.Class*) _cls;
    // We'll pack some methods in here, which may have many overloads.
    const(Smoke.Method*)[][string] _overloadedMethodMap;

    pure @safe nothrow
    this(const(Smoke*) smoke, const(Smoke.Class*) cls)
    in {
        assert(smoke !is null);
        assert(cls !is null);
    } body {
        _smoke = smoke;
        _cls = cls;
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
public:
    /**
     * Search for a method with a given name and list of argument types.
     * The types must be specified exactly as they are in C++.
     */
    @trusted pure
    immutable(Smoke.Method*) findMethod
    (string methodName, string[] argumentTypes ...) const {
        import std.c.string;

        methLoop: foreach(meth; methodMatches(methodName)) {
            if (meth.numArgs != argumentTypes.length) {
                continue;
            }

            debug {
                writeln("Possible method match...");
                writeln(methodName);
            }

            // Slice the argument index list out.
            auto argIndexList = _smoke._argumentList[
                meth.args .. meth.args + meth.numArgs];

            foreach(i, argIndex; argIndexList) {
                // Skip to the type pointer.
                auto type = _smoke._types + argIndex;

                debug {
                    writefln("Type name: %s", type.name.toSlice);
                }

                // TODO: Include const and & here?

                if (strcmp(argumentTypes[i].ptr, type.name)) {
                    continue methLoop;
                }
            }

            // FIXME: This cast shouldn't be needed.
            return cast(immutable) meth;
        }

        return null;
    }

    /**
     * Search for a method with a given name and list of argument types.
     * The types must be specified exactly as they are in C++.
     *
     * If the method cannot be found, throw an exception.
     */
    @trusted pure
    immutable(Smoke.Method*) demandMethod
    (string methodName, string[] argumentTypes ...) const {
        import std.exception;

        auto method = findMethod(methodName, argumentTypes);

        enforce(method !is null, "Demanded method not found!");

        return method;
    }

    /**
     * Given a method pointer and some arguments, call a method on
     * the smoke class.
     *
     * Params:
     *     method = A method pointer identifying the method to call.
     *     a... = Arguments to call the method with, the first must be the
     *            pointer to the class instance pointer, this should be null
     *            if no instance exists. (static methods, etc.)
     *
     * Returns: A StackItem representing the return value from C++.
     */
    Smoke.StackItem callMethod(A...)(const(Smoke.Method*) method, A a) const
    if (is(A[0] : void*))
    in {
        assert(!method.isInstance || a[0] !is null,
            "null pointer for smoke object, expected instance pointer!");
        assert(a.length - 1 == method.numArgs,
            "Stack size did not match argument count!");
    } body {
        auto stack = createSmokeStack(a[1 .. $]);

        // Forward the call to the C wrapper.
        dqt_call_ClassFn(_cls.classFn, method.method, a[0], stack.ptr);

        if (method.isConstructor) {
            // Smoke requires an extra call to make constructors work.
            dqt_bind_instance(_cls.classFn, stack[0].s_voidp);
        }

        return stack[0];
    }
}

enum QtLibraryFlag : uint {
    qtcore = 0x1,
    qtgui  = 0x2,
    all    = uint.max
}

struct SmokeLoader {
private:
    ClassData[string] _classMap;
    QtLibraryFlag _libraryFlags;

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
            ClassData classData = _classMap.setDefault(className,
                // Skip to the class pointer directly.
                new ClassData(smoke, smoke._classes + meth.classID)
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
    immutable(ClassData) findClass(string className) const {
        return cast(immutable) _classMap.get(className, null);
    }

    pure @trusted
    immutable(ClassData) demandClass(string className) const {
        import std.exception;

        auto cls = findClass(className);

        enforce(cls !is null, "Demanded class not found!");

        return cls;
    }
}

/// A meaningless value used for skipping constructors in generated files.
enum Nothing : byte { nothing }
