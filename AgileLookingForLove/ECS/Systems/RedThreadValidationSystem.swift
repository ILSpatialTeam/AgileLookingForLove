//
//  RedThreadValidationSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import RealityKit
import ILSSpatialDraw
import Foundation
import ILSSpatialAudio

final class RedThreadValidationSystem: System {
    static let drawQuery  = EntityQuery(where: .has(DrawingComponent.self) && .has(IsDrawingComponent.self) && .has(DrawingStateComponent.self))
    static let shapeQuery = EntityQuery(where: .has(ShapeComponent.self) && .has(EntityStateComponent.self))
    
    required init(scene: Scene) {
    }
    
    func update(context: SceneUpdateContext) {
        // Ambil draw controller entity
        guard let drawer = context.entities(matching: Self.drawQuery, updatingSystemWhen: .rendering).first(where: { _ in true }),
              let isDrawing = drawer.components[IsDrawingComponent.self],
              let drawComp  = drawer.components[DrawingComponent.self],
              var stateDrawComp = drawer.components[DrawingStateComponent.self]
        else { return }
        
        let isCurrentlyDrawing = isDrawing.isActive
        
        if isCurrentlyDrawing {
            stateDrawComp.cachedStrokePoints = drawComp.activeStrokePoints
            stateDrawComp.cachedStrokeEntity = drawComp.activeStrokeEntity
        }
        
        // Deteksi momen BERHENTI menggambar benang
        if stateDrawComp.wasDrawing && !isCurrentlyDrawing {
            let strokePoints = stateDrawComp.cachedStrokePoints
            let strokeEntity = stateDrawComp.cachedStrokeEntity
            
            // Reset status pada komponen data
            stateDrawComp.cachedStrokePoints = []
            stateDrawComp.cachedStrokeEntity = nil
            
            print("[RedThreadValidationSystem] Stroke ended! Points count: \(strokePoints.count)")
            
            guard strokePoints.count >= 2 else {
                print("[RedThreadValidationSystem] Stroke points count < 2. Ignoring.")
                strokeEntity?.removeFromParent()
                stateDrawComp.wasDrawing = isCurrentlyDrawing
                drawer.components[DrawingStateComponent.self] = stateDrawComp
                return
            }
            
            let startPoint = strokePoints.first!
            let endPoint   = strokePoints.last!
            
            // Cari entity stunned yang paling dekat dengan ujung-ujung stroke
            let shapes = context.entities(matching: Self.shapeQuery, updatingSystemWhen: .rendering)
            var startEntity: Entity? = nil
            var endEntity:   Entity? = nil
            var minStartDist: Float = 0.80   // max jarak 80cm
            var minEndDist:   Float = 0.80
            
            let shapeArray = Array(shapes)
            
            for shape in shapeArray {
                guard let stateComp = shape.components[EntityStateComponent.self] else { continue }
                guard stateComp.state == .stunned else { continue }
                
                let visualCenter = shape.visualBounds(relativeTo: nil).center
                let dStart = simd_distance(visualCenter, startPoint)
                let dEnd   = simd_distance(visualCenter, endPoint)
                
                if dStart < minStartDist {
                    minStartDist = dStart
                    startEntity  = shape
                }
                if dEnd < minEndDist {
                    minEndDist = dEnd
                    endEntity  = shape
                }
            }
            
            if let a = startEntity, let b = endEntity {
                if a.id != b.id {
                    print("[RedThreadValidationSystem] Posting threadStrokeConnected notification!")
                    NotificationCenter.default.post(
                        name: .threadStrokeConnected,
                        object: nil,
                        userInfo: [
                            "entityA": a,
                            "entityB": b,
                            "strokeEntity": strokeEntity as Any
                        ]
                    )
                } else {
                    strokeEntity?.removeFromParent()
                }
            } else {
                strokeEntity?.removeFromParent()
            }
        }
        
        stateDrawComp.wasDrawing = isCurrentlyDrawing
        drawer.components[DrawingStateComponent.self] = stateDrawComp
    }
}

extension Notification.Name {
    static let threadStrokeConnected = Notification.Name("threadStrokeConnected")
}
