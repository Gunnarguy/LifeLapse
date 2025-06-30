//  Views/TimelinePlayerView.swift
import SwiftUI
import SwiftData

struct TimelinePlayerView: View {
    @Environment(\.modelContext) private var context
    @State private var store: EventStore?
    @State private var vm: TimelineVM?

    var body: some View {
        VStack(spacing: 20) {
            if let vm = vm {
                // Timeline rail at the top
                TimelineRailView(vm: vm)
                    .frame(height: 120)
                    .padding(.horizontal)

                // Map in the middle
                MapOverlayView(vm: vm)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)

                // Controls at the bottom
                HStack(spacing: 40) {
                    Button {
                        vm.togglePlay()
                    } label: {
                        Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.accentColor)
                    }
                    
                    if let store = store {
                        NavigationLink {
                            SettingsView(store: store)
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 10)
                
                Spacer()
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .task {
            if store == nil {
                let eventStore = EventStore(context: context)
                store = eventStore
                vm = TimelineVM(store: eventStore)
                // Seed demo data and refresh significance scores
                DemoData.seed(into: eventStore)
                SignificanceEngine.refreshScores(context: context)
            }
        }
    }
}