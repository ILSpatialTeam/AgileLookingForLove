//
//  LeaderboardView.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 30/06/26.
//

import SwiftUI

struct LeaderboardView: View {
    let viewModel: GameViewModel
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Leaderboard (Top Cepe)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    dismissWindow(id: "LeaderboardWindow")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            if viewModel.leaderboardEntries.isEmpty {
                Spacer()
                Text("No scores recorded yet!")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            } else {
                List {
                    ForEach(Array(viewModel.leaderboardEntries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                        HStack {
                            Text("#\(index + 1)")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(index < 3 ? .yellow : .white.opacity(0.6))
                                .frame(width: 36, alignment: .leading)
                            
                            // Tampilkan nama pemain
                            Text(entry.playerName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(entry.score) pts")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.leading, 12)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.04))
                                .padding(.vertical, 3)
                        )
                    }
                }
                .listStyle(.plain)
                .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassBackgroundEffect()
    }
}
