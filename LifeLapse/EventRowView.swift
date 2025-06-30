//  Views/EventRowView.swift
import SwiftUI

struct EventRowView: View {
    @Environment(EventStore.self) private var store
    @State private var isEditing = false
    let event: Event
    
    var body: some View {
        HStack {
            // Event type indicator
            Circle()
                .fill(event.type.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(event.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Significance indicator
            VStack(alignment: .trailing) {
                if event.favorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Text("\(Int(event.significance * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            isEditing = true
        }
        .sheet(isPresented: $isEditing) {
            EditEventView(store: store, event: event)
        }
    }
}
