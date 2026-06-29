//
//  HUDOverlayView.swift
//  AgileLookingForLove
//
//  Created by Muhammad Benny Fathurrahman on 23/06/26.
//

import SwiftUI

struct HUDOverlayView: View {
    let viewModel: GameViewModel
    
    var body: some View {
        ZStack {
            switch viewModel.gameState {
            case .menu, .instructions:
                // HUD is empty or hidden in immersive view when in menu/instructions
                EmptyView()
                
            case .countdown(let count):
                // Giant, clean countdown number
                Text("\(count)")
                    .font(.system(size: 140, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 4)
                    .transition(.scale.combined(with: .opacity))
                    .id("countdown_\(count)")
                    
            case .playing:
                VStack(spacing: 30) {
                    // Top HUD row: Objective panel on the left, Score Progress bar in the middle, Timer panel on the right
                    HStack(alignment: .top) {
                        // Left: Objective panel
                        ObjectivePanel(instruction: viewModel.currentInstruction)
                            .frame(width: 260)
                        
                        Spacer()
                        
                        // Middle: Score bar
                        ScoreProgressView(score: viewModel.score, target: 500)
                            .padding(.top, 10)
                        
                        Spacer()
                        
                        // Right: Timer panel
                        TimerPanel(timeLeft: viewModel.gameTimeLeft)
                            .frame(width: 180)
                    }
                    .frame(width: 950)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Connection feedback toast (correct/wrong toast banner)
                    if !viewModel.lastConnectionMessage.isEmpty {
                        Text(viewModel.lastConnectionMessage)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                viewModel.lastConnectionMessage.hasPrefix("CORRECT") ?
                                    AnyShapeStyle(Color.green.opacity(0.85)) :
                                    AnyShapeStyle(Color.red.opacity(0.85))
                            )
                            .cornerRadius(16)
                            .shadow(radius: 4)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(duration: 0.3), value: viewModel.lastConnectionMessage)
                            .padding(.bottom, 60)
                    }
                }
                .frame(width: 1000, height: 600)
                
            case .gameOver(let victory):
                // Game Result overlay
                GameResultCard(victory: victory, score: viewModel.score) {
                    viewModel.startCountdown()
                } exitAction: {
                    viewModel.exitToMenu()
                }
            }
        }
    }
}

// Objective Panel View
struct ObjectivePanel: View {
    let instruction: GameInstruction?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Objective:")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 2)
            
            if let instruction = instruction {
                HStack(spacing: 12) {
                    ShapeIcon(kind: instruction.formShape)
                    
                    Text("+")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    ShapeIcon(kind: instruction.toShape)
                }
                .padding(.top, 4)
            } else {
                Text("Generating...")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
        )
    }
}

// Shape Icon view
struct ShapeIcon: View {
    let kind: ShapeKind
    
    var body: some View {
        VStack(spacing: 4) {
            switch kind {
            case .sphere:
                Circle()
                    .fill(Color.red)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 2)
            case .cube:
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue)
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 2)
            case .pyramid:
                Triangle()
                    .fill(Color.green)
                    .frame(width: 36, height: 36)
                    .overlay(Triangle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 2)
            }
            
            Text(kind.displaySymbol)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// Custom Score Progress View
struct ScoreProgressView: View {
    let score: Int
    let target: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("0")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("Score")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2)
                
                Spacer()
                
                Text("\(target)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 300)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 300, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    )
                
                if score > 0 {
                    let progressWidth = CGFloat(min(1.0, Double(score) / Double(target))) * 296
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.pink, Color.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth, height: 20)
                        .padding(.horizontal, 2)
                        .animation(.spring(duration: 0.3), value: score)
                }
            }
            
            Text("Current: \(score)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 1)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
        )
    }
}

// Timer Panel View
struct TimerPanel: View {
    let timeLeft: Double
    
    var body: some View {
        VStack(spacing: 6) {
            Text("Timer")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 2)
            
            Text(formatTime(timeLeft))
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundColor(timeLeft <= 10 ? .red : .white)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .animation(.spring, value: timeLeft <= 10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
        )
    }
    
    private func formatTime(_ time: Double) -> String {
        let totalSeconds = Int(ceil(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Game Result Card View
struct GameResultCard: View {
    let victory: Bool
    let score: Int
    let restartAction: () -> Void
    let exitAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text(victory ? "VICTORY!" : "GAME OVER")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(victory ? .green : .red)
                .shadow(color: .black.opacity(0.5), radius: 4)
            
            Text("Your Final Score: \(score)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.bottom, 10)
            
            HStack(spacing: 20) {
                Button(action: restartAction) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Button(action: exitAction) {
                    Text("Main Menu")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.25), lineWidth: 2)
        )
        .shadow(radius: 15)
        .frame(width: 480)
    }
}
