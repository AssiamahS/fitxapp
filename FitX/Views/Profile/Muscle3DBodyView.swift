import SceneKit
import SceneKit.ModelIO
import ModelIO
import SwiftUI

/// Interactive 3D body from the OpenGym3D pipeline — orbit/zoom like a game
/// character, muscles tinted by training heat. Material names in body.mtl
/// ("muscle_<group>") map straight onto MuscleGroup raw values.
struct Muscle3DBodyView: View {
    let intensity: (MuscleGroup) -> Double

    @State private var scene: SCNScene?

    /// The parent decides between 3D and the 2D fallback with this.
    static var isAvailable: Bool {
        Bundle.main.url(forResource: "body", withExtension: "obj") != nil
    }

    var body: some View {
        Group {
            if let scene {
                SceneView(scene: scene,
                          options: [.allowsCameraControl, .autoenablesDefaultLighting])
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ProgressView()
                    .frame(height: 340)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear { if scene == nil { scene = Self.makeScene(intensity: intensity) } }
        .onChange(of: heatFingerprint) {
            scene = Self.makeScene(intensity: intensity)
        }
    }

    /// Re-tint when the underlying heat values change.
    private var heatFingerprint: String {
        MuscleGroup.allCases.map { String(Int(intensity($0) * 100)) }.joined(separator: "-")
    }

    static func makeScene(intensity: (MuscleGroup) -> Double) -> SCNScene? {
        guard let url = Bundle.main.url(forResource: "body", withExtension: "obj") else { return nil }
        let asset = MDLAsset(url: url)
        asset.loadTextures()
        let scene = SCNScene(mdlAsset: asset)

        scene.background.contents = UIColor.clear

        var bodyNode: SCNNode?
        scene.rootNode.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            bodyNode = node
            for material in geometry.materials {
                guard let name = material.name else { continue }
                if name.hasPrefix("muscle_"),
                   let group = MuscleGroup(rawValue: String(name.dropFirst("muscle_".count))) {
                    let t = intensity(group)
                    material.diffuse.contents = UIColor(heat(t))
                    material.emission.contents = UIColor(heat(t)).withAlphaComponent(t > 0 ? 0.25 : 0)
                } else {
                    material.diffuse.contents = UIColor(white: 0.86, alpha: 1)
                }
                material.lightingModel = .physicallyBased
                material.roughness.contents = 0.6
            }
        }

        if let bodyNode {
            let (center, radius) = boundingSphere(of: bodyNode)
            let camera = SCNCamera()
            camera.fieldOfView = 40
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(center.x, center.y, center.z + radius * 2.6)
            cameraNode.look(at: center)
            scene.rootNode.addChildNode(cameraNode)
        }
        return scene
    }

    private static func boundingSphere(of node: SCNNode) -> (SCNVector3, Float) {
        let (minV, maxV) = node.boundingBox
        let center = SCNVector3((minV.x + maxV.x) / 2, (minV.y + maxV.y) / 2, (minV.z + maxV.z) / 2)
        let radius = max(maxV.x - minV.x, maxV.y - minV.y, maxV.z - minV.z) / 2
        return (center, radius)
    }

    private static func heat(_ t: Double) -> Color {
        guard t > 0 else { return Color(white: 0.86) }
        // neutral -> brand coral ramp
        let clamped = min(t, 1)
        return Color(red: 0.86 + 0.05 * clamped,
                     green: 0.86 - 0.55 * clamped,
                     blue: 0.86 - 0.58 * clamped)
    }
}
