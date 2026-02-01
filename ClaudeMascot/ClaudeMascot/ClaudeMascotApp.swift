import SwiftUI

@main
struct ClaudeMascotApp: App {
    var body: some Scene {
        MenuBarExtra {
            Text("Claude Usage - Coming Soon")
                .padding()
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "circle.fill")
                .foregroundStyle(.gray)
        }
        .menuBarExtraStyle(.window)
    }
}
