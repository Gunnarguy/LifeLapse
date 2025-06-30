//
//  ModelConfiguration+Extensions.swift
//  LifeLapse
//
//  Created by Gunnar Hostetler on 6/25/25.
//

import SwiftData
import Foundation

extension ModelConfiguration {
    /// Create a configuration that explicitly disables CloudKit
    static func localOnly(schema: Schema) -> ModelConfiguration {
        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
    }
    
    /// Create a configuration for in-memory storage without CloudKit
    static func inMemoryOnly(schema: Schema) -> ModelConfiguration {
        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
    }
    
    /// Create a CloudKit configuration with error handling
    static func cloudKit(schema: Schema, containerIdentifier: String) -> ModelConfiguration? {
        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .private(containerIdentifier)
        )
    }
}
