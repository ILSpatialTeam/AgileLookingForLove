//
//  GameTimerManager.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 03/07/26.
//

import RealityKit
import Observation

@MainActor
@Observable
class GameTimerManager {
    
    var gameTimeLeft: Double = 50.0
    var spawnAccumulator: Double = 0.0
    var instructionTimer: Double = 0.0
    
    func reset(duration: Double) {
        gameTimeLeft = duration
        spawnAccumulator = 0.0
        instructionTimer = 0.0
    }
    
    func tick(delta: Double, spawnInterval: Double) -> (shouldSpawn: Bool, shouldRefreshInstruction: Bool, isExpired: Bool) {
        gameTimeLeft -= delta
        let isExpired = gameTimeLeft <= 0
        if isExpired {
            gameTimeLeft = 0
        }
        
        spawnAccumulator += delta
        var shouldSpawn = false
        if spawnAccumulator >= spawnInterval {
            spawnAccumulator = 0.0
            shouldSpawn = true
        }
        
        instructionTimer -= delta
        var shouldRefreshInstruction = false
        if instructionTimer <= 0 {
            shouldRefreshInstruction = true
        }
        
        return (shouldSpawn, shouldRefreshInstruction, isExpired)
    }
}
