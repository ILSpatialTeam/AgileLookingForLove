//
//  DrawingStateComponent.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 03/07/26.
//

import RealityKit
import simd

public struct DrawingStateComponent: Component {
    public var wasDrawing: Bool = false
    public var cachedStrokePoints: [SIMD3<Float>] = []
        public var cachedStrokeEntity: Entity? = nil
    
    public init(){}
}
