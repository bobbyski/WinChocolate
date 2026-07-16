import Foundation

// ViewInfo — dump the views, properties, outlets and actions a Swift UI source
// file builds, as markdown on stdout.
//
//   swift run ViewInfo ../DemoApplication/main.swift > mac.md
//   swift run ViewInfo a.swift b.swift | less
//
// Pipe two implementations to files and diff them to spot a control, property,
// or action that one side is missing.

let arguments = Array(CommandLine.arguments.dropFirst())

guard !arguments.isEmpty, !arguments.contains("-h"), !arguments.contains("--help") else {
    let usage = """
    ViewInfo — dump views, properties and actions from Swift source as markdown.

    USAGE:
      ViewInfo <file.swift> [more.swift ...]

    Markdown goes to stdout so it can be piped or redirected:
      swift run ViewInfo Demo/DemoApplication/main.swift > appkit.md
      diff appkit.md winchocolate.md

    Each view gets its declaration, initializer, parent, a table of every
    property set on it, and each attached action as a code block followed by the
    other controls that action touches.
    """
    print(usage)
    exit(arguments.isEmpty ? 1 : 0)
}

let collector = SourceCollector()

for path in arguments {
    guard FileManager.default.fileExists(atPath: path) else {
        FileHandle.standardError.write(Data("error: no such file: \(path)\n".utf8))
        exit(1)
    }
    do {
        try collector.add(file: path)
    } catch {
        FileHandle.standardError.write(Data("error: could not read \(path): \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

print(MarkdownReport(report: collector.finish()).render())

