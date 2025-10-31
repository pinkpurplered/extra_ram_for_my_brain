import Foundation

struct RecordingSegment: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let startDate: Date
    let duration: TimeInterval

    init(url: URL, startDate: Date, duration: TimeInterval) {
        self.id = UUID()
        self.url = url
        self.startDate = startDate
        self.duration = duration
    }

    var endDate: Date { startDate.addingTimeInterval(duration) }
}


