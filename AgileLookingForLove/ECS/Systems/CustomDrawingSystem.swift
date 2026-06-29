//
//  CustomDrawingSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 26/06/26.
//

import Foundation
import RealityKit
import ILSSpatialDraw
import ILSFoundation
import UIKit

class CustomDrawingResourceCache {
    private var materials: [SIMD4<Float>: UnlitMaterial] = [:]

    func material(for color: SIMD4<Float>) -> UnlitMaterial {
        if let existing = materials[color] { return existing }
        var newMaterial = UnlitMaterial()
        newMaterial.color = .init(tint: .init(
            red:   CGFloat(color.x),
            green: CGFloat(color.y),
            blue:  CGFloat(color.z),
            alpha: CGFloat(color.w)
        ))
        materials[color] = newMaterial
        return newMaterial
    }
    
    func clear() {
        materials.removeAll()
    }
}

public class CustomDrawingSystem: System {
    static let drawQuery     = EntityQuery(where: .has(DrawingComponent.self) && .has(IsDrawingComponent.self))
    static let canvasQuery   = EntityQuery(where: .has(CanvasComponent.self))
    static let receiverQuery = EntityQuery(where: .has(SharePlayReceiverComponent.self))

    // Min distance between spawned points
    static let minSpacing: Float = 0.003
    
    private let resourceCache = CustomDrawingResourceCache()
    
    // Remote stroke tracking
    private var remoteStrokeEntities: [UUID: Entity] = [:]
    private var remoteStrokePoints: [UUID: [SIMD3<Float>]] = [:]

    required public init(scene: RealityKit.Scene) {}

    public func update(context: SceneUpdateContext) {
        let canvasEntities   = context.entities(matching: Self.canvasQuery,   updatingSystemWhen: .rendering)
        let receiverEntities = context.entities(matching: Self.receiverQuery, updatingSystemWhen: .rendering)
        let drawEntities     = context.entities(matching: Self.drawQuery,     updatingSystemWhen: .rendering)

        guard let canvas = canvasEntities.first(where: { _ in true }) else {
            return
        }

        // Check for a local clear request written into CanvasComponent
        if var canvasComp = canvas.components[CanvasComponent.self], canvasComp.clearRequested {
            clearCanvas(canvas)
            canvasComp.clearRequested = false
            canvas.components.set(canvasComp)
        }

        // Process incoming SharePlay strokes
        if let receiver = receiverEntities.first(where: { _ in true }),
           let manager  = receiver.components[SharePlayReceiverComponent.self]?.manager {
            let remoteStrokes = manager.consumeRemoteStrokes()
            for stroke in remoteStrokes {
                switch stroke.action {
                case .addPoint:
                    let id = stroke.strokeID
                    if remoteStrokePoints[id] == nil {
                        remoteStrokePoints[id] = []
                    }
                    remoteStrokePoints[id]?.append(stroke.position)
                    
                    var entityRef = remoteStrokeEntities[id]
                    _ = updateMeshAsync(
                        points: remoteStrokePoints[id]!,
                        color: stroke.color,
                        radius: stroke.radius,
                        entityRef: &entityRef,
                        on: canvas,
                        owner: nil
                    )
                    remoteStrokeEntities[id] = entityRef
                case .endStroke:
                    let id = stroke.strokeID
                    remoteStrokePoints.removeValue(forKey: id)
                    remoteStrokeEntities.removeValue(forKey: id)
                case .clear:
                    clearCanvas(canvas)
                }
            }
        }

        // Handle local drawing — reads from IsDrawingComponent set by a gesture system
        for entity in drawEntities {
            guard var dc = entity.components[DrawingComponent.self],
                  let isDrawingComp = entity.components[IsDrawingComponent.self] else {
                continue
            }

            if isDrawingComp.isActive {
                let tipPos = isDrawingComp.tipPosition
                
                print("[CustomDrawingSystem] Active drawing detected! TipPos: \(tipPos), points so far: \(dc.activeStrokePoints.count)")
                
                if dc.currentStrokeID == nil {
                    dc.currentStrokeID = UUID()
                    print("[CustomDrawingSystem] Started new stroke ID: \(dc.currentStrokeID!)")
                }

                let shouldSpawn: Bool
                if let lastPos = dc.lastPlacedPosition {
                    shouldSpawn = simd_distance(tipPos, lastPos) > Self.minSpacing
                } else {
                    shouldSpawn = true
                }

                if shouldSpawn {
                    dc.lastPlacedPosition = tipPos
                    dc.activeStrokePoints.append(tipPos)
                    
                    print("[CustomDrawingSystem] shouldSpawn = true, point count = \(dc.activeStrokePoints.count), tipPos: \(tipPos)")
                    
                    if !dc.isGeneratingMesh {
                        dc.isGeneratingMesh = true
                        print("[CustomDrawingSystem] updateMeshAsync called")
                        let startedAsync = updateMeshAsync(
                            points: dc.activeStrokePoints,
                            color: dc.currentColor,
                            radius: dc.sphereRadius,
                            entityRef: &dc.activeStrokeEntity,
                            on: canvas,
                            owner: entity
                        )
                        if !startedAsync {
                            dc.isGeneratingMesh = false
                        }
                    }

                    // Broadcast via SharePlay if active (throttle to ~10Hz)
                    let currentTime = Date().timeIntervalSince1970
                    if currentTime - dc.lastSharePlaySyncTime > 0.1 {
                        dc.lastSharePlaySyncTime = currentTime
                        if let receiver = receiverEntities.first(where: { _ in true }),
                           let manager  = receiver.components[SharePlayReceiverComponent.self]?.manager,
                           manager.isSharing,
                           let strokeID = dc.currentStrokeID {
                            let msg = StrokeMessage.addPoint(
                                strokeID: strokeID,
                                senderID: manager.localParticipantID,
                                position: tipPos,
                                color:    dc.currentColor,
                                radius:   dc.sphereRadius
                            )
                            Task { await manager.sendStroke(msg) }
                        }
                    }

                    // Increment canvas stroke count
                    if var canvasComp = canvas.components[CanvasComponent.self] {
                        canvasComp.strokeCount += 1
                        canvas.components.set(canvasComp)
                    }
                }
            } else {
                // Stroke ended
                if dc.currentStrokeID != nil {
                    print("[CustomDrawingSystem] Local stroke ended, clearing activeStrokePoints (count was \(dc.activeStrokePoints.count))")
                }
                
                if let strokeID = dc.currentStrokeID,
                   let receiver = receiverEntities.first(where: { _ in true }),
                   let manager  = receiver.components[SharePlayReceiverComponent.self]?.manager,
                   manager.isSharing {
                    let msg = StrokeMessage.endStroke(strokeID: strokeID, senderID: manager.localParticipantID)
                    Task { await manager.sendStroke(msg) }
                }
                
                dc.lastPlacedPosition = nil
                dc.activeStrokeEntity = nil
                dc.currentStrokeID = nil
                dc.activeStrokePoints.removeAll()
            }

            entity.components.set(dc)
        }
    }

