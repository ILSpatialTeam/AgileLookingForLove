//
//  LoveBeamSFXSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 02/07/26.
//


//Virtual Parcitle Only
import RealityKit
import simd

final class LoveBeamSFXSystem: System {
    static let loveBeamQuery = EntityQuery(where: .has(LoveBeamComponent.self))
    static let gestureQuery  = EntityQuery(where: .has(HeartGestureComponent.self))
    
    required init(scene: Scene) {}
    
    func update(context: SceneUpdateContext) {
        // Ambil data status gesture dari DrawController
        guard let controller = context.entities(matching: Self.gestureQuery, updatingSystemWhen: .rendering).first(where: {_ in true}),
              let heartGesture = controller.components[HeartGestureComponent.self]
        else { return }
        
        let loveBeams = context.entities(matching: Self.loveBeamQuery, updatingSystemWhen: .rendering)
        for loveBeam in loveBeams {
            if heartGesture.isActive {
                loveBeam.position = heartGesture.centerPosition
                
                if let emitterEntity = loveBeam.findEntity(named: "ParticleEmitter") {
                    if var vfx = emitterEntity.components[ParticleEmitterComponent.self] {
                        vfx.speed = 3.0
                        vfx.speedVariation = 0.5
                        vfx.mainEmitter.size = 0.05
                        vfx.mainEmitter.sizeMultiplierAtEndOfLifespan = 4.0
                        vfx.mainEmitter.sizeMultiplierAtEndOfLifespanPower = 1.0
                        vfx.mainEmitter.lifeSpan = 1.5
                        vfx.mainEmitter.birthRate = 25.0
                        vfx.mainEmitter.stretchFactor = 0.0
                        vfx.mainEmitter.acceleration = SIMD3<Float>(0, 0, 0)
                        vfx.mainEmitter.angleVariation = 0.15
                        
                        let from = SIMD3<Float>(0, 1, 0)
                        let to = heartGesture.direction
                        emitterEntity.orientation = quaternionFromTo(from: from, to: to)
                        
                        if !vfx.isEmitting {
                            vfx.isEmitting = true
                        }
                        emitterEntity.components.set(vfx)
                    }
                }
            } else {
                if let emitterEntity = loveBeam.findEntity(named: "ParticleEmitter") {
                    if var vfx = emitterEntity.components[ParticleEmitterComponent.self] {
                        if vfx.isEmitting {
                            vfx.isEmitting = false
                            emitterEntity.components.set(vfx)
                        }
                    }
                }
            }
        }
    }
    
    private func quaternionFromTo(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_quatf {
        let dot = simd_dot(from, to)
        if dot > 0.9999 {
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        } else if dot < -0.9999 {
            var perp = simd_cross(from, SIMD3<Float>(0, 1, 0))
            if simd_length(perp) < 0.001 {
                perp = simd_cross(from, SIMD3<Float>(1, 0, 0))
            }
            return simd_quatf(angle: Float.pi, axis: simd_normalize(perp))
        }
        let cross = simd_cross(from, to)
        return simd_normalize(simd_quatf(ix: cross.x, iy: cross.y, iz: cross.z, r: 1.0 + dot))
    }
}
