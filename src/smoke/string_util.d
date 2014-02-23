module smoke.string_util;

import std.array;
import std.traits: isSomeString;

private template CharType(T) if(isSomeString!(T)) {
    static if (is(T : const(char)[])) {
        alias CharType = char;
    } else static if (is(T : const(wchar)[])) {
        alias CharType = wchar;
    } else {
        alias CharType = dchar;
    }
}

/**
 * In a completely unsafe manner and in O(n) runtime,
 * create a slice from a null terminated C string referencing
 * the contents of that string. No copy is made.
 *
 * null pointers will be returned as empty slices.
 *
 * Params:
 *    cString = A C null terminated string pointer.
 *
 * Returns: A view of the C string as a D slice.
 */
@system pure nothrow
inout(char)[] toSlice(inout(char)* cString) {
    import std.c.string : strlen;

    return cString == null ? null : cString[0 .. strlen(cString)];
}

/**
 * Given a mutable D string of any type, modify the string converting
 * any ASCII uppercase characters to lowercase characters.
 *
 * Characters beyond the ASCII range will not be considered.
 *
 * Params:
 *     str = A mutable string to modify.
 */
@safe pure nothrow
void toLowerInPlaceASCII(C)
(ref C[] str) if(is(C == char) || is(C == wchar) || is(C == dchar)) {
    foreach(index, character; str) {
        switch (character) {
        case 'A': .. case 'Z':
            str[index] = cast(C) (character + 32);
        break;
        default: break;
        }
    }
}

unittest {
    char[] small   = "ABC".dup;
    wchar[] medium = "ABC"w.dup;
    dchar[] large  = "ABC"d.dup;

    small.toLowerInPlaceASCII();
    medium.toLowerInPlaceASCII();
    large.toLowerInPlaceASCII();

    assert(small == "abc");
    assert(medium == "abc");
    assert(large == "abc");
}

/**
 * Given a mutable string of any type, modify the string converting
 * any ASCII lowercase characters to uppercase characters.
 *
 * Characters beyond the ASCII range will not be considered.
 *
 * Params:
 *     str = A mutable string to modify.
 */
@safe pure nothrow
void toUpperInPlaceASCII(C)
(ref C[] str) if(is(C == char) || is(C == wchar) || is(C == dchar)) {
    foreach(index, character; str) {
        switch (character) {
        case 'a': .. case 'z':
            str[index] = cast(C) (character - 32);
        break;
        default: break;
        }
    }
}

unittest {
    char[] small   = "abc".dup;
    wchar[] medium = "abc"w.dup;
    dchar[] large  = "abc"d.dup;

    small.toUpperInPlaceASCII();
    medium.toUpperInPlaceASCII();
    large.toUpperInPlaceASCII();

    assert(small == "ABC");
    assert(medium == "ABC");
    assert(large == "ABC");
}

/**
 * Given any type of D string, produce a string where
 * any ASCII lowercase characters are converted to uppercase characters.
 * The original string will not be modified, and a copy of the string
 * will be created if and only if case conversion is needed.
 *
 * Characters beyond the ASCII range will not be considered.
 *
 * Params:
 *     str = Any string to convert from.
 *
 * Returns: A converted string, which may be the same string as the input.
 */
@safe pure nothrow
String toLowerASCII(String)(String str) if(isSomeString!String) {
    alias CharType!String Char;

    bool copyNeeded = false;

    foreach(character; str) {
        if (character >= 'A' && character <= 'Z') {
            copyNeeded = true;
            break;
        }
    }

    if (!copyNeeded) {
        return str;
    }

    Char[] newString = new Char[str.length];
    newString[0 .. $] = str[0 .. $];

    newString.toLowerInPlaceASCII();

    return newString;
}

unittest {
    string small   = "ABC";
    wstring medium = "ABC";
    dstring large  = "ABC";

    assert(small.toLowerASCII == "abc");
    assert(medium.toLowerASCII == "abc");
    assert(large.toLowerASCII == "abc");

    // Test that the originals were not changed somehow.
    assert(small == "ABC");
    assert(medium == "ABC");
    assert(large == "ABC");
}


/**
 * Given any type of D string, produce a string where
 * any ASCII uppercase characters are converted to lowercase characters.
 * The original string will not be modified, and a copy of the string
 * will be created if and only if case conversion is needed.
 *
 * Characters beyond the ASCII range will not be considered.
 *
 * Params:
 *     str = Any string to convert from.
 *
 * Returns: A converted string, which may be the same string as the input.
 */
@safe pure nothrow
String toUpperASCII(String)(String str) if(isSomeString!String) {
    alias CharType!String Char;

    bool copyNeeded = false;

    foreach(character; str) {
        if (character >= 'a' && character <= 'z') {
            copyNeeded = true;
            break;
        }
    }

    if (!copyNeeded) {
        return str;
    }

    Char[] newString = new Char[str.length];
    newString[0 .. $] = str[0 .. $];

    toUpperInPlaceASCII(newString);

    return newString;
}

unittest {
    string small   = "abc";
    wstring medium = "abc";
    dstring large  = "abc";

    assert(small.toUpperASCII == "ABC");
    assert(medium.toUpperASCII == "ABC");
    assert(large.toUpperASCII == "ABC");

    // Test that the originals were not changed somehow.
    assert(small == "abc");
    assert(medium == "abc");
    assert(large == "abc");
}
