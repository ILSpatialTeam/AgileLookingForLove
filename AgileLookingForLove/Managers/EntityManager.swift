//
//  EntityManager.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 03/07/26.
//

import RealityKit
import RealityKitContent
import UIKit
import Observation
import _RealityKit_SwiftUI

@MainActor
@Observable
class EntityManager {
    var activeEntities: [Entity] = []
    var shapeTemplates: [ShapeKind: Entity] = [:]
    
    //Minion load 
    func loadTemplates() async {
        do {
            let sphereTemplate = try await Entity(named: "Animation/bundar_walk_anim", in: realityKitContentBundle)
            let cubeTemplate = try await Entity(named: "Animation/kotak_walk_anim", in: realityKitContentBundle)
            let pyramidTemplate = try await Entity(named: "Animation/segitiga_walk_anim", in: realityKitContentBundle)
            
            shapeTemplates[.sphere] = sphereTemplate
            shapeTemplates[.cube] = cubeTemplate
            shapeTemplates[.pyramid] = pyramidTemplate
            
            print("[EntityManager] Templates loaded successfully!")
        } catch {
            print("[EntityManager] Error loading templates: \(error)")
        }
    }
    
    //Create new entity withentity factory
    func spawnEntity(in content: RealityViewContent, maxCount: Int) {
        guard activeEntities.count < maxCount else {
            print("[Spawning] Maximum character limit reached (\(maxCount)). Skipping spawn.")
            return
        }
        
        let kind = ShapeKind.allCases.randomElement()!
        let template = shapeTemplates[kind]
        let color = colorFor(kind)
        
        let entity = EntityFactory.createCharacter(kind: kind, template: template, color: color)
        
        activeEntities.append(entity)
        content.add(entity)
    }
    
    func clearAll() {
        for entity in activeEntities {
            entity.removeFromParent()
        }
        activeEntities.removeAll()
    }
    
    private func colorFor(_ kind: ShapeKind) -> UIColor {
        switch kind {
        case .sphere:  return .systemRed
        case .cube:    return .systemBlue
        case .pyramid: return .systemGreen
        }
    }
}
