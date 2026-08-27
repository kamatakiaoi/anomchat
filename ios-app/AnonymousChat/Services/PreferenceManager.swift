import Foundation

public class PreferenceManager: ObservableObject {
    public static let shared = PreferenceManager()

    private let defaults = UserDefaults.standard

    private let keyServerHost = "server_host"
    private let keyServerPort = "server_port"
    private let keyAuthKey = "auth_key"
    private let keyRecoveryKey = "recovery_key"
    private let keyTimezone = "pref_timezone"
    private let keyDeviceMac = "chat_device_mac"
    private let keySoundEnabled = "pref_sound_enabled"

    public static let defaultServerHost = "snow.pikamc.vn"
    public static let defaultServerPort = 25222

    @Published public var serverHost: String {
        didSet { defaults.set(serverHost, forKey: keyServerHost) }
    }

    @Published public var serverPort: Int {
        didSet { defaults.set(serverPort, forKey: keyServerPort) }
    }

    @Published public var authKey: String? {
        didSet { defaults.set(authKey, forKey: keyAuthKey) }
    }

    @Published public var recoveryKey: String? {
        didSet { defaults.set(recoveryKey, forKey: keyRecoveryKey) }
    }

    @Published public var timezone: String {
        didSet { defaults.set(timezone, forKey: keyTimezone) }
    }

    @Published public var isSoundEnabled: Bool {
        didSet { defaults.set(isSoundEnabled, forKey: keySoundEnabled) }
    }

    @Published public var deviceMac: String

    private init() {
        let savedHost = defaults.string(forKey: keyServerHost) ?? PreferenceManager.defaultServerHost
        let savedPort = defaults.integer(forKey: keyServerPort)
        self.serverHost = savedHost.isEmpty ? PreferenceManager.defaultServerHost : savedHost
        self.serverPort = savedPort > 0 ? savedPort : PreferenceManager.defaultServerPort
        self.authKey = defaults.string(forKey: keyAuthKey)
        self.recoveryKey = defaults.string(forKey: keyRecoveryKey)
        self.timezone = defaults.string(forKey: keyTimezone) ?? "vn"
        self.isSoundEnabled = defaults.object(forKey: keySoundEnabled) == nil ? true : defaults.bool(forKey: keySoundEnabled)

        // Initialize MAC address
        if let existingMac = defaults.string(forKey: keyDeviceMac), !existingMac.isEmpty {
            self.deviceMac = existingMac
        } else {
            var bytes = [String]()
            for _ in 0..<6 {
                let val = Int.random(in: 0...255)
                bytes.append(String(format: "%02X", val))
            }
            let newMac = "MAC-" + bytes.joined(separator: ":")
            defaults.set(newMac, forKey: keyDeviceMac)
            self.deviceMac = newMac
        }
    }

    public func getDeviceMac() -> String {
        if !deviceMac.isEmpty {
            return deviceMac
        }
        if let mac = defaults.string(forKey: keyDeviceMac), !mac.isEmpty {
            self.deviceMac = mac
            return mac
        }
        var bytes = [String]()
        for _ in 0..<6 {
            let val = Int.random(in: 0...255)
            bytes.append(String(format: "%02X", val))
        }
        let newMac = "MAC-" + bytes.joined(separator: ":")
        defaults.set(newMac, forKey: keyDeviceMac)
        self.deviceMac = newMac
        return newMac
    }

    public var serverBaseUrl: String {
        var host = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty { host = PreferenceManager.defaultServerHost }
        let port = serverPort > 0 ? serverPort : PreferenceManager.defaultServerPort

        if !host.hasPrefix("http://") && !host.hasPrefix("https://") {
            host = "http://" + host
        }

        if let range = host.range(of: "://") {
            let afterScheme = String(host[range.upperBound...])
            if !afterScheme.contains(":") {
                return "\(host):\(port)"
            }
        }
        return host
    }
}
