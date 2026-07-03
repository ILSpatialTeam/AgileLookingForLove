//
//  SelectionManager.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 03/07/26.
//

import RealityKit
import UIKit
import Observation

@Observable
@MainActor
class SelectionManager {
    var firstSelectedEntity: Entity? = nil
    
    func select(entity: Entity) -> Entity? {
        if firstSelectedEntity == nil {
            firstSelectedEntity = entity
            highlightEntity(entity)
            return nil
        } else {
            let first = firstSelectedEntity
            firstSelectedEntity = nil
            return first
        }
    }
    
    func clear() {
        firstSelectedEntity = nil
    }
    
    func highlightEntity(_ entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            // Simpan material asli jika belum pernah disimpan
            if entity.components[OriginalMaterialsComponent.self] == nil {
                entity.components.set(OriginalMaterialsComponent(materials: model.materials))
            }
            // Glow Yellow
            model.materials = [SimpleMaterial(color: .yellow, isMetallic: true)]
            entity.components[ModelComponent.self] = model
        }
    }
    
    func resetVisuals(for entity: Entity) {
        if let original = entity.components[OriginalMaterialsComponent.self] {
            if var model = entity.components[ModelComponent.self] {
                model.materials = original.materials
                entity.components[ModelComponent.self] = model
            }
        }
    }
}
