//
//  HandGestureInputSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 02/07/26.
//

//HandGesture (Heart and Draw)
//And Save it to each components

import ARKit
import RealityKit
import Foundation
import ILSSpatialDraw
import ILSHandTracking

final class HandGestureInputSystem: System {
    static let query = EntityQuery(where: .has(IsDrawingComponent.self) && .has(ILHandAnchorComponent.self) && .has(HeartGestureComponent.self))
    static let headQuery = EntityQuery(where: .has(HeadAnchorComponent.self))
    
    
    required init(scene: Scene) {}
    
    func update(context: SceneUpdateContext) {
        let entities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        
        // Update sensor tracking kepala
        HeadTracker.shared.update()
        var beamDirection = SIMD3<Float>(0, 0, -1)
        
        if let headTransform = HeadTracker.shared.lastHeadTransform {
            let zAxis = headTransform.columns.2
            let forwardDir = -SIMD3<Float>(zAxis.x, zAxis.y, zAxis.z)
            beamDirection = simd_normalize(forwardDir)
        } else {
            let heads = context.entities(matching: Self.headQuery, updatingSystemWhen: .rendering)
            var headIterator = heads.makeIterator()
            if let head = headIterator.next() {
                let orientation = head.orientation(relativeTo: nil)
                beamDirection = orientation.act(SIMD3<Float>(0, 0, -1))
            }
        }
        
        for entity in entities {
            guard var isDrawingComp = entity.components[IsDrawingComponent.self],
                  var heartComp = entity.components[HeartGestureComponent.self],
                  let anchorComp = entity.components[ILHandAnchorComponent.self] else {
                continue
            }
            
            // 1. Deteksi Gesture Hati (Kedua Tangan)
            var heartActive = false
            var heartCenter = SIMD3<Float>.zero
            
            if let leftHand = anchorComp.leftHand,
               let rightHand = anchorComp.rightHand,
               let leftSkeleton = leftHand.handSkeleton,
               let rightSkeleton = rightHand.handSkeleton,
               leftHand.isTracked,
               rightHand.isTracked {
                
                let leftIndexTip = ILHandPoseUtilities.worldPosition(of: .indexFingerTip, handAnchor: leftHand, skeleton: leftSkeleton)
                let rightIndexTip = ILHandPoseUtilities.worldPosition(of: .indexFingerTip, handAnchor: rightHand, skeleton: rightSkeleton)
                let leftThumbTip = ILHandPoseUtilities.worldPosition(of: .thumbTip, handAnchor: leftHand, skeleton: leftSkeleton)
                let rightThumbTip = ILHandPoseUtilities.worldPosition(of: .thumbTip, handAnchor: rightHand, skeleton: rightSkeleton)
                
                let indexDistance = simd_distance(leftIndexTip, rightIndexTip)
                let thumbDistance = simd_distance(leftThumbTip, rightThumbTip)
                
                let indexY = (leftIndexTip.y + rightIndexTip.y) / 2.0
                let thumbY = (leftThumbTip.y + rightThumbTip.y) / 2.0
                
                if indexDistance < 0.06 && thumbDistance < 0.06 && indexY > thumbY {
                    heartActive = true
                    heartCenter = (leftIndexTip + rightIndexTip + leftThumbTip + rightThumbTip) / 4.0
                }
            }
            
            heartComp.isActive = heartActive
            heartComp.centerPosition = heartCenter
            heartComp.direction = beamDirection
            
            // 2. Deteksi Gesture Cubitan Tangan Kanan (Pinch Drawing)
            if let rightHand = anchorComp.rightHand,
               let rightSkeleton = rightHand.handSkeleton,
               rightHand.isTracked {
                
                let middleTip = ILHandPoseUtilities.worldPosition(of: .middleFingerTip, handAnchor: rightHand, skeleton: rightSkeleton)
                let thumbTip = ILHandPoseUtilities.worldPosition(of: .thumbTip, handAnchor: rightHand, skeleton: rightSkeleton)
                
                let pinchDist = simd_distance(middleTip, thumbTip)
                let pinchActive = pinchDist < 0.035
                
                if pinchActive {
                    isDrawingComp.frameCount = min(isDrawingComp.frameCount + 1, 10)
                } else {
                    isDrawingComp.frameCount = max(isDrawingComp.frameCount - 1, 0)
                }
                isDrawingComp.isActive = (isDrawingComp.frameCount >= 3)
                
                if isDrawingComp.isActive {
                    isDrawingComp.tipPosition = middleTip
                }
            } else {
                isDrawingComp.frameCount = 0
                isDrawingComp.isActive = false
            }
            
            entity.components.set(heartComp)
            entity.components.set(isDrawingComp)
        }
    }
}
