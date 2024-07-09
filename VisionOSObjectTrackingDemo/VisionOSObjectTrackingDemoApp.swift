import SwiftUI

@main
struct VisionOSObjectTrackingDemoApp: App {
    
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            HomeContentView(immersiveSpaceIdentifier: "ObjectTracking", appState: appState)
                .task {
                    if appState.allRequiredProvidersAreSupported {
                        await appState.referenceObjectLoader.loadBuiltInReferenceObjects()
                    }
                }
        }
        .defaultSize(CGSize(width: 250, height: 150))
        
        ImmersiveSpace(id: "ObjectTracking") {
            ObjectTrackingRealityView(appState: appState)
        }
    }
}
