//
//  MovementMonsterSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 03/07/26.
//

import RealityKit
import Foundation
import simd

final class MovementMonsterSystem: System {
        
    static let query = EntityQuery(where: .has(ShapeComponent.self) && .has(EntityStateComponent.self))

    required init(scene: Scene) {}
    
    func update(context: SceneUpdateContext) {
            let entities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
            
            for entity in entities {
                guard let stateComp = entity.components[EntityStateComponent.self] else { continue }
                
                // 1. Batas ketinggian jatuh minimum (mencegah monster jatuh menembus lantai)
                var pos = entity.position(relativeTo: nil)
                if pos.y < -0.2 {
                    var newPos = entity.position
                    newPos.y = 0.1
                    entity.position = newPos
                    pos.y = 0.1
                    
                    var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
                    motion.linearVelocity.y = 0
                    entity.components[PhysicsMotionComponent.self] = motion
                }
                
                // 2. Menerapkan Kecepatan Gerak Fisika Berdasarkan State Arah
                var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
                
                if stateComp.state == .walking || stateComp.state == .idle {
                    let speed: Float = 0.2
                    motion.linearVelocity = SIMD3<Float>(
                        stateComp.direction.x * speed,
                        motion.linearVelocity.y,
                        stateComp.direction.z * speed
                    )
                    motion.angularVelocity = .zero
                } else if stateComp.state == .stunned || stateComp.state == .connected {
                    // Hentikan pergerakan XZ jika stunned/connected
                    motion.linearVelocity = SIMD3<Float>(0, motion.linearVelocity.y, 0)
                    motion.angularVelocity = .zero
                }
                
                entity.components[PhysicsMotionComponent.self] = motion
            }
        }
}
