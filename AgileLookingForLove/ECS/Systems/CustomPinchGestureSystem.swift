//
//  CustomPinchGestureSystem.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 24/06/26.
//

import RealityKit
import Foundation
import ARKit
import ILSHandTracking
import ILSSpatialDraw

public struct CustomPinchGestureSystem: System {
    static let query = EntityQuery(where: .has(IsDrawingComponent.self) && .has(ILHandAnchorComponent.self) && .has(DrawingComponent.self))
    
    public init(scene: Scene) {}
    
    public func update(context: SceneUpdateContext) {
        let entities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        
        for entity in entities {
            guard var isDrawingComp = entity.components[IsDrawingComponent.self],
                  let anchorComp = entity.components[ILHandAnchorComponent.self],
                  let anchor = anchorComp.rightHand,
                  let skeleton = anchor.handSkeleton else {
                
                if var idc = entity.components[IsDrawingComponent.self] {
                    idc.frameCount = 0
                    idc.isActive = false
                    entity.components.set(idc)
                }
                continue
            }
            
            // Use middle finger and thumb tips to track the pinch
            let middleTip = ILHandPoseUtilities.worldPosition(of: .middleFingerTip, handAnchor: anchor, skeleton: skeleton)
            let thumbTip = ILHandPoseUtilities.worldPosition(of: .thumbTip, handAnchor: anchor, skeleton: skeleton)
            
            let dist = simd_distance(middleTip, thumbTip)
            // Pinch is active when they are closer than 2cm
            let pinchActive = dist < 0.02
            let activeJoint: ARKit.HandSkeleton.JointName = .middleFingerTip
            
            // Anti-jitter logic
            if pinchActive {
                isDrawingComp.frameCount = min(isDrawingComp.frameCount + 1, 10)
            } else {
                isDrawingComp.frameCount = max(isDrawingComp.frameCount - 1, 0)
            }
            
            isDrawingComp.isActive = (isDrawingComp.frameCount >= 3)
            
            if isDrawingComp.isActive {
                isDrawingComp.tipPosition = ILHandPoseUtilities.worldPosition(
                    of: activeJoint, handAnchor: anchor, skeleton: skeleton
                )
            }
            
            entity.components.set(isDrawingComp)
        }
    }
}
