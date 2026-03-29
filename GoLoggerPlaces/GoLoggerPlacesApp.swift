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
            Photo.self,
            TravelMode.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            // Seed built-in travel modes on first launch
            let context = container.mainContext
            let descriptor = FetchDescriptor<TravelMode>(predicate: #Predicate { $0.isBuiltIn })
            if let existing = try? context.fetch(descriptor), existing.isEmpty {
                context.insert(TravelMode(name: "Walking", icon: "figure.walk", isBuiltIn: true, sortOrder: 0))
                context.insert(TravelMode(name: "Driving", icon: "car.fill", isBuiltIn: true, sortOrder: 1))
                try? context.save()
            }
            return container
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
