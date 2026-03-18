import Foundation
import UniformTypeIdentifiers

/// Represents whether a file type is identified by a URL scheme (mailto, http) or a file extension (pdf, txt).
enum FileTypeKind: Sendable {
    case urlScheme(String)       // e.g. "mailto", "https", "ftp"
    case fileExtension(String)   // e.g. "pdf", "txt", "json"
}

/// A single file type entry shown in the UI.
struct FileTypeEntry: Identifiable, Sendable {
    let id: String               // unique key, e.g. "mailto" or "ext-pdf"
    let displayName: String      // e.g. "Email (mailto)"
    let systemImage: String      // SF Symbol name
    let kind: FileTypeKind

    var sortKey: String { displayName }
}

/// Groups file types into tabs.
enum FileTypeCategory: String, CaseIterable, Identifiable, Sendable {
    case main = "Apps"
    case coding = "Code"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .main: return "app.badge.checkmark"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        }
    }

    var entries: [FileTypeEntry] {
        switch self {
        case .main:
            return Self.mainEntries
        case .coding:
            return Self.codingEntries
        }
    }

    // MARK: - Apps

    private static let mainEntries: [FileTypeEntry] = [
        FileTypeEntry(
            id: "mailto",
            displayName: "Email (mailto)",
            systemImage: "envelope",
            kind: .urlScheme("mailto")
        ),
        FileTypeEntry(
            id: "https",
            displayName: "Web Browser (http/s)",
            systemImage: "globe",
            kind: .urlScheme("https")
        ),
        FileTypeEntry(
            id: "ftp",
            displayName: "File Transfer (ftp)",
            systemImage: "arrow.up.arrow.down.circle",
            kind: .urlScheme("ftp")
        ),
        FileTypeEntry(
            id: "ext-pdf",
            displayName: "PDF Documents",
            systemImage: "doc.richtext",
            kind: .fileExtension("pdf")
        ),
        FileTypeEntry(
            id: "ext-txt",
            displayName: "Text Files (.txt)",
            systemImage: "doc.text",
            kind: .fileExtension("txt")
        ),
        FileTypeEntry(
            id: "ext-md",
            displayName: "Markdown (.md)",
            systemImage: "text.document",
            kind: .fileExtension("md")
        ),
        FileTypeEntry(
            id: "ext-xlsx",
            displayName: "Spreadsheets (.xlsx)",
            systemImage: "tablecells",
            kind: .fileExtension("xlsx")
        ),
        FileTypeEntry(
            id: "ext-docx",
            displayName: "Documents (.docx)",
            systemImage: "doc",
            kind: .fileExtension("docx")
        ),
        FileTypeEntry(
            id: "ext-rtf",
            displayName: "Rich Text (.rtf)",
            systemImage: "doc.richtext.fill",
            kind: .fileExtension("rtf")
        ),
        FileTypeEntry(
            id: "ext-html",
            displayName: "HTML Files (.html)",
            systemImage: "safari",
            kind: .fileExtension("html")
        ),
        FileTypeEntry(
            id: "ext-csv",
            displayName: "CSV Files (.csv)",
            systemImage: "tablecells.badge.ellipsis",
            kind: .fileExtension("csv")
        ),
        FileTypeEntry(
            id: "ext-mhl",
            displayName: "Media Hash List (.mhl)",
            systemImage: "checkmark.seal",
            kind: .fileExtension("mhl")
        ),
    ]

    // MARK: - Code

    private static let codingEntries: [FileTypeEntry] = [
        FileTypeEntry(
            id: "ext-json",
            displayName: "JSON (.json)",
            systemImage: "curlybraces",
            kind: .fileExtension("json")
        ),
        FileTypeEntry(
            id: "ext-yaml",
            displayName: "YAML (.yaml)",
            systemImage: "list.bullet.indent",
            kind: .fileExtension("yaml")
        ),
        FileTypeEntry(
            id: "ext-toml",
            displayName: "TOML (.toml)",
            systemImage: "gearshape.2",
            kind: .fileExtension("toml")
        ),
        FileTypeEntry(
            id: "ext-plist",
            displayName: "Property List (.plist)",
            systemImage: "list.bullet.rectangle",
            kind: .fileExtension("plist")
        ),
        FileTypeEntry(
            id: "ext-mobileconfig",
            displayName: "Mobile Config (.mobileconfig)",
            systemImage: "iphone.gen3",
            kind: .fileExtension("mobileconfig")
        ),
        FileTypeEntry(
            id: "ext-xml",
            displayName: "XML (.xml)",
            systemImage: "list.bullet.rectangle",
            kind: .fileExtension("xml")
        ),
        FileTypeEntry(
            id: "ext-sh",
            displayName: "Shell Scripts (.sh)",
            systemImage: "terminal",
            kind: .fileExtension("sh")
        ),
        FileTypeEntry(
            id: "ext-zsh",
            displayName: "Zsh Scripts (.zsh)",
            systemImage: "terminal",
            kind: .fileExtension("zsh")
        ),
        FileTypeEntry(
            id: "ext-py",
            displayName: "Python (.py)",
            systemImage: "chevron.left.forwardslash.chevron.right",
            kind: .fileExtension("py")
        ),
        FileTypeEntry(
            id: "ext-rb",
            displayName: "Ruby (.rb)",
            systemImage: "chevron.left.forwardslash.chevron.right",
            kind: .fileExtension("rb")
        ),
        FileTypeEntry(
            id: "ext-swift",
            displayName: "Swift (.swift)",
            systemImage: "swift",
            kind: .fileExtension("swift")
        ),
        FileTypeEntry(
            id: "ext-js",
            displayName: "JavaScript (.js)",
            systemImage: "curlybraces.square",
            kind: .fileExtension("js")
        ),
    ]
}
