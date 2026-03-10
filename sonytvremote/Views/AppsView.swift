import SwiftUI

struct AppsView: View {
    @EnvironmentObject var vm: RemoteViewModel

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.10).ignoresSafeArea()

            if vm.isLoading {
                ProgressView("Loading apps...")
                    .foregroundColor(.white)
            } else if vm.apps.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No apps found")
                        .foregroundColor(.gray)
                    Button("Refresh") { Task { await vm.loadApps() } }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.apps) { app in
                            AppTileView(app: app) {
                                Task { await vm.launchApp(app) }
                            }
                        }
                    }
                    .padding(16)
                }
            }

            // Error toast
            if let error = vm.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85).cornerRadius(10))
                        .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await vm.loadApps() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { if vm.apps.isEmpty { await vm.loadApps() } }
    }
}

struct AppTileView: View {
    let app: TVApp
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 8) {
            if let iconURL = app.iconURL, let url = URL(string: iconURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    appIconPlaceholder
                }
                .frame(width: 56, height: 56)
                .cornerRadius(12)
            } else {
                appIconPlaceholder
            }

            Text(app.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 100, height: 110)
        .background(Color.white.opacity(isPressed ? 0.2 : 0.08))
        .cornerRadius(14)
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            // Instant tap — no ScrollView delay
            withAnimation { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { isPressed = false }
            }
            action()
        }
    }

    var appIconPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.3))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 22))
            )
    }
}
