module dqt.smoke.smokeqt_loader;

import dqt.smoke.smoke;
import dqt.smoke.smoke_util;
import dqt.smoke.smoke_cwrapper;

import std.stdio;

pure @trusted nothrow
private string computeString(const(char)* cString) {
    import std.c.string;

    return cString == null ? null : cast(string) cString[0 .. strlen(cString)];
}

void smokeqtLoad() {
    dqt_init_qtcore_Smoke();
    dqt_init_qtgui_Smoke();

    auto qtcore = cast(Smoke*) dqt_fetch_qtcore_Smoke();

    auto classList = qtcore.classList;
    auto methNameList = qtcore.methodNameList;

    foreach(meth; qtcore.methodList) {
        if (meth.name < methNameList.length) {
            if (meth.classID < classList.length) {
                classList[meth.classID].className.computeString.write();
                "::".write();
            }

            methNameList[meth.name].computeString.write();

            writeln();

            meth.numArgs.writeln();
        }
    }
}

void smokeqtUnload() {
    //Smoke.classMap = null;

    dqt_delete_qtgui_Smoke();
    dqt_delete_qtcore_Smoke();
}
