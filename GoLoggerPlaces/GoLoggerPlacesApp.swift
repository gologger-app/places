import SwiftUI
import SwiftData

@main
struct GoLoggerPlacesApp: App {
    var modelContainer: ModelContainer = {
        let schema = Schema([
            Collection.self,
            Venue.self,
            Trail.self,
            TrailPoint.self,
            WayPoint.self,
            Visit.self,
            Link.self,
            Photo.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Home()
        }
        .modelContainer(modelContainer)
    }
}
