module dqt.smoke.smoke_cwrapper;

import dqt.smoke.smoke;

// Declare C wrapper functions.

///
extern(C) const(char*) Smoke_c_moduleName(void* smoke);

///
extern(C) const(char)* Smoke_c_className(Index classID);

// TODO: What do these C++ Smoke methods actually do?
// void* cast(void *ptr, const ModuleIndex& from, const ModuleIndex& to);
// void* cast(void *ptr, Index from, Index to);

///
extern(C) Index idType(void* smoke, const(char)* t);

///
extern(C) ModuleIndex Smoke_c_idClass(void* smoke, const(char)* c, bool external);

///
extern(C) ModuleIndex Smoke_c_findClass(void* smoke, const(char)* c);

///
extern(C) ModuleIndex Smoke_c_idMethodName(void* smoke, const(char)* m);

///
extern(C) ModuleIndex Smoke_c_findMethodName(void* smoke, const(char)* c, const(char)* m);

///
extern(C) ModuleIndex Smoke_c_idMethod(void* smoke, Index c, Index name);

///
extern(C) ModuleIndex Smoke_c_findMethod_ModuleIndex(
    void* smoke, ModuleIndex c, ModuleIndex name);

///
extern(C) ModuleIndex Smoke_c_findMethod_charS(
    void* smoke, const(char)* c, const(char)* name);

///
extern(C) ModuleIndex Smoke_c_idClass(
    void* smoke, const(char)* c, bool external);

// TODO: Wrap these static methods.

// static inline bool isDerivedFrom(const ModuleIndex& classId, const ModuleIndex& baseClassId);
// static inline bool isDerivedFrom(Smoke *smoke, Index classId, Smoke *baseSmoke, Index baseId);
// static inline bool isDerivedFrom(const char *className, const char *baseClassName);


// Replace these methods with a mechanism for copying all of the data out?

///
extern(C) Index Smoke_ModuleIndex_c_methodIndex(ModuleIndex moduleIndex);

///
extern(C) Method* Smoke_c_method(void* smoke, Index methodIndex);

///
extern(C) ClassFn Smoke_c_classFunction(void* smoke, Index classID);
