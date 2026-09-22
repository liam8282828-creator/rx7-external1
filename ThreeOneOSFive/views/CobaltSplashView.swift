import SwiftUI

struct CobaltSplashView: View {
    @Binding var showSplash: Bool
    
    @State private var phase = 0
    @State private var outerRotation = 0.0
    @State private var innerRotation = 0.0
    @State private var dotOrbit = 0.0
    @State private var messageIndex = 0
    @State private var progress = 0.0
    
    private let messages = [
        "INITIALIZING COBALT",
        "LOADING SYSTEM",
        "VERIFYING ACCESS",
        "PREPARING CONTROL PANEL",
        "SYSTEM READY"
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.black, MoonPlaceTheme.surface, Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            // Ambient glow
            Circle()
                .fill(MoonPlaceTheme.accentBlue)
                .frame(width: 300, height: 300)
                .blur(radius: 120)
                .opacity(phase >= 1 ? 0.2 : 0)
            
            VStack(spacing: 50) {
                // Logo & Title
                VStack(spacing: 20) {
                    MoonLogoView(size: 110, pulse: phase >= 2)
                        .opacity(phase >= 2 ? 1 : 0)
                        .scaleEffect(phase >= 2 ? 1 : 0.8)
                    
                    Text("COBALT")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(8)
                        .opacity(phase >= 3 ? 1 : 0)
                        .offset(y: phase >= 3 ? 0 : 10)
                }
                
                // Custom Loader
                if phase >= 3 {
                    VStack(spacing: 30) {
                        ZStack {
                            // Outer ring
                            Circle()
                                .stroke(MoonPlaceTheme.accent.opacity(0.3), lineWidth: 4)
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .trim(from: 0, to: 0.4)
                                .stroke(MoonPlaceTheme.accentBlue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(outerRotation))
                            
                            // Inner ring
                            Circle()
                                .stroke(MoonPlaceTheme.accentBlue.opacity(0.2), lineWidth: 3)
                                .frame(width: 40, height: 40)
                            
                            Circle()
                                .trim(from: 0, to: 0.6)
                                .stroke(MoonPlaceTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(innerRotation))
                            
                            // Orbiting dots
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 4, height: 4)
                                    .offset(y: -38)
                                    .rotationEffect(.degrees(dotOrbit + Double(i) * 120))
                                    .moonGlow(MoonPlaceTheme.accentBlue, radius: 4)
                            }
                        }
                        
                        // Status Text
                        Text(messages[messageIndex])
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MoonPlaceTheme.accentBlue)
                            .tracking(2)
                            .id(messageIndex)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        
                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 4)
                                
                                Capsule()
                                    .fill(LinearGradient(colors: [MoonPlaceTheme.accent, MoonPlaceTheme.accentBlue], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * progress, height: 4)
                                    .moonGlow(MoonPlaceTheme.accentBlue, radius: 4)
                            }
                        }
                        .frame(width: 180, height: 4)
                    }
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            runSequence()
        }
    }
    
    private func runSequence() {
        // Step 1: Ambient light
        withAnimation(.easeIn(duration: 0.8)) { phase = 1 }
        
        // Step 2: Logo appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { phase = 2 }
        }
        
        // Step 3: Name and Loader
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.6)) { phase = 3 }
            
            // Start spinning
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                outerRotation = 360
            }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                innerRotation = -360
            }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                dotOrbit = 360
            }
            
            // Progress and messages
            animateProgress()
        }
    }
    
    private func animateProgress() {
        let totalSteps = messages.count
        let stepDuration = 0.6
        
        for i in 0..<totalSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepDuration) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    messageIndex = i
                }
                withAnimation(.linear(duration: stepDuration)) {
                    progress = Double(i + 1) / Double(totalSteps)
                }
                
                if i == totalSteps - 1 {
                    // Finish
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            showSplash = false
                        }
                    }
                }
            }
        }
    }
}
