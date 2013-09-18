module dqt.smoke.smoke_util;

import core.stdc.config : c_long, c_ulong;

import dqt.smoke.smoke;
import dqt.smoke.smoke_cwrapper;


@property @safe pure nothrow
const(char)* moduleName(Smoke* smoke) {
    return smoke._moduleName;
}

@property @safe pure nothrow
package Smoke.Class[] classList(Smoke* smoke) {
    return smoke._classes[0 .. smoke._numClasses];
}

@property @safe pure nothrow
package Smoke.Method[] methodList(Smoke* smoke) {
    return smoke._methods[0 .. smoke._numMethods];
}

@property @safe pure nothrow
package const(char)*[] methodNameList(Smoke* smoke) {
    return smoke._methodNames[0 .. smoke._numMethodNames];
}


/*

private enum ModuleIndex NullModuleIndex;

Smoke.ModuleIndex findMethodName(Smoke* smoke, const char *c, const char *m) {
    ModuleIndex mni = smoke.idMethodName(m);

    if (mni.index) return mni;

    ModuleIndex cmi = smoke.findClass(c);

    if (cmi.smoke && cmi.smoke != smoke) {
        return cmi.smoke->findMethodName(c, m);
    } else if (cmi.smoke == smoke) {
        if (!smoke.classes[cmi.index].parents) return NullModuleIndex;

        for (Index p = smoke.classes[cmi.index].parents; smoke.inheritanceList[p]; p++) {
            Smoke.Index ci = inheritanceList[p];
            const char* cName = smoke.className(ci);
            ModuleIndex mi = classMap[cName].smoke->findMethodName(cName, m);

            if (mi.index) return mi;
        }
    }

    return NullModuleIndex;
}

*/


/+

/**
 * Returns: The name of the module (e.g. "qt" or "kde")
 */
const(char)* moduleName(Smoke smoke)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_moduleName(smoke.ptr);
}

/**
 * Returns: The class name for a class ID.
 */
const(char)* className(Smoke smoke, Index classID)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_className(smoke.ptr, classID);
}

///
Index idType(Smoke smoke, const(char)* t)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_idType(smoke.ptr, t);
}

///
ModuleIndex idClass(Smoke smoke, const(char)* c, bool external = false)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_idClass(smoke.ptr, c, external);
}

///
ModuleIndex findClass(Smoke smoke, const(char)* c)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_findClass(smoke.ptr, c);
}

///
ModuleIndex idMethodName(Smoke smoke, const(char)* m)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_idMethodName(smoke.ptr, m);
}

///
ModuleIndex findMethodName(Smoke smoke, const(char)* c, const(char)* m)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_findMethodName(smoke.ptr, c, m);
}

///
ModuleIndex idMethod(Smoke smoke, Index c, Index name)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_idMethod(smoke.ptr, c, name);
}

///
ModuleIndex findMethod(Smoke smoke, ModuleIndex c, ModuleIndex name)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_findMethod_ModuleIndex(smoke.ptr, c, name);
}

///
ModuleIndex findMethod(Smoke smoke, const(char)* c, const(char)* name)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_findMethod_charS(smoke.ptr, c, name);
}

///
ModuleIndex idClass(Smoke smoke, const(char)* c, bool external = false)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_idClass(smoke.ptr, c, external);
}

Index methodIndex(ModuleIndex moduleIndex)
in {
    assert(moduleIndex.smoke.ptr !is null);
    assert(!moduleIndex.hasNoMatch, "No matching method index!");
    assert(!moduleIndex.hasMultipleMatches, "Ambiguous method index!");
} body {
    return Smoke_ModuleIndex_c_methodIndex(moduleIndex);
}

+/

/**
 * Returns: true if a module index didn't match.
 */
@property @safe pure nothrow
bool hasNoMatch(in ref Smoke.ModuleIndex moduleIndex) {
    return moduleIndex.index == 0;
}

/**
 * Returns: true if a module index had many matches.
 */
@property @safe pure nothrow
bool hasMultipleMatches(in ref Smoke.ModuleIndex moduleIndex) {
    return moduleIndex.index < 0;
}

/**
 * Returns: true if a module index had an exact match for a method.
 */
@property @safe pure nothrow
bool hasExactMatch(in ref Smoke.ModuleIndex moduleIndex) {
    return moduleIndex.index > 1;
}

/+

///
Method* method(Smoke smoke, Index methodIndex)
in {
    assert(smoke.ptr !is null);
    assert(methodIndex > 0, "Invalid method index!");
} body {
    return Smoke_c_method(smoke.ptr, methodIndex);
}

ClassFn classFunction(Smoke smoke, Index classID)
in {
    assert(smoke.ptr !is null);
} body {
    return Smoke_c_classFunction(smoke.ptr, classID);
}

+/

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
            arr[index + 1].s_voidp = value;
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
