//  Models/SignificanceEngine.swift
import Foundation
import SwiftData

struct SignificanceEngine {
    struct Coeff {
        static let α = 4.2         // weight scalar
        static let β1 = 0.07       // engagement
        static let β2 = 1.3        // recency
        static let β3 = 2.0        // favorite flag
    }

    static func refreshScores(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Event>()
            var events = try context.fetch(descriptor).sorted { $0.date < $1.date }
            guard let minDate = events.first?.date else { return }

            for (idx, ev) in events.enumerated() {
                let gapDays = ev.date.timeIntervalSince(minDate) / 86_400.0
                let sigmoid = { (x: Double) in 1 / (1 + exp(-x)) }

                let score = sigmoid(
                    Coeff.α * (ev.type.defaultWeight + ev.userWeight) +
                    Coeff.β1 * log1p(Double(ev.engagement)) +
                    Coeff.β2 / max(gapDays, 1) +
                    Coeff.β3 * (ev.favorite ? 1 : 0)
                )
                ev.significance = min(max(score, 0), 1)
                events[idx] = ev
            }
            try context.save()
        } catch {
            print("SignificanceEngine.refreshScores failed: \(error)")
            // Don't re-throw, just log the error to prevent app crashes
        }
    }
}