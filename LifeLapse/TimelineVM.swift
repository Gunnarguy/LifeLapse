//  ViewModels/TimelineVM.swift
import Foundation
import SwiftUI
import SwiftData

@Observable
final class TimelineVM {
    private let store: EventStore
    var playhead: Date = .now
    var isPlaying = false
    private var timer: Timer?
    
    // Playback speed (days per second)
    var playbackSpeed: Double = 7.0

    // Derived:
    var span: ClosedRange<Date> {
        guard let first = store.events.first?.date,
              let last = store.events.last?.date else { return Date()...Date() }
        return first ... last
    }

    init(store: EventStore) {
        self.store = store
        // Start playhead at the beginning of events
        if let firstEvent = store.events.first {
            playhead = firstEvent.date
        }
    }

    func togglePlay() {
        isPlaying.toggle()
        
        if isPlaying {
            startPlayback()
        } else {
            stopPlayback()
        }
    }
    
    func setPlayhead(to date: Date) {
        playhead = max(span.lowerBound, min(span.upperBound, date))
    }
    
    private func startPlayback() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Advance playhead
            let newDate = self.playhead.addingTimeInterval(self.playbackSpeed * 86_400 * 0.1) // 0.1 seconds
            
            if newDate > self.span.upperBound {
                // Reached the end, stop or loop
                self.playhead = self.span.lowerBound
                self.stopPlayback()
            } else {
                self.playhead = newDate
            }
        }
    }
    
    private func stopPlayback() {
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }
    
    deinit {
        timer?.invalidate()
    }
}