    // MARK: Helpers

    private func updateMeshAsync(points: [SIMD3<Float>], color: SIMD4<Float>, radius: Float, entityRef: inout Entity?, on canvas: Entity, owner: Entity?) -> Bool {
        if points.count < 2 {
            if entityRef == nil {
                let material = resourceCache.material(for: color)
                let sphereMesh = MeshResource.generateSphere(radius: radius)
                let strokeEntity = ModelEntity(mesh: sphereMesh, materials: [material])
                strokeEntity.setPosition(points.isEmpty ? .zero : points[0], relativeTo: nil)
                canvas.addChild(strokeEntity)
                entityRef = strokeEntity
            } else if !points.isEmpty {
                entityRef?.setPosition(points[0], relativeTo: nil)
            }
            return false
        }

        guard let strokeEntity = entityRef as? ModelEntity else { 
            return false 
        }

        // Optimisation: For first few points, generate mesh synchronously on main thread for instant feedback
        if points.count < 10 {
            strokeEntity.setPosition(.zero, relativeTo: nil)
            let descriptor = TubeMeshBuilder.generateMeshDescriptor(from: points, radius: radius)
            do {
                strokeEntity.model?.mesh = try MeshResource.generate(from: [descriptor])
            } catch {
                print("Failed to replace mesh synchronously: \(error)")
            }
            return false
        }

        // For large meshes, run asynchronously to prevent blocking the rendering loop
        strokeEntity.setPosition(.zero, relativeTo: nil)
        
        Task { @MainActor in
            let descriptor = await Task.detached(priority: .userInitiated) {
                TubeMeshBuilder.generateMeshDescriptor(from: points, radius: radius)
            }.value
            
            do {
                strokeEntity.model?.mesh = try MeshResource.generate(from: [descriptor])
            } catch {
                print("Failed to replace mesh asynchronously: \(error)")
            }
            
            if let owner = owner, var dc = owner.components[DrawingComponent.self] {
                dc.isGeneratingMesh = false
                owner.components.set(dc)
            }
        }
        
        return true
    }

    private func clearCanvas(_ canvas: Entity) {
        canvas.children.removeAll()
        remoteStrokeEntities.removeAll()
        remoteStrokePoints.removeAll()
    }
}
