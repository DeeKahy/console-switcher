import Cocoa

/// The two streaming clients this switches between. Add a case here (and a
/// button in ChooserWindow) if a third one ever shows up.
enum GamingApp: String {
    case edge = "com.microsoft.edgemac"
    case geforceNow = "com.nvidia.gfnpc.mall"

    var displayName: String {
        switch self {
        case .edge: return "Xbox Game Pass"
        case .geforceNow: return "GeForce NOW"
        }
    }

    var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue)
    }
}
