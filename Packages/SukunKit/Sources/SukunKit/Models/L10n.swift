import Foundation

/// Localization helper for strings that live in SukunKit's String Catalog.
/// Falls back to the English default when a key is missing.
public enum L10n {
    public static func string(_ key: String, default value: String) -> String {
        Bundle.module.localizedString(forKey: key, value: value, table: nil)
    }

    public static func format(_ key: String, default value: String, _ args: CVarArg...) -> String {
        String(format: string(key, default: value), locale: Locale.current, arguments: args)
    }
}
