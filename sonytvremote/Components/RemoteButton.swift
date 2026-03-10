import SwiftUI

struct RemoteButton: View {
    let icon: String
    let label: String?
    let color: Color
    let size: CGFloat
    let action: () async -> Void

    @State private var isPressed = false

    init(icon: String, label: String? = nil, color: Color = .white, size: CGFloat = 52, action: @escaping () async -> Void) {
        self.icon = icon
        self.label = label
        self.color = color
        self.size = size
        self.action = action
    }

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.38, weight: .medium))
                if let label {
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                }
            }
            .foregroundColor(color)
            .frame(width: size, height: label != nil ? size + 8 : size)
            .background(
                Circle()
                    .fill(Color.white.opacity(isPressed ? 0.25 : 0.1))
                    .frame(width: size, height: size)
            )
        }
        .buttonStyle(PressedButtonStyle(isPressed: $isPressed))
    }
}

struct TextRemoteButton: View {
    let text: String
    let color: Color
    let size: CGFloat
    let action: () async -> Void
    @State private var isPressed = false

    init(text: String, color: Color = .white, size: CGFloat = 52, action: @escaping () async -> Void) {
        self.text = text
        self.color = color
        self.size = size
        self.action = action
    }

    var body: some View {
        Button { Task { await action() } } label: {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isPressed ? 0.25 : 0.1))
                )
        }
        .buttonStyle(PressedButtonStyle(isPressed: $isPressed))
    }
}

struct PressedButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
