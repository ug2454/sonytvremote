import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: RemoteViewModel
    @AppStorage("tv_ip") private var tvIP = ""
    @AppStorage("tv_psk") private var tvPSK = ""
    @AppStorage("tv_mac") private var tvMAC = ""

    @State private var testStatus: TestStatus = .idle
    @State private var systemInfoText = ""
    @State private var diagnosticLog = ""

    enum TestStatus {
        case idle, testing, success(String), failure(String)
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.10).ignoresSafeArea()

            Form {
                // Connection Section
                Section {
                    HStack {
                        Label("TV IP Address", systemImage: "network")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("192.168.1.x", text: $tvIP)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.cyan)
                            .autocorrectionDisabled()
                            .keyboardType(.decimalPad)
                            .onChange(of: tvIP) { _, _ in applySettings() }
                    }

                    HStack {
                        Label("Pre-Shared Key", systemImage: "key.fill")
                            .foregroundColor(.white)
                        Spacer()
                        SecureField("Optional PSK", text: $tvPSK)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.cyan)
                            .onChange(of: tvPSK) { _, _ in applySettings() }
                    }

                    HStack {
                        Label("MAC Address", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("For Wake-on-LAN", text: $tvMAC)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.cyan)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("TV Connection")
                } footer: {
                    Text("IP: Settings → Network → Network Status\nPSK: Settings → Network → Home Network Setup → IP Control → Pre-Shared Key\n\nIf your TV has no PSK option, leave it empty.")
                        .font(.caption)
                }

                // Diagnostics
                Section("Diagnostics") {
                    Button {
                        Task { await testRESTAPI() }
                    } label: {
                        HStack {
                            Label("Test REST API (System Info)", systemImage: "checkmark.shield")
                            Spacer()
                            testStatusView
                        }
                    }
                    .foregroundColor(.white)
                    .disabled(tvIP.isEmpty)

                    Button {
                        Task { await testIRCC() }
                    } label: {
                        HStack {
                            Label("Test IRCC (sends Home button)", systemImage: "house")
                            Spacer()
                            if case .testing = testStatus { ProgressView() }
                        }
                    }
                    .foregroundColor(.white)
                    .disabled(tvIP.isEmpty)
                }

                // Result
                if case .success(let info) = testStatus {
                    Section("Result") {
                        Text(info).font(.caption).foregroundColor(.green)
                    }
                }
                if case .failure(let err) = testStatus {
                    Section("Result") {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                }

                // System Info
                if !systemInfoText.isEmpty {
                    Section("Device Info") {
                        Text(systemInfoText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                }

                // Diagnostic Log
                if !diagnosticLog.isEmpty {
                    Section("Log") {
                        ScrollView {
                            Text(diagnosticLog)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 180)

                        Button("Clear Log") { diagnosticLog = "" }
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // Setup Instructions
                Section("Setup Guide") {
                    instructionRow(number: "1", text: "Enable IP control on your Sony TV:\nSettings → Network → Home Network Setup → Remote Device / Renderer → Enable")
                    instructionRow(number: "2", text: "Set the PSK (optional):\nSettings → Network → Home Network Setup → IP Control → Authentication → Pre-Shared Key\n\nIf this menu doesn't exist, leave PSK empty.")
                    instructionRow(number: "3", text: "Note your TV's IP address:\nSettings → Network → Network Status → View Network Status")
                    instructionRow(number: "4", text: "Enter IP above (auto-saves). Tap 'Test REST API', then 'Test IRCC' to verify both work.")
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundColor(.white)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { applySettings() }
    }

    // MARK: - Helpers

    func applySettings() {
        Task {
            await SonyTVService.shared.configure(
                ip: tvIP.trimmingCharacters(in: .whitespacesAndNewlines),
                psk: tvPSK.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    func testRESTAPI() async {
        testStatus = .testing
        applySettings()
        log("Testing REST at http://\(tvIP)/sony/system")
        log("PSK: \(tvPSK.isEmpty ? "(none)" : "set (\(tvPSK.count) chars)")")
        do {
            let info = try await SonyTVService.shared.getSystemInfo()
            let product = info["product"] as? String ?? "Sony TV"
            let model   = info["model"] as? String ?? ""
            let serial  = info["serial"] as? String ?? "N/A"
            systemInfoText = "Product: \(product)\nModel: \(model)\nSerial: \(serial)"
            testStatus = .success("✅ Connected: \(product) \(model)")
            log("✅ REST OK: \(product) \(model)")
        } catch {
            testStatus = .failure(error.localizedDescription)
            log("❌ REST failed: \(error.localizedDescription)")
        }
    }

    func testIRCC() async {
        testStatus = .testing
        applySettings()
        log("Testing IRCC (will try /sony/IRCC → /sony/ircc → /IRCC)")
        log("Sending Home button...")
        do {
            try await SonyTVService.shared.sendIRCC(.home)
            testStatus = .success("✅ IRCC OK — TV should have reacted!")
            log("✅ IRCC success — working path cached for all buttons")
        } catch {
            testStatus = .failure(error.localizedDescription)
            log("❌ All IRCC paths failed: \(error.localizedDescription)")
            log("💡 Make sure IP control is enabled: TV Settings → Network → Home Network Setup → Remote Device → Enable")
        }
    }

    func log(_ msg: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        diagnosticLog += "[\(time)] \(msg)\n"
    }

    var testStatusView: some View {
        Group {
            switch testStatus {
            case .idle:    Image(systemName: "chevron.right").foregroundColor(.gray)
            case .testing: ProgressView()
            case .success: Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            case .failure: Image(systemName: "xmark.circle.fill").foregroundColor(.red)
            }
        }
    }

    func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.blue))
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(Color.white.opacity(0.05))
    }
}
