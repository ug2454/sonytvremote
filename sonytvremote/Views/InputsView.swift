import SwiftUI

struct InputsView: View {
    @EnvironmentObject var vm: RemoteViewModel

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.10).ignoresSafeArea()

            if vm.isLoading {
                ProgressView("Loading inputs...")
                    .foregroundColor(.white)
            } else if vm.inputs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "display")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No inputs found")
                        .foregroundColor(.gray)
                    Button("Refresh") { Task { await vm.loadInputs() } }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                }
            } else {
                List(vm.inputs) { input in
                    InputRowView(input: input) {
                        Task { await vm.selectInput(input) }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Inputs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await vm.loadInputs() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { if vm.inputs.isEmpty { await vm.loadInputs() } }
    }
}

struct InputRowView: View {
    let input: TVInput
    let action: () -> Void

    var inputIcon: String {
        let title = input.title.lowercased()
        if title.contains("hdmi") { return "cable.connector.horizontal" }
        if title.contains("component") { return "bolt.horizontal" }
        if title.contains("composite") { return "dot.radiowaves.right" }
        if title.contains("pc") || title.contains("vga") { return "desktopcomputer" }
        if title.contains("tuner") || title.contains("antenna") { return "antenna.radiowaves.left.and.right" }
        return "tv"
    }

    var statusColor: Color {
        switch input.status {
        case "connected": return .green
        case "notConnected": return .gray
        default: return .yellow
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: inputIcon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(input.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text(input.status == "connected" ? "Connected" : "Not connected")
                        .font(.caption)
                        .foregroundColor(statusColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
