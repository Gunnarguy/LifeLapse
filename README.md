# LifeLapse

LifeLapse is an iOS application designed to help you automatically capture, organize, and relive your life's most significant moments. By intelligently analyzing your photos, locations, and other data, LifeLapse constructs a rich, interactive timeline of your life, allowing you to see your journey on a map and in a chronological view.

## Core Features

*   **Event Timeline:** A dynamic and interactive timeline that showcases your life events, complete with photos and details.
*   **Map Visualization:** View your life's journey on a map, with events pinned to the locations where they happened.
*   **Automatic Event Creation:** A "Significance Engine" that intelligently analyzes your data to automatically suggest and create meaningful events, reducing manual entry.
*   **Photo Integration:** Seamlessly import photos from your library to enrich your events and bring your memories to life.
*   **Video Export:** Generate beautiful video summaries and montages of your life's highlights to share with friends and family.
*   **iCloud Sync:** Your data is securely stored and synchronized across all your Apple devices using CloudKit, ensuring you always have access to your life's story.
*   **SwiftData Persistence:** Utilizes the modern SwiftData framework for robust and efficient local data storage.

## Technology Stack

*   **UI:** SwiftUI
*   **Data Persistence:** SwiftData
*   **Cloud Sync:** CloudKit
*   **Language:** Swift

## Project Structure

The project is organized into several key components:

*   **Views (`/LifeLapse/*View.swift`):** Contains all the SwiftUI views that make up the user interface, such as the main `ContentView`, `AddEventView`, `TimelinePlayerView`, and `MapOverlayView`.
*   **Data Model (`/LifeLapse/Event.swift`, `/LifeLapse/EventType.swift`):** Defines the core data structures for the application using SwiftData.
*   **Managers (`/LifeLapse/*Manager.swift`):** Handles logic for interacting with system services like CloudKit (`CloudKitManager`), Photos (`PhotosManager`), and Location (`LocationManager`).
*   **Core Logic (`/LifeLapse/SignificanceEngine.swift`, `/LifeLapse/VideoExporter.swift`):** Contains the business logic for features like determining event significance and exporting videos.
*   **App Entry Point (`/LifeLapse/LifeLapseApp.swift`):** The main entry point of the application, where the main window and data container are configured.
