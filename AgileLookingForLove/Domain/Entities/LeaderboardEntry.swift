//
//  LeaderboardEntry.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 30/06/26.
//

import Foundation

public struct LeaderboardEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let playerName: String
    public let score: Int
    public let date: Date
    
    public init(id: UUID = UUID(), playerName: String, score: Int, date: Date = Date()) {
        self.id = id
        self.playerName = playerName
        self.score = score
        self.date = date
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case playerName
        case score
        case date
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.score = try container.decode(Int.self, forKey: .score)
        self.date = try container.decode(Date.self, forKey: .date)
        // Jika playerName tidak ada di data lama, gunakan fallback "Player"
        self.playerName = try container.decodeIfPresent(String.self, forKey: .playerName) ?? "Player"
    }
}
