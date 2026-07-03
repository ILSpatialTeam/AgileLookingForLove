//
//  GameSceneManager.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 03/07/26.
//

import RealityKit
import UIKit
import ILSSpatialDraw
import _RealityKit_SwiftUI

@MainActor
class GameSceneManager {
    private var content: RealityViewContent?
    private var canvasEntity: Entity?
    
    func setContent(_ content: RealityViewContent) {
        self.content = content
    }
    
    func setCanvas(_ canvas: Entity) {
        self.canvasEntity = canvas
    }
    
    // Stun monster secara visual dan status komponen
    func handleShoot(entity: Entity) {
        guard var stateComp = entity.components[EntityStateComponent.self] else { return }
        guard stateComp.state == .idle || stateComp.state == .walking || stateComp.state == .stunned else { return }
        
        stateComp.state = .stunned
        stateComp.stunTimer = 7.0
        entity.components[EntityStateComponent.self] = stateComp
        
        entity.setStatusIndicator(color: .red)
        entity.stopAllAnimations(recursive: true)
        AudioManager.shared.play(.stunned, on: entity)
    }
    
    //Mengubah status entitas menjadi terhubung (connected)
    func markConnected(_ entity: Entity) {
        var stateComp = entity.components[EntityStateComponent.self] ?? EntityStateComponent()
        stateComp.state = .connected
        entity.components[EntityStateComponent.self] = stateComp
    }
    
    // Membuat objek visual benang merah di antara dua entitas
    func createThreadBetween(_ entityA: Entity, _ entityB: Entity) {
        guard let content = self.content else { return }
        let posA = entityA.position(relativeTo: nil)
        let posB = entityB.position(relativeTo: nil)
        let points = makeThreadPoints(from: posA, to: posB, segments: 12, sag: 0.06)
        let descriptor = TubeMeshBuilder.generateMeshDescriptor(from: points, radius: 0.004)
        do {
            let mesh = try MeshResource.generate(from: [descriptor])
            var material = UnlitMaterial()
            material.color = .init(tint: UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1.0))
            let threadEntity = ModelEntity(mesh: mesh, materials: [material])
            threadEntity.name = "RedThread_\(entityA.id)_\(entityB.id)"
            
            if let canvas = canvasEntity {
                canvas.addChild(threadEntity)
            } else {
                content.add(threadEntity)
            }
        } catch {
            print("[RedThread] Failed to generate mesh: \(error)")
        }
    }
    
    private func makeThreadPoints(from start: SIMD3<Float>, to end: SIMD3<Float>, segments: Int = 12, sag: Float = 0.06) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        for i in 0...segments {
            let t = Float(i) / Float(segments)
            var p = start + (end - start) * t
            p.y -= sag * sin(t * .pi)
            points.append(p)
        }
        return points
    }
    
    //Memasang komponen animasi penggabungan minion (MergeAnimationComponent)
    func applyMergeAnimation(entityA: Entity, entityB: Entity) {
        let posA = entityA.position(relativeTo: nil)
        let posB = entityB.position(relativeTo: nil)
        let midpoint = (posA + posB) / 2.0
        
        entityA.components.remove(PhysicsBodyComponent.self)
        entityB.components.remove(PhysicsBodyComponent.self)
        entityA.stopAllAnimations(recursive: true)
        entityB.stopAllAnimations(recursive: true)
        
        entityA.components.set(MergeAnimationComponent(midpoint: midpoint, startPosition: posA))
        entityB.components.set(MergeAnimationComponent(midpoint: midpoint, startPosition: posB))
    }
    
    //Mereset seluruh isi 3D scene (minion, projectile, canvas benang)
    func clearScene(activeEntities: [Entity]) {
        for entity in activeEntities {
            entity.removeFromParent()
        }
        
        if let content = self.content {
            if let drawController = content.entities.first(where: { $0.name == "DrawController" }) {
                if var dc = drawController.components[DrawingComponent.self] {
                    dc.activeStrokeEntity = nil
                    dc.currentStrokeID = nil
                    dc.activeStrokePoints.removeAll()
                    dc.lastPlacedPosition = nil
                    dc.isGeneratingMesh = false
                    drawController.components.set(dc)
                }
                if var isDrawing = drawController.components[IsDrawingComponent.self] {
                    isDrawing.isActive = false
                    isDrawing.frameCount = 0
                    drawController.components.set(isDrawing)
                }
            }
            
            if let canvas = content.entities.first(where: { $0.name == "RedThreadCanvas" }) {
                canvas.children.removeAll()
            }
            
            let extraEntities = content.entities.filter {
                ($0.name.hasPrefix("RedThread") && $0.name != "RedThreadCanvas") ||
                $0.name == "LoveProjectile"
            }
            for entity in extraEntities {
                entity.removeFromParent()
            }
        }
    }
}
