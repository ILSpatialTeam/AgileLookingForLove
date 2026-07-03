//
//  InstructionManager.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 03/07/26.
//

import Foundation
import Observation
import RealityKit

enum ConnectionResult: Equatable {
    case none
    case valid(fromShape: ShapeKind, toShape: ShapeKind)
    case invalid(fromShape: ShapeKind, toShape: ShapeKind)
}

@MainActor
@Observable
class InstructionManager {
    var currentInstruction: GameInstruction?
    var connectionResult: ConnectionResult = .none
    var lastConnectionMessage: String = ""
    
    private let generateInstruction: GenerateInstructionUseCase
    
    init(generateInstruction: GenerateInstructionUseCase) {
        self.generateInstruction = generateInstruction
    }
    
    //Suffle Instruction based on current minion in thscene
    func refresh(activeEntities: [Entity]) -> Double {
        let kinds = activeEntities.compactMap { $0.components[ShapeComponent.self]?.kind }
        let uniqueKinds = Array(Set(kinds))
        
        let instruction = generateInstruction.execute(availableKinds: uniqueKinds)
        currentInstruction = instruction
        
        return instruction.timeLimit
    }
    
    //hud result spawn
    func showResult(_ result: ConnectionResult, message: String) {
        connectionResult = result
        lastConnectionMessage = message
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            // Cek jika status belum di-override oleh koneksi baru
            if connectionResult == result {
                connectionResult = .none
                lastConnectionMessage = ""
            }
        }
    }
    
    func clear() {
        connectionResult = .none
        lastConnectionMessage = ""
    }
}
