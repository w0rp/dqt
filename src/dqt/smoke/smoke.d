module dqt.smoke.smoke;

import core.stdc.config : c_long, c_ulong;

struct Smoke {
// Define all of the public nested data.
public:
    /// The index type for Smoke.
    alias short Index;

    // typedef void (*ClassFn)(Index method, void* obj, Stack args);
    /// A class method function
    alias void function(Index method, void* object, StackItem* args) ClassFn;

    //typedef void* (*CastFn)(void* obj, Index from, Index to);
    /// A cast function
    alias void* function(void* obj, Index from, Index to) CastFn;

    // typedef void (*EnumFn)(EnumOperation, Index, void*&, long&);
    /// An enum function
    alias void function(EnumOperation, Index, void**, c_long*) EnumFn;

    /// A Smoke module.
    struct Smoke {
        void* ptr;
    }

    /// A Smoke module index type.
    struct ModuleIndex {
        ///
        Smoke* smoke;
        ///
        Index index;
    }

    /// A SMOKE value.
    union StackItem {
        ///
        void* s_voidp;
        ///
        bool s_bool;
        ///
        byte s_char;
        ///
        ubyte s_uchar;
        ///
        short s_short;
        ///
        ushort s_ushort;
        ///
        int s_int;
        ///
        uint s_uint;
        ///
        c_long s_long;
        ///
        c_ulong s_ulong;
        ///
        float s_float;
        ///
        double s_double;
        ///
        c_long s_enum;
        ///
        void* s_class;
    }

    ///
    enum EnumOperation {
        ///
        EnumNew,
        ///
        EnumDelete,
        ///
        EnumFromLong,
        ///
        EnumToLong
    }

    /// SMOKE Method flags.
    enum MethodFlags : ushort {
        /// Method is static
        mf_static      = 0x01,
        /// Method is const
        mf_const       = 0x02,
        /// Copy constructor
        mf_copyctor    = 0x04,
        /// For internal use only
        mf_internal    = 0x08,
        /// An enum value
        mf_enum        = 0x10,
        /// A constructor
        mf_ctor        = 0x20,
        /// A destructor
        mf_dtor        = 0x40,
        /// Method is protected
        mf_protected   = 0x80,
        // Accessor method for a field.
        mf_attribute   = 0x100,
        /// Accessor method for a property
        mf_property    = 0x200,
        /// Method is virtual.
        mf_virtual     = 0x400,
        /// Method is pure virtual
        mf_purevirtual = 0x800,
        /// Method is a signal.
        mf_signal      = 0x1000,
        /// Method is a slot.
        mf_slot        = 0x2000,
        /// method is an 'explicit' constructor
        mf_explicit    = 0x4000
    }

    /// SMOKE method information.
    struct Method {
        /// Index into classes
        Index classID;
        /// Index into methodNames; real name
        Index name;
        /// Index into argumentList
        Index args;
        /// Number of arguments
        ubyte numArgs;
        /// MethodFlags (const/static/etc...)
        ushort flags;
        /// Index into types for the return type
        Index ret;
        /// Passed to Class.classFn, to call method
        Index method;
    }

    /**
     * One MethodMap entry maps the munged method prototype
     * to the Method entry.
     *
     * The munging works this way:
     * $ is a plain scalar
     * # is an object
     * ? is a non-scalar (reference to array or hash, undef)
     *
     * e.g. QApplication(int &, char **) becomes QApplication$?
     */
    struct MethodMap {
        /// Index into classes
        Index classId;
        /// Index into methodNames; munged name
        Index name;
        /// Index into methods
        Index method;
    }

    /// SMOKE class flags.
    enum ClassFlags : ushort {
        /// Has a constructor
        cf_constructor = 0x01,
        /// Has a copy constructor
        cf_deepcopy    = 0x02,
        /// Has a virtual destructor
        cf_virtual     = 0x04,
        /// Is a namespace
        cf_namespace   = 0x08,
        /// defined elsewhere
        cf_undefined   = 0x10
    }

    /// SMOKE class information.
    struct Class {
        /// Name of the class.
        const(char) *className;
        /// Whether the class is in another module.
        bool external;
        /// Index into inheritanceList
        Index _parents;
        /// Calls any method in the class
        ClassFn classFn;
        /// Handles enum pointers
        EnumFn enumFn;
        /// ClassFlags
        ushort flags;
        /// The size of the class.
        uint size;
    }

    /// The type ID, as set in TypeFlags.
    enum TypeId : ubyte {
        /// void*
        t_voidp,
        /// bool
        t_bool,
        /// char
        t_char,
        /// unsigned char
        t_uchar,
        /// short
        t_short,
        /// unsigned short
        t_ushort,
        /// int
        t_int,
        /// unsigned int
        t_uint,
        /// long
        t_long,
        /// unsigned long
        t_ulong,
        /// float
        t_float,
        /// double
        t_double,
        /// enum?
        t_enum,
        /// class?
        t_class,
        /// Number of pre-defined types.
        t_last
    }

    /**
     * Type flags.
     *
     * Only one of tf_stack, tf_ptr, or tf_ref should be set at a time.
     *
     * The first 4 bits indicate the TypeId value, i.e. which field
     * of the StackItem union is used.
     */
    enum TypeFlags : ushort {
        /// The first 4 bits.
        tf_elem  = 0x0F,
        /// Stored on the stack, 'type'
        tf_stack = 0x10,
        /// Pointer, 'type*'
        tf_ptr   = 0x20,
        /// Reference, 'type&'
        tf_ref   = 0x30,
        /// Const argument
        tf_const = 0x40
    }

    struct Type {
        /// Stringified type name
        const(char)* name;
        /// Index into classes. -1 for none
        Index classId;
        /// TypeFlags
        ushort flags;
    }

    ///

// Define the hidden struct data.
public:
    /// The static class map for loading classes.
    //static shared ModuleIndex[string] classMap = null;

    /// The module name.
    const(char)* _moduleName;

    /// The classes array defines every class.
    Class* _classes;
    /// The size of the classes array.
    Index _numClasses;

    /// The methods array defines every method in every class.
    Method* _methods;
    /// The size of the methods array.
    Index _numMethods;

    /// methodMaps maps the munged method prototypes to the methods entries.
    MethodMap* _methodMaps;
    /// The size of the methodMaps array.
    Index _numMethodMaps;

    /// Array of method names, for Method.name and MethodMap.name
    const(char)** _methodNames;
    /// The size of the methodNames array.
    Index _numMethodNames;

    /// List of all types needed by the methods (arguments and return values)
    Type* _types;
    /// The size of the types array.
    Index _numTypes;

    /**
     * Groups of Indexes (0 separated) used as super class lists.
     * For classes with super classes: Class.parents = index into this array.
     */
    Index* _inheritanceList;

    /**
     * Groups of type IDs (0 separated), describing the types of argument
     * for a method.
     *
     * Method.args = index into this array.
     */
    Index* _argumentList;

    /**
     * Groups of method prototypes with the same number of arguments,
     * but different types.
     *
     * Used to resolve overloading.
     */
    Index* _ambiguousMethodList;

    /**
     * Function used for casting from/to the classes defined by this module.
     */
    CastFn _castFn;
}
