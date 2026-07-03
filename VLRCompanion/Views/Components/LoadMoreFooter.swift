import SwiftUI

/// Footer that grows a paged list as it scrolls into view. Place it right after
/// the visible rows in a `LazyVStack`; it renders a spinner and calls `grow`
/// the moment it appears, so large feeds (50+ results) show a first page and
/// append the rest on demand instead of building every row up front.
///
/// Paging is a presentation concern over the already-cached array — the data
/// layer still holds the full payload, so offline still works.
struct LoadMoreFooter: View {
    let visible: Int
    let total: Int
    let grow: () -> Void

    var body: some View {
        if visible < total {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 14)
            .onAppear(perform: grow)
        }
    }
}

/// Standard page size for scroll-loaded match feeds.
enum Paging {
    static let matchPageSize = 20
    static let listPageSize = 15

    /// Next window size, clamped to the total.
    static func next(_ visible: Int, total: Int, step: Int) -> Int {
        min(visible + step, total)
    }
}
