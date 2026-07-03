//
//  GameViewModel.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import SwiftUI
import RealityKit
import Observation
@MainActor
@Observable
public final class GameViewModel {
    
    // Managers
    let timer = GameTimerManager()
    //let selection = SelectionManager()
    let entityManager = EntityManager()
    let sceneManager = GameSceneManager()
    let instructionManager: InstructionManager
    
    // Use Cases & Repositories
    private let repository: GameStateRepository
    private let connectEntities: ConnectEntityUseCase
    public let leaderboardRepository: LeaderboardRepository
    
    // Game States
    var gameState: GameState = .menu
    var score: Int = 0
    var lastConnectionMessage: String { instructionManager.lastConnectionMessage }
    var connectionResult: ConnectionResult { instructionManager.connectionResult }
    var currentInstruction: GameInstruction? { instructionManager.currentInstruction }
    public var leaderboardEntries: [LeaderboardEntry] = []
    
    var isHighScoreCandidate: Bool = false
    var hasSavedHighScore: Bool = false
    
    var activeEntities: [Entity] { entityManager.activeEntities }
    let spawnInterval: Double = GameConfiguration.spawnInterval
    private let maxEntitiesCount: Int = GameConfiguration.maxEntitiesLimit
    
    var gameTimeLeft: Double {
        get { timer.gameTimeLeft }
        set { timer.gameTimeLeft = newValue }
    }
    var instructionTimer: Double {
        get { timer.instructionTimer }
        set { timer.instructionTimer = newValue }
    }
    var firstSelectedEntity: Entity? {
        get { selection.firstSelectedEntity }
        set { selection.firstSelectedEntity = newValue }
    }
    
    private var content: RealityViewContent?
    
    // Initializer
    init(
        repository: GameStateRepository,
        generateInstruction: GenerateInstructionUseCase,
        connectEntities: ConnectEntityUseCase,
        leaderboardRepository: LeaderboardRepository
    ) {
        self.repository = repository
        self.connectEntities = connectEntities
        self.leaderboardRepository = leaderboardRepository
        self.instructionManager = InstructionManager(generateInstruction: generateInstruction)
        self.leaderboardEntries = leaderboardRepository.getTopScores()
    }
    
    convenience init() {
        let repository = InMemoryGameStateRepository()
        let generateInstruction = GenerateInstructionUseCase(repository: repository)
        let connectEntities = ConnectEntityUseCase(repository: repository)
        let leaderboardRepo = UserDefaultsLeaderboardRepository()
        
        self.init(
            repository: repository,
            generateInstruction: generateInstruction,
            connectEntities: connectEntities,
            leaderboardRepository: leaderboardRepo
        )
    }
    
    func setContent(_ content: RealityViewContent) {
        self.content = content
        sceneManager.setContent(content)
    }
    
    func setCanvas(_ canvas: Entity) {
        sceneManager.setCanvas(canvas)
    }
    
    func loadTemplates() async {
        await entityManager.loadTemplates()
    }
    
    func spawnEntity() {
        guard let content = self.content else { return }
        entityManager.spawnEntity(in: content, maxCount: maxEntitiesCount)
    }
    
    func spawnEntity(in content: RealityViewContent) {
        entityManager.spawnEntity(in: content, maxCount: maxEntitiesCount)
    }
    
    // Game Loop Tick
    func tickTimer(delta: Double) {
        guard case .playing = gameState else { return }
        
        let results = timer.tick(delta: delta, spawnInterval: spawnInterval)
        if results.shouldRefreshInstruction {
            refreshInstruction()
        }
        
        if results.shouldSpawn {
            for _ in 0..<5 {
                spawnEntity()
            }
        }
        
        if results.isExpired {
            isHighScoreCandidate = leaderboardRepository.isTopScore(score)
            hasSavedHighScore = false
            leaderboardEntries = leaderboardRepository.getTopScores()
            
            let isVictory = score >= GameConfiguration.victoryScoreThreshold
            gameState = .gameOver(victory: isVictory)
            clearPlayingEntities()
            
            if let content = self.content,
               let sceneRoot = content.entities.first(where: { $0.name == "SceneRoot" }) {
                let sound: AudioManager.SoundEffect = isVictory ? .victory : .defeat
                AudioManager.shared.play(sound, on: sceneRoot)
            }
        }
        score = repository.score
    }
    
