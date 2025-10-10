import UIKit
import Foundation

extension Bundle {
    var displayName: String {
        if let name = infoDictionary?["CFBundleDisplayName"] as? String {
            return name
        }
        if let name = infoDictionary?["CFBundleName"] as? String {
            return name
        }
        return "CycloNotes"
    }
    
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    var appBuild: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
}

extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier.append(String(UnicodeScalar(UInt8(value))))
        }
        
        if identifier.starts(with: "iPhone") {
            return "iPhone"
        }
        
        if identifier.starts(with: "iPad") {
            return "iPad"
        }
        
        if identifier.starts(with: "iPod") {
            return "iPod touch"
        }
        
        if (identifier.contains("x86_64") || identifier.contains("arm64")) &&
            ProcessInfo().environment["SIMULATOR_DEVICE_NAME"] != nil {
            return "Simulator"
        }
        
        return identifier
    }
}
