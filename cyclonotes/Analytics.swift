import Foundation

enum Analytics {
    /// Standard app and OS metadata to attach to TelemetryDeck signals
    static var standardPayload: [String: String] {
        let info = Bundle.main.infoDictionary
        let appVersion = (info?["CFBundleShortVersionString"] as? String) ?? "Unknown"
        let appBuild = (info?["CFBundleVersion"] as? String) ?? "Unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return [
            "appVersion": appVersion,
            "appBuild": appBuild,
            "osVersion": osVersion
        ]
    }

    /// Merge the standard payload with additional key/values.
    /// Additional values override any duplicate keys from the standard payload.
    static func merged(with extra: [String: String]) -> [String: String] {
        var combined = standardPayload
        for (k, v) in extra { combined[k] = v }
        return combined
    }
}
