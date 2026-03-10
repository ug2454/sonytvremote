import SwiftUI

struct RemoteView: View {
    @EnvironmentObject var vm: RemoteViewModel
    @State private var showNumberPad = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.12), Color(red: 0.04, green: 0.04, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    headerSection
                    powerSection
                    dpadSection
                    volumeChannelSection
                    mediaSection
                    colorButtonSection
                    streamingSection

                    Button(showNumberPad ? "Hide Number Pad" : "Number Pad") {
                        withAnimation { showNumberPad.toggle() }
                    }
                    .font(.footnote)
                    .foregroundColor(.gray)

                    if showNumberPad {
                        numberPadSection
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            if let error = vm.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85).cornerRadius(10))
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Header

    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sony TV Remote")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.isOn ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(vm.isOn ? "Active" : "Standby")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Button { Task { await vm.refreshStatus() } } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Power Row

    var powerSection: some View {
        HStack(spacing: 12) {
            Button {
                Task { await vm.togglePower() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.system(size: 16, weight: .semibold))
                    Text(vm.isOn ? "Turn Off" : "Turn On")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(vm.isOn ? Color.red.opacity(0.7) : Color.green.opacity(0.7))
                .cornerRadius(14)
            }
            .buttonStyle(ScaleButtonStyle())

            RemoteButton(icon: "house.fill",             label: "Home",  color: .white, size: 48) { await vm.sendCommand(.home) }
            RemoteButton(icon: "arrow.uturn.backward",   label: "Back",  color: .white, size: 48) { await vm.sendCommand(.back) }
            RemoteButton(icon: "info.circle",            label: "Info",  color: .white, size: 48) { await vm.sendCommand(.info) }
        }
    }

    // MARK: - D-Pad

    var dpadSection: some View {
        VStack(spacing: 12) {
            HStack {
                RemoteButton(icon: "line.3.horizontal",                              label: "Menu",  color: .white, size: 48) { await vm.sendCommand(.options) }
                Spacer()
                RemoteButton(icon: "rectangle.and.arrow.up.right.and.arrow.down.left", label: "Exit", color: .white, size: 48) { await vm.sendCommand(.exit) }
            }

            DPadView(
                onUp:    { await vm.sendCommand(.up) },
                onDown:  { await vm.sendCommand(.down) },
                onLeft:  { await vm.sendCommand(.left) },
                onRight: { await vm.sendCommand(.right) },
                onOK:    { await vm.sendCommand(.confirm) }
            )
        }
    }

    // MARK: - Volume / Channel

    var volumeChannelSection: some View {
        HStack(spacing: 0) {
            // Volume
            VStack(spacing: 6) {
                Text("VOL").font(.caption2.bold()).foregroundColor(.gray)
                RemoteButton(icon: "speaker.plus.fill",  label: "Vol+", color: .white,                       size: 50) { await vm.volumeUp() }
                RemoteButton(icon: "speaker.slash.fill", label: "Mute", color: vm.isMuted ? .yellow : .gray, size: 50) { await vm.toggleMute() }
                RemoteButton(icon: "speaker.minus.fill", label: "Vol-", color: .white,                       size: 50) { await vm.volumeDown() }
            }

            Spacer()

            // Middle
            VStack(spacing: 12) {
                RemoteButton(icon: "captions.bubble", label: "Sub",    color: .white, size: 50) { await vm.sendCommand(.subtitle) }
                RemoteButton(icon: "waveform",        label: "Audio",  color: .white, size: 50) { await vm.sendCommand(.audio) }
                RemoteButton(icon: "aspectratio",     label: "Aspect", color: .white, size: 50) { await vm.sendCommand(.aspect) }
            }

            Spacer()

            // Channel
            VStack(spacing: 6) {
                Text("CH").font(.caption2.bold()).foregroundColor(.gray)
                RemoteButton(icon: "chevron.up",   label: "Ch+",   color: .white, size: 50) { await vm.sendCommand(.channelUp) }
                RemoteButton(icon: "tv",           label: "Input", color: .white, size: 50) { await vm.sendCommand(.input) }
                RemoteButton(icon: "chevron.down", label: "Ch-",   color: .white, size: 50) { await vm.sendCommand(.channelDown) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Media — split into 2 rows so nothing overflows

    var mediaSection: some View {
        VStack(spacing: 10) {
            Text("Playback")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Row 1: main transport
            HStack(spacing: 0) {
                Spacer()
                RemoteButton(icon: "backward.fill",  label: "RW",    color: .white, size: 50) { await vm.sendCommand(.rewind) }
                Spacer()
                RemoteButton(icon: "play.fill",      label: "Play",  color: .cyan,  size: 56) { await vm.sendCommand(.play) }
                Spacer()
                RemoteButton(icon: "pause.fill",     label: "Pause", color: .white, size: 50) { await vm.sendCommand(.pause) }
                Spacer()
                RemoteButton(icon: "forward.fill",   label: "FF",    color: .white, size: 50) { await vm.sendCommand(.fastForward) }
                Spacer()
            }

            // Row 2: secondary controls
            HStack(spacing: 0) {
                Spacer()
                RemoteButton(icon: "backward.end.fill", label: "Prev", color: .white,            size: 50) { await vm.sendCommand(.prev) }
                Spacer()
                RemoteButton(icon: "stop.fill",         label: "Stop", color: .red.opacity(0.8), size: 50) { await vm.sendCommand(.stop) }
                Spacer()
                RemoteButton(icon: "forward.end.fill",  label: "Next", color: .white,            size: 50) { await vm.sendCommand(.next) }
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Color Buttons

    var colorButtonSection: some View {
        HStack(spacing: 0) {
            Spacer()
            colorBtn("Red",    color: .red,    cmd: .red)
            Spacer()
            colorBtn("Green",  color: .green,  cmd: .green)
            Spacer()
            colorBtn("Yellow", color: .yellow, cmd: .yellow)
            Spacer()
            colorBtn("Blue",   color: .blue,   cmd: .blue)
            Spacer()
        }
    }

    func colorBtn(_ label: String, color: Color, cmd: IRCCCommand) -> some View {
        Button { Task { await vm.sendCommand(cmd) } } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.8))
                .frame(width: 60, height: 30)
                .overlay(Text(label).font(.system(size: 10, weight: .bold)).foregroundColor(.white))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Streaming

    var streamingSection: some View {
        VStack(spacing: 10) {
            Text("Streaming")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                streamBtn("Netflix", color: Color(red: 0.9, green: 0.1, blue: 0.1), cmd: .netflix)
                streamBtn("YouTube", color: Color(red: 0.85, green: 0.1, blue: 0.1), cmd: .youtube)
                streamBtn("Prime",   color: Color(red: 0.0,  green: 0.6, blue: 0.8), cmd: .prime)
            }
        }
    }

    func streamBtn(_ name: String, color: Color, cmd: IRCCCommand) -> some View {
        Button { Task { await vm.sendCommand(cmd) } } label: {
            Text(name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(color.cornerRadius(10))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Number Pad

    var numberPadSection: some View {
        VStack(spacing: 10) {
            let numbers: [(String, IRCCCommand)] = [
                ("1", .num1), ("2", .num2), ("3", .num3),
                ("4", .num4), ("5", .num5), ("6", .num6),
                ("7", .num7), ("8", .num8), ("9", .num9),
                ("",  .num0), ("0", .num0), ("",  .num0)
            ]

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(0..<12, id: \.self) { i in
                    if i == 0 || i == 11 {
                        Color.clear.frame(height: 50)
                    } else {
                        let (label, cmd) = numbers[i]
                        TextRemoteButton(text: label, size: 50) {
                            await vm.sendCommand(cmd)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

#Preview {
    RemoteView()
        .environmentObject(RemoteViewModel())
}
