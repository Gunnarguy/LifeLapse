//  Views/TimelineRailView.swift
import SwiftUI
import SwiftData

struct TimelineRailView: View {
    var vm: TimelineVM
    @Environment(\.modelContext) private var context

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 8)
                
                Canvas { ctx, size in
                    // Use DataHelpers for safer event fetching
                    let events = DataHelpers.fetchAllEvents(from: context)
                    
                    guard let earliest = events.first?.date,
                          let latest = events.last?.date else { return }

                    let total = latest.timeIntervalSince(earliest)
                    let y = size.height / 2
                    
                    // Draw main timeline
                    let path = Path { p in
                        p.move(to: .init(x: 0, y: y))
                        p.addLine(to: .init(x: size.width, y: y))
                    }
                    ctx.stroke(path, with: .color(.accentColor), style: StrokeStyle(lineWidth: 4, lineCap: .round))

                    // Draw events
                    for ev in events {
                        let x = size.width * CGFloat(ev.date.timeIntervalSince(earliest) / total)
                        let radius = CGFloat(6 + 16 * ev.significance)
                        let color = ev.type.color.opacity(0.3 + 0.7 * ev.significance)
                        
                        // Event circle
                        ctx.fill(
                            Path(ellipseIn: .init(x: x-radius, y: y-radius, width: 2*radius, height: 2*radius)),
                            with: .color(color)
                        )
                        
                        // Inner dot
                        let innerRadius = CGFloat(3 + 6 * ev.significance)
                        ctx.fill(
                            Path(ellipseIn: .init(x: x-innerRadius, y: y-innerRadius, width: 2*innerRadius, height: 2*innerRadius)),
                            with: .color(ev.type.color)
                        )
                        
                        // Favorite indicator
                        if ev.favorite {
                            ctx.fill(
                                Path(ellipseIn: .init(x: x-2, y: y-2, width: 4, height: 4)),
                                with: .color(.red)
                            )
                        }
                    }
                    
                    // Draw playhead
                    if !events.isEmpty {
                        let playheadX = size.width * CGFloat(vm.playhead.timeIntervalSince(earliest) / total)
                        let playheadPath = Path { p in
                            p.move(to: .init(x: playheadX, y: 0))
                            p.addLine(to: .init(x: playheadX, y: size.height))
                        }
                        ctx.stroke(playheadPath, with: .color(.primary), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        
                        // Playhead indicator
                        ctx.fill(
                            Path(ellipseIn: .init(x: playheadX-6, y: y-6, width: 12, height: 12)),
                            with: .color(.primary)
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: vm.playhead)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let events = DataHelpers.fetchAllEvents(from: context)
                        guard let earliest = events.first?.date,
                              let latest = events.last?.date else { return }
                        
                        let pct = max(0, min(1, value.location.x / geo.size.width))
                        let interval = latest.timeIntervalSince(earliest)
                        vm.playhead = earliest.addingTimeInterval(Double(pct) * interval)
                    }
            )
        }
    }
}