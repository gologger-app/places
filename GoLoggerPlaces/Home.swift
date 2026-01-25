import SwiftUI

/// Navigation destinations for the main menu
enum MenuDestination: Hashable {
    case collections
    case venues
    case trails
}

/// Root view of the app with Map as the main view
struct Home: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingSettings = false
    @State private var hasMigrated = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MapContainerView(navigationPath: $navigationPath)
                .navigationDestination(for: MenuDestination.self) { destination in
                    switch destination {
                    case .collections:
                        CollectionListView()
                    case .venues:
                        VenueListView()
                    case .trails:
                        TrailListView()
                    }
                }
                .navigationDestination(for: Collection.self) { collection in
                    CollectionDetailView(collection: collection)
                }
                .navigationDestination(for: Venue.self) { venue in
                    VenueDetailView(venue: venue)
                }
                .navigationDestination(for: Trail.self) { trail in
                    TrailDetailView(trail: trail)
                }
                .navigationDestination(for: TrailNavigation.self) { navigation in
                    switch navigation {
                    case .trail(let trail):
                        TrailDetailView(trail: trail)
                    case .collection(let collection):
                        CollectionDetailView(collection: collection)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {
//                        Menu {
                            Button(action: { navigationPath.append(MenuDestination.collections) }) {
                                Label("Collections", systemImage: "folder")
                            }

                            Button(action: { navigationPath.append(MenuDestination.venues) }) {
                                Label("Venues", systemImage: "mappin.circle")
                            }

                            Button(action: { navigationPath.append(MenuDestination.trails) }) {
                                Label("Trails", systemImage: "figure.walk")
                            }
//                        } label: {
//                            Image(systemName: "ellipsis.circle")
//                        }
                    }
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            // Run data migration once on app launch
            if !hasMigrated {
                let dataService = DataService(modelContext: modelContext)
                dataService.migrateCollectionCachedCounts()
                hasMigrated = true
            }
        }
    }
}
