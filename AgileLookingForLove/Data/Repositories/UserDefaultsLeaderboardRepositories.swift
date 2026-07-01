//
//  UserDefaultsLeaderboardRepositories.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 30/06/26.
//

import Foundation

public final class UserDefaultsLeaderboardRepository: LeaderboardRepository {
    private let storageKey = "agile_leaderboard_scores"
    private let maxEntries = 10
    
    public init() {}
    
    public func getTopScores() -> [LeaderboardEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        do {
            let entries = try JSONDecoder().decode([LeaderboardEntry].self, from: data)
            return entries.sorted { $0.score > $1.score }
        } catch {
            print("[LeaderboardRepository] Failed to decode leaderboard data: \(error)")
            return []
        }
    }
    
    public func isTopScore(_ score: Int) -> Bool {
        let currentEntries = getTopScores()
        if currentEntries.count < maxEntries {
            return true
        }

        if let lowestScore = currentEntries.last?.score {
            return score > lowestScore
        }
        return false
    }
    
    public func saveScore(_ score: Int, playerName: String) {
        var currentEntries = getTopScores()
        let newEntry = LeaderboardEntry(playerName: playerName, score: score)
        currentEntries.append(newEntry)
        
        // Urutkan berdasarkan skor tertinggi dan batasi hanya top 10
        let sortedEntries = Array(currentEntries.sorted { $0.score > $1.score }.prefix(maxEntries))
        
        do {
            let data = try JSONEncoder().encode(sortedEntries)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("[LeaderboardRepository] Score \(score) for \(playerName) saved successfully!")
        } catch {
            print("[LeaderboardRepository] Failed to encode leaderboard data: \(error)")
        }
    }
}
