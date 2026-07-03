//
//  HeartGestureComponent.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 02/07/26.
//

import RealityKit
import simd

struct HeartGestureComponent: Component {
    public var isActive: Bool = false
    public var centerPosition: SIMD3<Float> = .zero
    public var direction: SIMD3<Float> = SIMD3<Float>(0,0,-1)
    
    public init() {}
}
