import SwiftUI

struct DPadView: View {
    let onUp: () async -> Void
    let onDown: () async -> Void
    let onLeft: () async -> Void
    let onRight: () async -> Void
    let onOK: () async -> Void

    private let dpadSize: CGFloat = 200
    private let centerSize: CGFloat = 64
    private let arrowSize: CGFloat = 52

    var body: some View {
        ZStack {
            // D-Pad background ring
            Circle()
                .fill(Color(white: 0.18))
                .frame(width: dpadSize, height: dpadSize)

            // OK center
            Button { Task { await onOK() } } label: {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.3))
                        .frame(width: centerSize, height: centerSize)
                    Text("OK")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            // Up
            VStack {
                arrowButton(icon: "chevron.up", action: onUp)
                Spacer()
            }
            .frame(height: dpadSize)

            // Down
            VStack {
                Spacer()
                arrowButton(icon: "chevron.down", action: onDown)
            }
            .frame(height: dpadSize)

            // Left
            HStack {
                arrowButton(icon: "chevron.left", action: onLeft)
                Spacer()
            }
            .frame(width: dpadSize)

            // Right
            HStack {
                Spacer()
                arrowButton(icon: "chevron.right", action: onRight)
            }
            .frame(width: dpadSize)
        }
        .frame(width: dpadSize, height: dpadSize)
    }

    private func arrowButton(icon: String, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: arrowSize, height: arrowSize)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
