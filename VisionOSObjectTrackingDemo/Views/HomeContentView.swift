//
//  ContentView.swift
//  VisionOSObjectTrackingDemo
//
//  Created by Dilmer Valecillos on 7/6/24.
//

import SwiftUI
import RealityKit

struct HomeContentView: View {
    let immersiveSpaceIdentifier: String
    @Bindable var appState: AppState
   
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    var body: some View {
        Group {
            Text("visionOS Object Tracking Demo...")
                .font(.system(size: 15, weight:. bold))
                .padding(.horizontal, 30)
        }
        VStack {
            if appState.canEnterImmersiveSpace {
                VStack {
                    if !appState.isImmersiveSpaceOpened {
                        Button("Start Tracking \(appState.referenceObjectLoader.enabledReferenceObjectsCount) Object(s)") {
                            Task {
                                switch await openImmersiveSpace(id: immersiveSpaceIdentifier) {
                                case .opened:
                                    break
                                case .error:
                                    print("An error occurred when trying to open the immersive space \(immersiveSpaceIdentifier)")
                                case .userCancelled:
                                    print("The user declined opening immersive space \(immersiveSpaceIdentifier)")
                                @unknown default:
                                    break
                                }
                            }
                        }
                        .disabled(!appState.canEnterImmersiveSpace || appState.referenceObjectLoader.enabledReferenceObjectsCount == 0)
                    } else {
                        Button("Stop Tracking") {
                            Task {
                                await dismissImmersiveSpace()
                                appState.didLeaveImmersiveSpace()
                            }
                        }
                        
                        if !appState.objectTrackingStartedRunning {
                            HStack {
                                ProgressView()
                                Text("Please wait until all reference objects have been loaded")
                            }
                        }
                    }
                    
                    Text(appState.isImmersiveSpaceOpened ?
                         "This leaves the immersive space." :
                         "This enters an immersive space, hiding all other apps."
                    )
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .onChange(of: scenePhase, initial: true) {
            print("Scene phase: \(scenePhase)")
            if scenePhase == .active {
                Task {
                    // When returning from the background, check if the authorization has changed.
                    await appState.queryWorldSensingAuthorization()
                }
            } else {
                // Make sure to leave the immersive space if this view is no longer active
                // - such as when a person closes this view - otherwise they may be stuck
                // in the immersive space without the controls this view provides.
                if appState.isImmersiveSpaceOpened {
                    Task {
                        await dismissImmersiveSpace()
                        appState.didLeaveImmersiveSpace()
                    }
                }
            }
        }
        .onChange(of: appState.providersStoppedWithError, { _, providersStoppedWithError in
            // Immediately close the immersive space if an error occurs.
            if providersStoppedWithError {
                if appState.isImmersiveSpaceOpened {
                    Task {
                        await dismissImmersiveSpace()
                        appState.didLeaveImmersiveSpace()
                    }
                }
                
                appState.providersStoppedWithError = false
            }
        })
        .task {
            // Ask for authorization before a person attempts to open the immersive space.
            // This gives the app opportunity to respond gracefully if authorization isn't granted.
            if appState.allRequiredProvidersAreSupported {
                await appState.requestWorldSensingAuthorization()
            }
        }
        .task {
            // Start monitoring for changes in authorization, in case a person brings the
            // Settings app to the foreground and changes authorizations there.
            await appState.monitorSessionEvents()
        }
    }
}

#Preview(windowStyle: .automatic) {
    HomeContentView(immersiveSpaceIdentifier: "ObjectTracking", appState: AppState())
}
