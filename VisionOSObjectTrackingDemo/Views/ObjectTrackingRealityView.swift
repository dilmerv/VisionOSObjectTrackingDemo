/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The view shown inside the immersive space.
*/

import RealityKit
import ARKit
import SwiftUI

@MainActor
struct ObjectTrackingRealityView: View {
    var appState: AppState
    var root = Entity()
    
    @State private var objectVisualizations: [UUID: ObjectAnchorVisualization] = [:]

    var body: some View {
        RealityView { content in
            content.add(root)
            
            Task {
                let objectTracking = await appState.startTracking()
                guard let objectTracking else {
                    return
                }
                
                for await anchorUpdate in objectTracking.anchorUpdates {
                    let anchor = anchorUpdate.anchor
                    let id = anchor.id
                    
                    switch anchorUpdate.event {
                    case .added:
                        let model = appState.referenceObjectLoader.usdzsPerReferenceObjectID[anchor.referenceObject.id]
                        let visualization = ObjectAnchorVisualization(for: anchor, withModel: model)
                        self.objectVisualizations[id] = visualization
                        root.addChild(visualization.entity)
                    case .updated:
                        self.objectVisualizations[id]?.update(with: anchor)
                    case .removed:
                        self.objectVisualizations[id]?.entity.removeFromParent()
                        self.objectVisualizations.removeValue(forKey: id)
                    }
                }
            }
        }
        .onAppear() {
            appState.isImmersiveSpaceOpened = true
        }
        .onDisappear() {
            for (_, visualization) in objectVisualizations {
                root.removeChild(visualization.entity)
            }
            objectVisualizations.removeAll()
            appState.didLeaveImmersiveSpace()
        }
    }
}
