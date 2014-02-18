module smoke.smoke_util;

import core.stdc.config : c_long, c_ulong;

import smoke.smoke;
import smoke.smoke_cwrapper;

// This function is very general, and belongs elsewhere.
pure @system nothrow
inout(char)[] toSlice(inout(char)* cString) {
    import std.c.string;

    return cString == null ? null : cString[0 .. strlen(cString)];
}

@property pure @safe nothrow
const(char*) moduleName(const(Smoke*) smoke) {
    return smoke._moduleName;
}

@property pure @trusted nothrow
package const(Smoke.Class)[] classList(const(Smoke*) smoke) {
    return smoke._classes[0 .. smoke._numClasses];
}

@property pure @trusted nothrow
package const(Smoke.Method)[] methodList(const(Smoke*) smoke) {
    return smoke._methods[0 .. smoke._numMethods];
}

@property pure @trusted nothrow
package const(char*)[] methodNameList(const(Smoke*) smoke) {
    return smoke._methodNames[0 .. smoke._numMethodNames];
}

@property pure @safe nothrow
bool isConstructor (const(Smoke.Method*) meth)
in {
    assert(meth !is null);
} body {
    return (meth.flags & Smoke.MethodFlags.mf_ctor) != 0;
}

@property pure @safe nothrow
bool isStatic (const(Smoke.Method*) meth)
in {
    assert(meth !is null);
} body {
    return (meth.flags & Smoke.MethodFlags.mf_static) != 0;
}

@property pure @safe nothrow
bool isInstance (const(Smoke.Method*) meth)
in {
    assert(meth !is null);
} body {
    return !meth.isConstructor && !meth.isStatic;
}

/**
 * Create a stack of arguments for SMOKE.
 *
 * One extra item will be prepended to the array created, which represents
 * the return value. So the first argument will be set at index 1, and so on.
 *
 * Params:
 *     a... = A stack item.
 *
 * Returns:
 *    A SMOKE stack item array containing the values given.
 */
Smoke.StackItem[A.length + 1] createSmokeStack(A...)(A a) {
    import std.traits : isPointer;

    // The stack also includes the return value.
    Smoke.StackItem[A.length + 1] arr;

    foreach(index, value; a) {
        alias typeof(value) T;

        static if(isPointer!T || is(T == typeof(null))) {
            // The same as s_class
            arr[index + 1].s_voidp = cast(void*) value;
        } else static if(is(T == bool)) {
            arr[index + 1].s_bool = value;
        } else static if(is(T == char) || is(T == byte)) {
            arr[index + 1].s_char = value;
        } else static if(is(T == ubyte)) {
            arr[index + 1].s_uchar = value;
        } else static if(is(T == short)) {
            arr[index + 1].s_short = value;
        } else static if(is(T == ushort)) {
            arr[index + 1].s_ushort = value;
        } else static if(is(T == int)) {
            arr[index + 1].s_int = value;
        } else static if(is(T == uint)) {
            arr[index + 1].s_uint = value;
        } else static if(is(T == c_long)) {
            // The same as s_enum
            arr[index + 1].s_long = value;
        } else static if(is(T == c_ulong)) {
            arr[index + 1].s_ulong = value;
        } else static if(is(T == float)) {
            arr[index + 1].s_float = value;
        } else static if(is(T == double)) {
            arr[index + 1].s_double = value;
        } else {
            static assert(false, "Invalid type for createStack!");
        }
    }

    return arr;
}
