//
//  LeaderboardRepository.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 30/06/26.
//

import Foundation

public protocol LeaderboardRepository: AnyObject {
    func getTopScores() -> [LeaderboardEntry]
    func saveScore(_ score: Int, playerName: String)
    func isTopScore(_ score: Int) -> Bool
}