    func startCountdown() {
        gameState = .countdown(3)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if case .countdown(3) = gameState { gameState = .countdown(2) } else { return }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if case .countdown(2) = gameState { gameState = .countdown(1) } else { return }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if case .countdown(1) = gameState { startGamePlay() }
        }
    }
    
    private func startGamePlay() {
        clearPlayingEntities()
        gameState = .playing
        timer.reset(duration: GameConfiguration.initialGameDuration)
        repository.resetScore()
        score = 0
        
        // Spawn di awal menggunakan self.content
        if let content = self.content {
            for _ in 0..<10 {
                entityManager.spawnEntity(in: content, maxCount: maxEntitiesCount)
            }
        }
        refreshInstruction()
    }
    
    func refreshInstruction() {
        let limit = instructionManager.refresh(activeEntities: activeEntities)
        instructionTimer = limit
    }
    
    // Action Handlers
    func handleShoot(entity: Entity) {
        sceneManager.handleShoot(entity: entity)
    }
    
//    func handleConnect(entity: Entity) {
//        guard let stateComp = entity.components[EntityStateComponent.self],
//              stateComp.state == .stunned,
//              let shapeComp = entity.components[ShapeComponent.self] else { return }
//        
//        if let first = selection.select(entity: entity) {
//            guard let firstShape = first.components[ShapeComponent.self] else { return }
//            
//            let isValid = connectEntities.execute(fromShape: firstShape.kind, toShape: shapeComp.kind)
//            if isValid {
//                sceneManager.createThreadBetween(first, entity)
//                sceneManager.markConnected(first)
//                sceneManager.markConnected(entity)
//            } else {
//                selection.resetVisuals(for: first)
//            }
//            score = repository.score
//        }
//    }
    
    func handleThreadStroke(entityA: Entity, entityB: Entity, strokeEntity: Entity?) {
        guard let shapeA = entityA.components[ShapeComponent.self],
              let shapeB = entityB.components[ShapeComponent.self] else {
            strokeEntity?.removeFromParent()
            return
        }
        
        let isValid = connectEntities.execute(fromShape: shapeA.kind, toShape: shapeB.kind)
        
        if isValid {
            instructionManager.showResult(.valid(fromShape: shapeA.kind, toShape: shapeB.kind), message: "CORRECT! \(shapeA.kind.displaySymbol) → \(shapeB.kind.displaySymbol) +100")
            score = repository.score
            
            sceneManager.markConnected(entityA)
            sceneManager.markConnected(entityB)
            AudioManager.shared.play(.connect, on: entityA)
            
            entityManager.activeEntities.removeAll(where: { $0 == entityA || $0 == entityB })
            entityA.setStatusIndicator(color: .systemGreen)
            entityB.setStatusIndicator(color: .systemGreen)
            
            strokeEntity?.removeFromParent()
            if strokeEntity == nil {
                let threadName = "RedThread_\(entityA.id)_\(entityB.id)"
                if let parent = entityA.parent,
                   let thread = parent.children.first(where: { $0.name == threadName }) {
                    thread.removeFromParent()
                }
            }
            
            sceneManager.applyMergeAnimation(entityA: entityA, entityB: entityB)
            
        } else {
            let instruction = currentInstruction?.description ?? "?"
            instructionManager.showResult(.invalid(fromShape: shapeA.kind, toShape: shapeB.kind), message: "WRONG! \(shapeA.kind.displaySymbol) → \(shapeB.kind.displaySymbol) | Instruction: \(instruction)")
            
            strokeEntity?.removeFromParent()
            entityA.setStatusIndicator(color: .red)
            entityB.setStatusIndicator(color: .red)
        }
    }
    
    func clearPlayingEntities() {
        sceneManager.clearScene(activeEntities: activeEntities)
        entityManager.clearAll()
        instructionManager.clear()
        selection.clear()
    }
    
    func saveHighScore(playerName: String) {
        guard isHighScoreCandidate, !hasSavedHighScore else { return }
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "Player" : trimmedName
        
        leaderboardRepository.saveScore(score, playerName: name)
        leaderboardEntries = leaderboardRepository.getTopScores()
        hasSavedHighScore = true
    }
    
    func exitToMenu() {
        clearPlayingEntities()
        gameState = .menu
    }
}
