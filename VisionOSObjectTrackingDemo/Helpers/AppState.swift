/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app's overall state.
*/

import ARKit
import RealityKitContent;

@MainActor
@Observable
class AppState {
    var isImmersiveSpaceOpened = false
    
    let referenceObjectLoader = ReferenceObjectLoader()

    func didLeaveImmersiveSpace() {
        // Stop the provider; the provider that just ran in the
        // immersive space is now in a paused state and isn't needed
        // anymore. When a person reenters the immersive space,
        // run a new provider.
        arkitSession.stop()
        isImmersiveSpaceOpened = false
    }

    // MARK: - ARKit state

    private var arkitSession = ARKitSession()
    
    private var objectTracking: ObjectTrackingProvider? = nil
    
    var objectTrackingStartedRunning = false
    
    var providersStoppedWithError = false
    
    var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    
    func startTracking() async -> ObjectTrackingProvider? {
        let referenceObjects = referenceObjectLoader.enabledReferenceObjects
        
        guard !referenceObjects.isEmpty else {
            fatalError("No reference objects to start tracking")
        }
        
        // Run a new provider every time when entering the immersive space.
        let objectTracking = ObjectTrackingProvider(referenceObjects: referenceObjects)
        do {
            try await arkitSession.run([objectTracking])
        } catch {
            print("Error: \(error)" )
            return nil
        }
        self.objectTracking = objectTracking
        return objectTracking
    }
    
    var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed
    }

    var allRequiredProvidersAreSupported: Bool {
        ObjectTrackingProvider.isSupported
    }

    var canEnterImmersiveSpace: Bool {
        allRequiredAuthorizationsAreGranted && allRequiredProvidersAreSupported
    }

    func requestWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.requestAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }
    
    func queryWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.queryAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }

    func monitorSessionEvents() async {
        for await event in arkitSession.events {
            switch event {
            case .dataProviderStateChanged(let providers, let newState, let error):
                switch newState {
                case .initialized:
                    break
                case .running:
                    guard objectTrackingStartedRunning == false, let objectTracking else { continue }
                    for provider in providers where provider === objectTracking {
                        objectTrackingStartedRunning = true
                        break
                    }
                case .paused:
                    break
                case .stopped:
                    guard objectTrackingStartedRunning == true, let objectTracking else { continue }
                    for provider in providers where provider === objectTracking {
                        objectTrackingStartedRunning = false
                        break
                    }
                    if let error {
                        print("An error occurred: \(error)")
                        providersStoppedWithError = true
                    }
                @unknown default:
                    break
                }
            case .authorizationChanged(let type, let status):
                print("Authorization type \(type) changed to \(status)")
                if type == .worldSensing {
                    worldSensingAuthorizationStatus = status
                }
            default:
                print("An unknown event occurred \(event)")
            }
        }
    }
}
