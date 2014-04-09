import std.range;
import std.algorithm;
import std.stdio;
import std.file;
import std.path;
import std.process;

enum sourcePath = "source";

int run(string[] args) {
    return wait(spawnProcess(args));
}

/**
 * Given a filename and a new root directory, replace the
 * root directory in the filename with the given root directory.
 */
@safe pure nothrow
string replaceRoot(string inFilename, string newRoot) {
    return buildPath(chain(
        only(newRoot),
        pathSplitter(inFilename).dropOne()
    ));
}

@safe pure nothrow
string objectFilenameForSource(string sourceFilename) {
    return sourceFilename
        .replaceRoot("build")
        .stripExtension
        ~ ".o";
}

string compileSource(string sourceFilename, string objectFilename) {
    if (exists(objectFilename)) {
        // Don't generate this again if we've already got it.
        return objectFilename;
    }

    mkdirRecurse(dirName(objectFilename));

    string[] commandLine;

    if (sourceFilename.endsWith(".cpp")) {
        commandLine = [
            "g++",
            "-c", sourceFilename,
            "-o", objectFilename,
            // TODO: Determine what the path for this is and configure it.
            "-I/usr/include/qt4/"
        ];
    } else {
        commandLine = [
            "dmd",
            "-c", sourceFilename,
            "-of" ~ objectFilename,
            // TODO: Turn this off after clearing warnings.
            "-d",
            "-Isource",
            "-I../dsmoke/source",
            "-I../dstruct/source",
        ];
    }

    writeln(commandLine.join(" "));

    run(commandLine);

    return objectFilename;
}

void linkObjects(immutable(string[]) objectList, string outputFilename) {
    string[] linkCommandline = cast(string[]) chain(
        [
            "dmd",
            "-lib",
            "-of" ~ outputFilename,
        ],
        objectList
    ).array;

    if (run(linkCommandline)) {
        throw new Exception("Linking failed!");
    };
}

int main(string[] argv) {
    import std.getopt;

    bool cleanBuild = false;
    bool showHelp = false;

    try {
        getopt(
            argv,
            "clean", &cleanBuild,
            "help", &showHelp,
        );
    } catch (Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    if (showHelp || argv.length > 1) {
        enum string[] usage = [
            "rdmd build.d [--clean]",
            "",
            "Build the DQt library.",
            "",
            "  --clean  Clean up build files first.",
            "  --help   Print this help message.",
        ];

        foreach(line; usage) {
            stderr.writeln(line);
        }

        return 1;
    }

    // Build the code generator first.
    chdir("generator");

    if (run(["dub", "build", "-q"])) {
        stderr.writeln("Building the code generator failed!");
        return 1;
    }

    chdir("..");

    if (!exists(sourcePath)) {
        mkdir(sourcePath);
    }

    // Run that code generator now.
    if (run([buildPath("generator", "bin", "dqt_generator")])) {
        stderr.writeln("Running the code generator failed!");
        return 1;
    }

    // Find all the source files now we've generated them.
    immutable sourceList = cast(immutable)
        dirEntries(sourcePath, SpanMode.breadth)
        .filter!(x => isFile(x))
        .map!(x => x.name)
        .filter!(x => x.endsWith(".d") || x.endsWith(".cpp"))
        .array;

    if (!exists("build")) {
        mkdir("build");
    }

    // Get all of the destination filenames for the objects.
    immutable objectList = cast(immutable)
        sourceList
        .map!objectFilenameForSource
        .array;

    if (cleanBuild) {
        // Remove all objects first in a clean build.
        foreach(filename; objectList.filter!exists) {
            remove(filename);
        }
    }

    // Build all of the sources.
    foreach(sourceFilename, objectFilename; zip(sourceList, objectList)) {
        compileSource(sourceFilename, objectFilename);
    }

    // Link the object code into the final library.
    try {
        linkObjects(objectList, buildPath("lib", "libdqt.a"));
    } catch (Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}
