import SwiftUI

/// Animated highlight sweep for skeleton placeholders.
private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(colors: [.clear, .white.opacity(0.08), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: geometry.size.width * phase)
                }
                .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(Shimmer())
    }
}

struct SkeletonBar: View {
    var width: CGFloat?
    var height: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Theme.elevated)
            .frame(width: width, height: height)
    }
}

/// Placeholder mirroring MatchCard's layout so loading doesn't reflow.
struct MatchCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBar(width: 170, height: 9)
            row
            row
        }
        .padding(14)
        .cardBackground()
        .shimmer()
    }

    private var row: some View {
        HStack(spacing: 10) {
            Circle().fill(Theme.elevated).frame(width: 26, height: 26)
            SkeletonBar(width: 120, height: 12)
            Spacer()
            SkeletonBar(width: 18, height: 16)
        }
    }
}

struct SkeletonColumn: View {
    var count: Int = 4

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { _ in
                MatchCardSkeleton()
            }
        }
    }
}
