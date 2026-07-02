import Foundation

struct NewsItem: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let author: String
    let date: Date
    var url: URL?
}
