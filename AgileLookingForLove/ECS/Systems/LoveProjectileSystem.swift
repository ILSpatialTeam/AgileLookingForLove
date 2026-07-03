//
//  LoveProjectileSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 02/07/26.
//

import RealityKit
import Foundation

final class LoveProjectileSystem: System {
    static let gestureQuery    = EntityQuery(where: .has(HeartGestureComponent.self))
    static let loveBeamQuery   = EntityQuery(where: .has(LoveBeamComponent.self))
    static let projectileQuery = EntityQuery(where: .has(LoveProjectileComponent.self))
    static let shapesQuery     = EntityQuery(where: .has(ShapeComponent.self) && .has(EntityStateComponent.self))
    
    private var shootCooldown: Float = 0.0
    
    required init(scene: Scene) {}
    
    func update(context: SceneUpdateContext) {
        let deltaTime = Float(context.deltaTime)
        
        if shootCooldown > 0 {
            shootCooldown -= deltaTime
        }
        
        //Projectile Spawner
        if let controller = context.entities(matching: Self.gestureQuery, updatingSystemWhen: .rendering).first(where: {_ in true}),
           let heartGesture = controller.components[HeartGestureComponent.self],
           heartGesture.isActive,
           shootCooldown <= 0 {
            
            shootCooldown = 0.5
            let loveBeam = context.entities(matching: Self.loveBeamQuery, updatingSystemWhen: .rendering).first(where: {_ in true})
            
            let projectile = Entity()
            projectile.name = "LoveProjectile"
            projectile.position = heartGesture.centerPosition
            projectile.components.set(LoveProjectileComponent(direction: heartGesture.direction))
            
            if let loveBeam = loveBeam {
                if let parent = loveBeam.parent {
                    parent.addChild(projectile)
                } else {
                    loveBeam.addChild(projectile)
                }
            } else if let sceneRoot = context.scene.findEntity(named: "SceneRoot") {
                sceneRoot.addChild(projectile)
            }
            
            AudioManager.shared.play(.laserBeam, on: projectile)
        }
        
        // Movement & Collision projectile
        let projectiles = context.entities(matching: Self.projectileQuery, updatingSystemWhen: .rendering)
        
        for projectile in projectiles {
            guard var projComp = projectile.components[LoveProjectileComponent.self] else { continue }
            
            let movement = projComp.direction * projComp.speed * deltaTime
            projectile.position += movement
            projComp.distanceTraveled += simd_length(movement)
            
            var hitTarget = false
            let shapes = context.entities(matching: Self.shapesQuery, updatingSystemWhen: .rendering)
            
            for shape in shapes {
                guard let stateComp = shape.components[EntityStateComponent.self],
                      (stateComp.state == .idle || stateComp.state == .walking) else { continue }
                
                let shapePos = shape.visualBounds(relativeTo: nil).center
                let dist = simd_distance(projectile.position, shapePos)
                
                if dist < 0.4 {
                    var mutableStateComp = stateComp
                    mutableStateComp.state = .stunned
                    mutableStateComp.stunTimer = 7.0
                    shape.components[EntityStateComponent.self] = mutableStateComp
                    
                    NotificationCenter.default.post(
                        name: .stunEntityRequested,
                        object: nil,
                        userInfo: ["entity": shape]
                    )
                    
                    hitTarget = true
                    break
                }
            }
            
            if hitTarget || projComp.distanceTraveled >= projComp.maxDistance {
                projectile.removeFromParent()
            } else {
                projectile.components.set(projComp)
            }
        }
    }
}
