import SwiftUI

struct OnboardingView: View {
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var page: Int = 0

    var body: some View {
        ZStack {
            BackgroundGlassMap()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    WelcomePage().tag(0)
                    PrivacyPage().tag(1)
                    RecordPage().tag(2)
                    RelivePage().tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                Button(action: advance) {
                    Text(page < 3 ? "Continue" : "Get Started")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func advance() {
        if page < 3 {
            withAnimation { page += 1 }
        } else {
            onFinished()
            dismiss()
        }
    }
}

// MARK: - Pages

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            // Illustration: 2x2 grid of icons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    IconTile(systemName: "bicycle")
                    IconTile(systemName: "figure.walk")
                }
                HStack(spacing: 12) {
                    IconTile(systemName: "figure.hiking")
                    IconTile(systemName: "figure.run")
                }
            }
            .frame(width: 220, height: 180)
            .padding(.bottom, 4)

            Text("Welcome to\nCycloNotes")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text("Track your bicycle rides, walks, hikes or runs.")
                Text("Capture moments along the way.")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct PrivacyPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            // Illustration: lock in rounded card
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 180, height: 160)
                Image(systemName: "lock.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 8)

            Text("Simple, Private, Local")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text("Your data stays on your iPhone.")
                Text("Nothing is uploaded or shared.")
                Text("Delete the app = delete your data.")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct RecordPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            // Illustration: glowing Start button on dark card
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 220, height: 140)
                Capsule()
                    .fill(Color.blue)
                    .shadow(color: .blue.opacity(0.6), radius: 14, x: 0, y: 0)
                    .frame(width: 160, height: 44)
                    .overlay(
                        Text("Start")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                    )
            }
            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 8)

            Text("Record")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                (Text("Tap ") + Text("Start").foregroundStyle(.blue) + Text(" to begin recording."))
                Text("Add notes or photos as you ride, walk, hike or run.")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct RelivePage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            // Illustration: small gallery + map thumbnails
            HStack(spacing: 16) {
                ThumbCard(systemName: "photo.on.rectangle.angled")
                ThumbCard(systemName: "map")
            }
            .padding(.bottom, 4)

            Text("Relive Your Journeys")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                (Text("View your activities in ") + Text("History").foregroundStyle(.blue) + Text("."))
                Text("See your route, stats, notes and photos - all in one place")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            Text("Made with ❤️ for those who love remembering where they've been")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Illustration helpers

private struct MapPathIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
            // Path line
            Path { path in
                path.move(to: CGPoint(x: 24, y: 120))
                path.addQuadCurve(to: CGPoint(x: 80, y: 40), control: CGPoint(x: 40, y: 40))
                path.addQuadCurve(to: CGPoint(x: 150, y: 110), control: CGPoint(x: 130, y: 70))
            }
            .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

            // Pins
            Group {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 24))
                    .position(x: 24, y: 120)
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.white)
                    .font(.system(size: 24))
                    .position(x: 150, y: 110)
            }
        }
    }
}

private struct ThumbCard: View {
    let systemName: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 110, height: 86)
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 8)
    }
}

private struct IconTile: View {
    let systemName: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 100, height: 80)
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 8)
    }
}

// A stylized dark, glassy background inspired by a muted map aesthetic
private struct BackgroundGlassMap: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(white: 0.12)], startPoint: .top, endPoint: .bottom)
            AngularGradient(gradient: Gradient(colors: [Color.blue.opacity(0.25), .clear, Color.cyan.opacity(0.2), .clear]), center: .center)
                .blur(radius: 120)
            GeometryReader { proxy in
                let size = proxy.size
                Path { path in
                    let step: CGFloat = 32
                    var x: CGFloat = 0
                    while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step }
                    var y: CGFloat = 0
                    while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                }
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
            }
        }
    }
}

#Preview {
    OnboardingView { }
}
