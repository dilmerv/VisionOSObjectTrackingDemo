/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The class that loads all available reference objects.
*/

import ARKit
import RealityKit

@MainActor
@Observable
final class ReferenceObjectLoader {
    
    private(set) var referenceObjects = [ReferenceObject]()
    var enabledReferenceObjects = [ReferenceObject]()
    var enabledReferenceObjectsCount: Int { enabledReferenceObjects.count }
    private(set) var usdzsPerReferenceObjectID = [UUID: Entity]()
    
    private var didStartLoading = false
    
    private var fileCount: Int = 0
    private var filesLoaded: Int = 0
    private(set) var progress: Float = 1.0
    
    var didFinishLoading: Bool { progress >= 1.0 }
    
    private func finishedOneFile() {
        filesLoaded += 1
        updateProgress()
    }
    
    private func updateProgress() {
        if fileCount == 0 {
            progress = 1.0
        } else if filesLoaded == fileCount {
            progress = 1.0
        } else {
            progress = Float(filesLoaded) / Float(fileCount)
        }
    }

    func loadBuiltInReferenceObjects() async {
        // Only allow one loading operation at any given time.
        guard !didStartLoading else { return }
        didStartLoading.toggle()
        
        print("Looking for reference objects in the main bundle ...")

        // Get a list of all reference object files in the app's main bundle and attempt to load each.
        var referenceObjectFiles: [String] = []
        if let resourcesPath = Bundle.main.resourcePath {
            try? referenceObjectFiles = FileManager.default.contentsOfDirectory(atPath: resourcesPath).filter { $0.hasSuffix(".referenceobject") }
        }
        
        fileCount = referenceObjectFiles.count
        updateProgress()
        
        await withTaskGroup(of: Void.self) { group in
            for file in referenceObjectFiles {
                let objectURL = Bundle.main.bundleURL.appending(path: file)
                group.addTask {
                    await self.loadReferenceObject(objectURL)
                    await self.finishedOneFile()
                }
            }
        }
    }
    
    private func loadReferenceObject(_ url: URL) async {
        var referenceObject: ReferenceObject
        do {
            print("Loading reference object from \(url)")
            // Load the file as a `ReferenceObject` - this can take a while for larger objects.
            try await referenceObject = ReferenceObject(from: url)
        } catch {
            fatalError("Failed to load reference object with error \(error)")
        }
        
        referenceObjects.append(referenceObject)
        
        // Add the new object to the list of objects to track.
        enabledReferenceObjects.append(referenceObject)

        if let usdzPath = referenceObject.usdzFile {
            var entity: Entity? = nil

            do {
                // Load the contents of the USDZ file as an `Entity` that you attach to the anchor.
                try await entity = Entity(contentsOf: usdzPath)
            } catch {
                print("Failed to load model \(usdzPath.absoluteString)")
            }

            usdzsPerReferenceObjectID[referenceObject.id] = entity
        }
    }
    
    func addReferenceObject(_ url: URL) async {
        fileCount += 1
        await self.loadReferenceObject(url)
        self.finishedOneFile()
    }
    
    func removeObject(_ referenceObject: ReferenceObject) {
        referenceObjects.removeAll { $0.id == referenceObject.id }
        enabledReferenceObjects.removeAll { $0.id == referenceObject.id }
        fileCount = referenceObjects.count
    }
    
    func removeObjects(atOffsets offsets: IndexSet) {
        referenceObjects.remove(atOffsets: offsets)
        // Remove deleted objects from objects to track.
        enabledReferenceObjects.removeAll(where: { object in
            !referenceObjects.contains(where: { $0.id == object.id })
        })
        fileCount = referenceObjects.count
    }
}
