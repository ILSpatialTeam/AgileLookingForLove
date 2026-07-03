//
//  MonsterAISystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 03/07/26.
//

import RealityKit
import simd
import Foundation

final class MonsterAISystem: System {
    static let query = EntityQuery(where: .has(ShapeComponent.self) && .has(EntityStateComponent.self))
    
    required init(scene: Scene) {}
    
    func update(context: SceneUpdateContext) {
        let dt = context.deltaTime
        let entities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        
        for entity in entities {
            guard var stateComp = entity.components[EntityStateComponent.self] else { continue }
            
            // AI hanya aktif jika monster dalam keadaan berjalan atau diam
            if stateComp.state == .walking || stateComp.state == .idle {
                // 1. Timer Perubahan Arah Jalan Random
                stateComp.changeDirTimer -= dt
                if stateComp.changeDirTimer <= 0 {
                    let angle = Float.random(in: 0...(2 * .pi))
                    stateComp.direction = SIMD3<Float>(cos(angle), 0, sin(angle))
                    stateComp.changeDirTimer = Double.random(in: 1...3)
                }
                
                // 2. Timer Mengeluarkan Suara Minion
                stateComp.soundTimer -= dt
                if stateComp.soundTimer <= 0 {
                    AudioManager.shared.play(.minion, on: entity)
                    stateComp.soundTimer = Double.random(in: 6...12)
                }
                
                // 3. Batas Area Berjalan (Max 4 meter dari titik tengah)
                let pos = entity.position(relativeTo: nil)
                let distanceXZ = sqrt(pos.x * pos.x + pos.z * pos.z)
                if distanceXZ > 4.0 {
                    let toOrigin = normalize(SIMD3<Float>(-pos.x, 0, -pos.z))
                    stateComp.direction = toOrigin
                }
                
                // 4. Memutar Arah Badan Menghadap ke Arah Pergerakan
                if stateComp.direction.x != 0 || stateComp.direction.z != 0 {
                    let angle = atan2(stateComp.direction.x, stateComp.direction.z)
                    entity.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
                }
                
                entity.components[EntityStateComponent.self] = stateComp
            }
        }
    }
}
