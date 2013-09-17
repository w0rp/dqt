import dqt.smoke.all;

Method* easyFindMethod(Smoke smoke, const(char)* className, const(char*) methodName) {
    Method method;

    ModuleIndex moduleIndex = smoke.findMethod(className, methodName);

    debug {
        import std.string : format;

        assert(moduleIndex.hasExactMatch,
            "%s %s did not produce a single match!"
            .format(className, methodName)
        );
    }

    Index methodIndex = moduleIndex.methodIndex();

    return smoke.method(methodIndex);
}

void* createApp() {
    import core.runtime;

    Method* method = qtgui_Smoke.easyFindMethod(
        "QApplication", "QApplication$@");

    ClassFn fun = qtgui_Smoke.classFunction(method.classID);

    CArgs args = Runtime.cArgs;

    auto stack = createSmokeStack(&args.argc, args.argv);

    fun(method.method, null, stack.ptr);

    return stack[0].s_voidp;
}

// There's copy-and-paste here, but it should hopefully make this example
// easier to understand.

int execApp(void* app) {
    Method* method = qtgui_Smoke.easyFindMethod("QCoreApplication", "exec");

    ClassFn fun = qtgui_Smoke.classFunction(method.classID);

    auto stack = createSmokeStack();

    fun(method.method, null, stack.ptr);

    return stack[0].s_int;
}

void* createLabel(const(char)* text) {
    Method* method = qtgui_Smoke.easyFindMethod("QLabel", "QLabel$#$");

    ClassFn fun = qtgui_Smoke.classFunction(method.classID);

    // Qt::Dialog is the 0 here.
    auto stack = createSmokeStack(cast(void*) text, null, 0);

    fun(method.method, null, stack.ptr);

    return stack[0].s_voidp;
}

void showLabel(void* label) {
    Method* method = qtgui_Smoke.easyFindMethod("QWidget", "show");

    ClassFn fun = qtgui_Smoke.classFunction(method.classID);

    auto stack = createSmokeStack();

    fun(method.method, null, stack.ptr);
}

int main() {
    init_qt_Smoke();

    scope(exit) delete_qt_Smoke();

    init_qtcore_Smoke();

    scope(exit) delete_qtcore_Smoke();

    init_qtgui_Smoke();

    scope(exit) delete_qtgui_Smoke();

    auto app = createApp();

    auto label = createLabel("Hello World!");

    showLabel(label);

    return execApp(app);
}
