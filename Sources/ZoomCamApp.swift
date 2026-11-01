import SwiftUI

@main
struct ZoomCamApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView().preferredColorScheme(.dark)
        }
    }
}
