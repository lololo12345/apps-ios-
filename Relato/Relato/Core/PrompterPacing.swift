import Foundation

/// Maps reading time to scroll offset so the teleprompter advances at the speed you speak.
///
/// Each beat is an anchor: when the elapsed reading time reaches the beat's start time, the top of that beat
/// sits on the reading line. Between anchors the offset is interpolated linearly. This keeps the scroll in
/// sync with spoken time even when beats differ in visual height (headers, short lines, long paragraphs).
struct PrompterPacing: Equatable, Sendable {
    struct Anchor: Equatable, Sendable {
        let time: Double
        let offset: Double
    }

    /// Minimum time a beat occupies, so tiny beats do not flash by.
    static let minimumSegmentSeconds: Double = 0.8

    let anchors: [Anchor]

    init(segmentSeconds: [Double], segmentOffsets: [Double], endOffset: Double) {
        precondition(segmentSeconds.count == segmentOffsets.count, "Every segment needs a measured offset")
        var anchors: [Anchor] = []
        var time: Double = 0
        for (seconds, offset) in zip(segmentSeconds, segmentOffsets) {
            anchors.append(Anchor(time: time, offset: offset))
            time += max(Self.minimumSegmentSeconds, seconds)
        }
        anchors.append(Anchor(time: time, offset: max(endOffset, anchors.last?.offset ?? 0)))
        self.anchors = anchors
    }

    var totalTime: Double { anchors.last?.time ?? 0 }
    var endOffset: Double { anchors.last?.offset ?? 0 }

    func offset(at time: Double) -> Double {
        guard let first = anchors.first, let last = anchors.last else { return 0 }
        if time <= first.time { return first.offset }
        if time >= last.time { return last.offset }
        let upper = anchors.firstIndex { $0.time > time } ?? anchors.count - 1
        let a = anchors[upper - 1]
        let b = anchors[upper]
        let span = b.time - a.time
        guard span > 0 else { return b.offset }
        return a.offset + (b.offset - a.offset) * (time - a.time) / span
    }

    func time(atOffset offset: Double) -> Double {
        guard let first = anchors.first, let last = anchors.last else { return 0 }
        if offset <= first.offset { return first.time }
        if offset >= last.offset { return last.time }
        let upper = anchors.firstIndex { $0.offset > offset } ?? anchors.count - 1
        let a = anchors[upper - 1]
        let b = anchors[upper]
        let span = b.offset - a.offset
        guard span > 0 else { return b.time }
        return a.time + (b.time - a.time) * (offset - a.offset) / span
    }

    /// Index of the segment being read at `time` (clamped to the last segment).
    func segmentIndex(at time: Double) -> Int {
        let segmentCount = anchors.count - 1
        guard segmentCount > 0 else { return 0 }
        let index = (anchors.lastIndex { $0.time <= time } ?? 0)
        return min(index, segmentCount - 1)
    }
}
