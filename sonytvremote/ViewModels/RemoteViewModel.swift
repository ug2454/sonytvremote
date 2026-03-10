import Foundation
import Combine
import OSLog

@MainActor
class RemoteViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app", category: "RemoteViewModel")
    @Published var isOn: Bool = false
    @Published var volume: Int = 0
    @Published var maxVolume: Int = 100
    @Published var isMuted: Bool = false
    @Published var apps: [TVApp] = []
    @Published var inputs: [TVInput] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var systemInfo: String = ""
    @Published var currentContent: String = ""

    private let service = SonyTVService.shared
    private var statusTimer: Timer?

    // MARK: - Configuration

    func loadSettings() async {
        logger.info("Loading settings from UserDefaults")
        let defaults = UserDefaults.standard
        let ip = defaults.string(forKey: "tv_ip") ?? ""
        let psk = defaults.string(forKey: "tv_psk") ?? ""
        logger.debug("Configuring service with IP: \(ip, privacy: .public)")
        await service.configure(ip: ip, psk: psk)
    }

    func startPolling() {
        logger.info("Starting status polling")
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshStatus()
            }
        }
        Task {
            await service.syncRemoteCodes() // fetch TV's actual IRCC codes once
            await refreshStatus()
        }
    }

    func stopPolling() {
        logger.info("Stopping status polling")
        statusTimer?.invalidate()
        statusTimer = nil
    }

    // MARK: - Status

    func refreshStatus() async {
        logger.debug("Refreshing TV status")
        do {
            isOn = try await service.getPowerStatus()
            logger.info("Power status: \(self.isOn ? "ON" : "OFF", privacy: .public)")
            if isOn {
                let volInfos = try await service.getVolumeInfo()
                if let speaker = volInfos.first(where: { $0.target == "speaker" }) ?? volInfos.first {
                    volume = speaker.volume
                    maxVolume = speaker.maxVolume
                    isMuted = speaker.mute
                    logger.debug("Volume: \(speaker.volume), Muted: \(speaker.mute)")
                }
            }
        } catch {
            logger.error("Failed to refresh status: \(error.localizedDescription, privacy: .public)")
            // Silent fail for polling
        }
    }

    // MARK: - Power

    func togglePower() async {
        logger.info("Toggle power button pressed")
        await sendCommand(.power)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await refreshStatus()
    }

    func powerOn() async {
        logger.info("Power ON requested")
        do {
            try await service.setPowerStatus(on: true)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await refreshStatus()
        } catch {
            logger.error("Power ON failed: \(error.localizedDescription, privacy: .public)")
            showError(error)
        }
    }

    func powerOff() async {
        logger.info("Power OFF requested")
        do {
            try await service.setPowerStatus(on: false)
            isOn = false
        } catch {
            logger.warning("Power OFF via API failed, trying IRCC command")
            await sendCommand(.powerOff)
        }
    }

    // MARK: - IRCC Commands

    func sendCommand(_ command: IRCCCommand) async {
        logger.info("Sending IRCC command: \(String(describing: command), privacy: .public)")
        do {
            try await service.sendIRCC(command)
            logger.debug("IRCC command sent successfully")
        } catch {
            logger.error("IRCC command failed: \(error.localizedDescription, privacy: .public)")
            showError(error)
        }
    }

    // MARK: - Volume

    func volumeUp() async { 
        logger.info("Volume UP pressed")
        await sendCommand(.volumeUp) 
    }
    
    func volumeDown() async { 
        logger.info("Volume DOWN pressed")
        await sendCommand(.volumeDown) 
    }

    func setVolume(_ value: Int) async {
        logger.info("Setting volume to: \(value, privacy: .public)")
        do {
            try await service.setVolume(volume: value)
            volume = value
        } catch {
            logger.error("Set volume failed: \(error.localizedDescription, privacy: .public)")
            showError(error)
        }
    }

    func toggleMute() async {
        logger.info("Toggle mute pressed (current: \(self.isMuted ? "muted" : "unmuted", privacy: .public))")
        do {
            isMuted.toggle()
            try await service.setMute(mute: isMuted)
        } catch {
            logger.error("Toggle mute failed: \(error.localizedDescription, privacy: .public)")
            isMuted.toggle()
            showError(error)
        }
    }

    // MARK: - Apps

    func loadApps() async {
        logger.info("Loading apps list")
        isLoading = true
        do {
            apps = try await service.getAppList()
            logger.info("Loaded \(self.apps.count, privacy: .public) apps")
        } catch {
            logger.error("Failed to load apps: \(error.localizedDescription, privacy: .public)")
            showError(error)
        }
        isLoading = false
    }

    func launchApp(_ app: TVApp) async {
        logger.info("Launching app: \(app.title, privacy: .public)")
        do {
            try await service.launchApp(uri: app.uri, title: app.title)
            logger.info("App launched successfully")
        } catch {
            logger.error("Failed to launch app: \(error.localizedDescription, privacy: .public)")
            showError(error)
        }
    }

    // MARK: - Inputs

    func loadInputs() async {
        logger.info("Loading inputs list")
        isLoading = true
        do {
            inputs = try await service.getInputs()
            logger.info("Loaded \(self.inputs.count, privacy: .public) inputs")
        } catch {
            logger.error("Failed to load inputs: \(error.localizedDescription, privacy: .public)")
            showError(error)
        }
        isLoading = false
    }

    func selectInput(_ input: TVInput) async {
        logger.info("Selecting input: \(input.title, privacy: .public)")
        do {
            try await service.setInput(uri: input.uri)
            logger.info("Input selected successfully")
        } catch {
            logger.error("Failed to select input: \(error.localizedDescription, privacy: .public)")
            showError(error)
        }
    }

    // MARK: - System Info

    func loadSystemInfo() async {
        logger.info("Loading system info")
        do {
            let info = try await service.getSystemInfo()
            let name = info["product"] as? String ?? "Sony TV"
            let model = info["model"] as? String ?? ""
            let serial = info["serial"] as? String ?? ""
            systemInfo = "\(name) \(model)\nSerial: \(serial)"
            logger.info("System info loaded: \(name, privacy: .public) \(model, privacy: .public)")
        } catch {
            logger.error("Failed to load system info: \(error.localizedDescription, privacy: .public)")
            systemInfo = "Could not load system info"
        }
    }

    // MARK: - Error

    private func showError(_ error: Error) {
        logger.error("Showing error to user: \(error.localizedDescription, privacy: .public)")
        errorMessage = error.localizedDescription
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { self.errorMessage = nil }
        }
    }
}
