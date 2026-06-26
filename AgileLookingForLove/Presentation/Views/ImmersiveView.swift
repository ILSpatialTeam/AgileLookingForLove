//
//  ImmersiveView.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 22/06/26.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ILSSpatialDraw
import ILSHandTracking
import ARKit

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @State private var floorEntity: Entity? = nil
    private let trackingSession = SpatialTrackingSession()

    var body: some View {
        RealityView { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            //Systems Register
            InstructionSystem.registerSystem()
            ThreadSystem.registerSystem()
            MovementSystem.registerSystem()
            ShapeComponent.registerComponent()
            EntityStateComponent.registerComponent()
            ThreadAnchorComponent.registerComponent()
            RedThreadValidationSystem.registerSystem()
            LoveBeamComponent.registerComponent()
            HeadAnchorComponent.registerComponent()
            LoveProjectileComponent.registerComponent()
            EnvironmentComponent.registerComponent()
            
            //ILDraw Package
            ILFeatureHandTrackingSetup.registerSystems()
                        
                        IsDrawingComponent.registerComponent()
                        DrawingComponent.registerComponent()
                        CanvasComponent.registerComponent()
                        SharePlayReceiverComponent.registerComponent()
                        
                        CustomPinchGestureSystem.registerSystem()
                        DrawingSystem.registerSystem()
            
            //Canvas Entity
            let canvas = Entity()
            canvas.name = "RedThreadCanvas"
            canvas.components.set(CanvasComponent())
            content.add(canvas)
            
            //DrawController
            let drawController = Entity()
            drawController.name = "DrawController"
            
            //Red Strting
            var drawComp = DrawingComponent()
            drawComp.currentColor = SIMD4<Float>(0.9, 0.1, 0.1, 1.0)
            drawComp.sphereRadius = 0.004
            drawController.components.set(drawComp)
            
            drawController.components.set(IsDrawingComponent())
            drawController.components.set(ILHandAnchorComponent())
            content.add(drawController)
            
            let hands = HandEntitySpawner.spawnHands()
            for hand in hands {content.add(hand)}
            
            // Add a fallback static floor collider so entities don't fall into the abyss before spatial tracking loads
            let fallbackFloor = Entity()
            fallbackFloor.name = "FallbackFloor"
            let floorShape = ShapeResource.generateBox(width: 50, height: 0.1, depth: 50)
            fallbackFloor.components.set(CollisionComponent(shapes: [floorShape], isStatic: true))
            fallbackFloor.components.set(PhysicsBodyComponent(mode: .static))
            fallbackFloor.position = SIMD3<Float>(0, -0.05, 0) // top surface is at y = 0
            content.add(fallbackFloor)
            
            // Persistent root entity for all async entity additions.
            // Must be created synchronously so rootEntity is available to the view model.
            let sceneRoot = Entity()
            sceneRoot.name = "SceneRoot"
            content.add(sceneRoot)
            
            appModel.viewModel.setContent(content, root: sceneRoot)
            appModel.viewModel.setupPlacementIndicator()
            
            // Load templates and spawn initial entities once templates are ready
            Task {
                await appModel.viewModel.loadTemplates()
                
                // OAD LOVE SHOT PARTICLE
                do {
                    let loveShot = try await Entity(named: "Love Shot", in: realityKitContentBundle)
                    loveShot.name = "LoveBeam"
                    loveShot.components.set(LoveBeamComponent())
                    
                    if let emitter = loveShot.findEntity(named: "ParticleEmitter") {
                           if var vfx = emitter.components[ParticleEmitterComponent.self] {
                               vfx.isEmitting = false // Gunakan isEmitting
                               emitter.components.set(vfx)
                           }
                       }
                    
                    sceneRoot.addChild(loveShot)
                    print("[ImmersiveView] Love Shot particle system loaded!")
                } catch {
                    print("[ImmersiveView] Failed to load Love Shot: \(error)")
                }
            }
            
            // Start plane detection to find and spawn floor
            Task {
                let configuration = SpatialTrackingSession.Configuration(
                    tracking: [],
                    sceneUnderstanding: [.collision, .physics]
                )
                let _ = await trackingSession.run(configuration)
                print("Spatial Tracking Session (Room Mesh) berjalan sukses!")
            }
            
            // UI
            let headAnchor = AnchorEntity(.head)
            headAnchor.components.set(HeadAnchorComponent())
            if let hudEntity = attachments.entity(for: "HUDOverlay") {
                hudEntity.position = SIMD3<Float>(0.10, -0.15, -0.7)
                headAnchor.addChild(hudEntity)
            }
            content.add(headAnchor)
            
        } update: { (content: inout RealityViewContent, attachments: RealityViewAttachments) in
            // Update block: only update content reference; root is already persistent in the scene.
            if let root = appModel.viewModel.rootEntity {
                appModel.viewModel.setContent(content, root: root)
            }
        } attachments: {
            Attachment(id: "HUDOverlay") {
                HUDOverlayView(
                    instruction: appModel.viewModel.currentInstruction,
                    score: appModel.viewModel.score,
                    timeLeft: appModel.viewModel.instructionTimer,
                    connectionMessage: appModel.viewModel.lastConnectionMessage
                )
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let entity = value.entity
                    let stateComp = entity.components[EntityStateComponent.self]
                    
                    if stateComp?.state == .idle || stateComp?.state == .walking {
                        appModel.viewModel.handleShoot(entity: entity)
                    }
                }
        )
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    if value.entity.name == "PlacementIndicator" {
                        let parent = value.entity.parent ?? value.entity
                        value.entity.position = value.convert(value.location3D, from: .local, to: parent)
                    }
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: .spawnEntityRequested)) { _ in
            let groundY = appModel.viewModel.environmentEntity?.position(relativeTo: nil).y ?? 0
            appModel.viewModel.spawnEntityAt(groundY: groundY)
        }
        .onReceive(NotificationCenter.default.publisher(for: .threadStrokeConnected)) { notif in
            guard let a = notif.userInfo?["entityA"] as? Entity,
                  let b = notif.userInfo?["entityB"] as? Entity else { return }
            let stroke = notif.userInfo?["strokeEntity"] as? Entity
            appModel.viewModel.handleThreadStroke(entityA: a, entityB: b, strokeEntity: stroke)
        }
        .onReceive(NotificationCenter.default.publisher(for: .stunEntityRequested)) { notif in
            if let entity = notif.userInfo?["entity"] as? Entity {
                appModel.viewModel.handleShoot(entity: entity)
            }
        }
        .task {
            let arSession = ARKitSession()
            _ = await arSession.requestAuthorization(for: [.handTracking, .worldSensing])

            // Start head tracker for querying head pose/anchor
            await HeadTracker.shared.start()

            try? await HandTrackingService.shared.start()
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
