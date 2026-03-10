import Foundation

import Foundation
import OSLog

enum TVError: LocalizedError {
    case notConfigured
    case networkError(String)
    case httpError(Int, String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "TV IP not configured. Go to Settings."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .httpError(let code, let body):
            switch code {
            case 401: return "HTTP 401 – Auth failed. Check your PSK, or try leaving PSK empty."
            case 403: return "HTTP 403 – Forbidden. Enable IP control in TV Settings → Network."
            case 404: return "HTTP 404 – Endpoint not found. Check TV IP address."
            case 500: return "HTTP 500 – TV internal error. \(body.prefix(80))"
            default:  return "HTTP \(code). \(body.prefix(80))"
            }
        case .invalidResponse(let detail):
            return "Invalid response: \(detail)"
        }
    }
}

actor SonyTVService {
    static let shared = SonyTVService()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app", category: "SonyTVService")

    private var tvIP: String = ""
    private var psk: String = ""
    private var session: URLSession
    private var irccPath: String? = nil              // cached once discovered
    private var appLaunchSupported: Bool = true     // set false if TV returns error 12
    private var tvRemoteCodes: [String: String] = [:] // codes fetched from TV via getRemoteControllerInfo

    private func alternativeName(for command: IRCCCommand) -> String? {
        switch command {
        case .up:       return "CursorUp"
        case .down:     return "CursorDown"
        case .left:     return "CursorLeft"
        case .right:    return "CursorRight"
        case .confirm:  return "Enter"
        case .back:     return "Back"
        case .info:     return "Info"
        default:        return nil
        }
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
        // Load saved settings immediately
        self.tvIP = (UserDefaults.standard.string(forKey: "tv_ip") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.psk  = (UserDefaults.standard.string(forKey: "tv_psk") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func configure(ip: String, psk: String) {
        self.tvIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        self.psk  = psk.trimmingCharacters(in: .whitespacesAndNewlines)
        self.irccPath = nil  // reset so it re-discovers on next send
    }

    private func reloadFromUserDefaults() {
        self.tvIP = (UserDefaults.standard.string(forKey: "tv_ip") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.psk  = (UserDefaults.standard.string(forKey: "tv_psk") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - IRCC Command

    func syncRemoteCodes() async {
        logger.info("Syncing remote codes from TV")
        guard let codes = try? await getRemoteControllerInfo() else { 
            logger.warning("Failed to fetch remote codes from TV")
            return 
        }
        logger.info("📺 Fetched \(codes.count, privacy: .public) remote codes from TV")
        
        // Log ALL codes for diagnostic purposes
        let sortedCodes = codes.sorted { $0.name < $1.name }
        for entry in sortedCodes {
            tvRemoteCodes[entry.name] = entry.code
            logger.info("  📍 \(entry.name, privacy: .public): \(entry.code, privacy: .public)")
        }
    }

    func sendIRCC(_ command: IRCCCommand) async throws {
        // Prefer the code the TV itself reported — try the canonical name, then a known alias, else fallback to baked-in constant
        let alias = alternativeName(for: command)
        let tvCodeFromCanonical = tvRemoteCodes[command.tvName]
        let tvCodeFromAlias = alias.flatMap { tvRemoteCodes[$0] }
        let tvCode = tvCodeFromCanonical ?? tvCodeFromAlias
        let chosen = tvCode ?? command.rawValue
        
        let source = tvCodeFromCanonical != nil ? "canonical(\(command.tvName))" : 
                     tvCodeFromAlias != nil ? "alias(\(alias ?? ""))" : "hardcoded"
        logger.debug("Sending IRCC for '\(command.tvName)' - source: \(source), code: \(chosen)")

        do {
            try await sendIRCCCode(chosen)
        } catch {
            logger.warning("IRCC code failed, error: \(error.localizedDescription)")
            // If the TV-provided code caused a 500, retry once with the baked-in constant
            if case TVError.httpError(500, _) = error {
                if tvCode != nil && tvCode != command.rawValue {
                    logger.info("Retrying '\(command.tvName)' with hardcoded fallback: \(command.rawValue)")
                    try await sendIRCCCode(command.rawValue)
                    return
                }
            }
            throw error
        }
    }

    func sendIRCCCode(_ code: String) async throws {
        reloadFromUserDefaults()
        guard !tvIP.isEmpty else { throw TVError.notConfigured }

        // If we already found the working path, use it directly
        if let path = irccPath {
            try await sendIRCCToPath(path, code: code)
            return
        }

        // Auto-discover: try each known IRCC endpoint path in order
        let candidates = ["/sony/IRCC", "/sony/ircc", "/IRCC"]
        var lastError: Error = TVError.invalidResponse("No IRCC endpoint found")

        for path in candidates {
            do {
                try await sendIRCCToPath(path, code: code)
                irccPath = path  // cache the working path
                return
            } catch TVError.httpError(404, _) {
                continue  // try next path
            } catch {
                lastError = error
                break  // real error (401, 403, network), stop trying
            }
        }

        throw lastError
    }

    private func sendIRCCToPath(_ path: String, code: String) async throws {
        let soapBody = """
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
<s:Body>
<u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">
<IRCCCode>\(code)</IRCCCode>
</u:X_SendIRCC>
</s:Body>
</s:Envelope>
"""

        var request = URLRequest(url: try tvURL(path: path))
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\"", forHTTPHeaderField: "SOAPACTION")
        if !psk.isEmpty {
            request.setValue(psk, forHTTPHeaderField: "X-Auth-PSK")
        }
        request.httpBody = soapBody.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TVError.invalidResponse("No HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TVError.httpError(http.statusCode, body)
        }
    }

    // MARK: - REST API

    func restRequest(service: String, method: String, params: [[String: Any]] = []) async throws -> [String: Any] {
        reloadFromUserDefaults()
        guard !tvIP.isEmpty else { throw TVError.notConfigured }

        let body: [String: Any] = [
            "method": method,
            "params": params,
            "id": Int.random(in: 1...999),
            "version": "1.0"
        ]

        var request = URLRequest(url: try tvURL(path: "/sony/\(service)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !psk.isEmpty {
            request.setValue(psk, forHTTPHeaderField: "X-Auth-PSK")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TVError.invalidResponse("No HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TVError.httpError(http.statusCode, body)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let raw = String(data: data, encoding: .utf8) ?? "empty"
            throw TVError.invalidResponse("JSON parse failed: \(raw.prefix(100))")
        }
        // Check for API-level error in response body e.g. {"error":[7,"Illegal Argument"]}
        if let errArray = json["error"] as? [Any] {
            let code = errArray.first.map { "\($0)" } ?? "?"
            let msg  = errArray.last  as? String ?? "unknown"
            throw TVError.invalidResponse("TV error \(code): \(msg)")
        }
        return json
    }

    // MARK: - Power

    func getPowerStatus() async throws -> Bool {
        let result = try await restRequest(service: "system", method: "getPowerStatus")
        if let results = result["result"] as? [[String: Any]],
           let status = results.first?["status"] as? String {
            return status == "active"
        }
        return false
    }

    func setPowerStatus(on: Bool) async throws {
        _ = try await restRequest(service: "system", method: "setPowerStatus",
                                   params: [["status": on]])
    }

    // MARK: - Volume

    func getVolumeInfo() async throws -> [VolumeInfo] {
        let result = try await restRequest(service: "audio", method: "getVolumeInformation")
        guard let results = result["result"] as? [[[String: Any]]] else { return [] }
        return results.flatMap { $0 }.compactMap { item in
            guard let target = item["target"] as? String,
                  let volume = item["volume"] as? Int,
                  let minVol = item["minVolume"] as? Int,
                  let maxVol = item["maxVolume"] as? Int,
                  let mute = item["mute"] as? Bool else { return nil }
            return VolumeInfo(target: target, volume: volume, minVolume: minVol, maxVolume: maxVol, mute: mute)
        }
    }

    func setVolume(target: String = "speaker", volume: Int) async throws {
        _ = try await restRequest(service: "audio", method: "setAudioVolume",
                                   params: [["target": target, "volume": String(volume)]])
    }

    func setMute(mute: Bool) async throws {
        _ = try await restRequest(service: "audio", method: "setAudioMute",
                                   params: [["status": mute]])
    }

    // MARK: - Apps

    func getAppList() async throws -> [TVApp] {
        let result = try await restRequest(service: "appControl", method: "getApplicationList")
        guard let results = result["result"] as? [[[String: Any]]] else { return [] }
        return results.flatMap { $0 }.compactMap { item in
            guard let title = item["title"] as? String,
                  let uri = item["uri"] as? String else { return nil }
            return TVApp(title: title, uri: uri, iconURL: item["icon"] as? String)
        }
    }

    func launchApp(uri: String, title: String) async throws {
        // 1. IRCC for apps with dedicated remote buttons
        if let ircc = irccCodeForApp(uri: uri, title: title) {
            try await sendIRCCCode(ircc)
            return
        }

        // 2. setActiveApplication (appControl service)
        if appLaunchSupported {
            do {
                _ = try await restRequest(service: "appControl", method: "setActiveApplication",
                                           params: [["uri": uri]])
                return
            } catch TVError.invalidResponse(let msg) where msg.contains("12") {
                appLaunchSupported = false
                // fall through to next method
            } catch {
                throw error
            }
        }

        // 3. setPlayContent (avContent service) — works on some firmware versions
        do {
            _ = try await restRequest(service: "avContent", method: "setPlayContent",
                                       params: [["uri": uri]])
            return
        } catch {
            // All methods exhausted
            throw TVError.invalidResponse("Cannot launch \"\(title)\" via API on this TV.\nPress Home on the remote tab to go to the home screen, then open the app manually.")
        }
    }

    private func irccCodeForApp(uri: String, title: String) -> String? {
        let u = uri.lowercased()
        let t = title.lowercased()
        if u.contains("netflix")  || t.contains("netflix")           { return IRCCCommand.netflix.rawValue }
        if u.contains("youtube")  || t.contains("youtube")           { return IRCCCommand.youtube.rawValue }
        if u.contains("amazon")   || t.contains("amazon")  ||
           u.contains("prime")    || t.contains("prime")             { return IRCCCommand.prime.rawValue }
        return nil
    }

    // MARK: - Inputs

    func getInputs() async throws -> [TVInput] {
        let result = try await restRequest(service: "avContent", method: "getCurrentExternalInputsStatus")
        guard let results = result["result"] as? [[[String: Any]]] else { return [] }
        return results.flatMap { $0 }.compactMap { item in
            guard let title = item["title"] as? String,
                  let uri = item["uri"] as? String else { return nil }
            let icon = item["icon"] as? String ?? "hdmi"
            let status = item["status"] as? String ?? "notConnected"
            return TVInput(title: title, uri: uri, icon: icon, status: status)
        }
    }

    func setInput(uri: String) async throws {
        _ = try await restRequest(service: "avContent", method: "setPlayContent",
                                   params: [["uri": uri]])
    }

    // MARK: - System Info

    func getSystemInfo() async throws -> [String: Any] {
        let result = try await restRequest(service: "system", method: "getSystemInformation")
        if let results = result["result"] as? [[String: Any]] {
            return results.first ?? [:]
        }
        return [:]
    }

    func getRemoteControllerInfo() async throws -> [(name: String, code: String)] {
        let result = try await restRequest(service: "system", method: "getRemoteControllerInfo")
        guard let results = result["result"] as? [[[String: Any]]] else { return [] }
        return results.flatMap { $0 }.compactMap { item in
            guard let name = item["name"] as? String,
                  let value = item["value"] as? String else { return nil }
            return (name: name, code: value)
        }
    }

    // MARK: - Playing Content

    func getPlayingContent() async throws -> [String: Any] {
        let result = try await restRequest(service: "avContent", method: "getPlayingContentInfo",
                                           params: [["output": ""]])
        if let results = result["result"] as? [[String: Any]] {
            return results.first ?? [:]
        }
        return [:]
    }

    // MARK: - Picture

    func setPictureMode(_ mode: String) async throws {
        _ = try await restRequest(service: "video", method: "setPictureQualitySettings",
                                   params: [["settings": [["target": "pictureMode", "value": mode]]]])
    }

    // MARK: - Wake on LAN

    func sendWakeOnLan(macAddress: String) {
        guard let packet = buildMagicPacket(mac: macAddress) else { return }
        _ = packet // NWConnection UDP send would go here
    }

    private func buildMagicPacket(mac: String) -> Data? {
        let cleaned = mac.replacingOccurrences(of: "[^0-9a-fA-F]", with: "", options: .regularExpression)
        guard cleaned.count == 12 else { return nil }
        var bytes: [UInt8] = Array(repeating: 0xFF, count: 6)
        let macBytes = stride(from: 0, to: 12, by: 2).compactMap { i -> UInt8? in
            let start = cleaned.index(cleaned.startIndex, offsetBy: i)
            let end = cleaned.index(start, offsetBy: 2)
            return UInt8(cleaned[start..<end], radix: 16)
        }
        guard macBytes.count == 6 else { return nil }
        for _ in 0..<16 { bytes += macBytes }
        return Data(bytes)
    }

    // MARK: - Helpers

    private func tvURL(path: String) throws -> URL {
        guard let url = URL(string: "http://\(tvIP)\(path)") else {
            throw TVError.networkError("Invalid URL: \(tvIP)\(path)")
        }
        return url
    }
}

