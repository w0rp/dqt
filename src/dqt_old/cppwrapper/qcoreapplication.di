module dqt.cppwrapper.qcoreapplication;

extern(C) void* dqt_QCoreApplication_ctor_int_charSS(
    int* argc, char** argv);
extern(C) void dqt_QCoreApplication_exit(int returnCode);
extern(C) int dqt_QCoreApplication_exec();
