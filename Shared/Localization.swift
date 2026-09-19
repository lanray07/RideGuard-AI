import Foundation

/// Looks up app-owned text in the bundle selected by the system language.
/// Unrecognised text is left unchanged; no text is sent to a translation service.
enum L10n {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
}
