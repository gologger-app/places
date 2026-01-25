//
//  LinkFormView.swift
//  GoLoggerPlaces
//
//  Created on 2025-11-22.
//

import SwiftUI
import SwiftData

struct LinkFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let link: Link?
    let onSave: (Link) -> Void

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var showValidationError: Bool = false

    init(link: Link? = nil, onSave: @escaping (Link) -> Void) {
        self.link = link
        self.onSave = onSave

        if let link = link {
            _name = State(initialValue: link.name ?? "")
            _url = State(initialValue: link.url ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (optional)", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onChange(of: url) { _, newValue in
                            autoFillNameIfNeeded()
                        }
                } header: {
                    Text("Link Information")
                }

                if !url.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: isValidURL ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isValidURL ? Color.green : Color.red)
                            Text(isValidURL ? "Valid URL" : "Invalid URL format")
                                .foregroundStyle(isValidURL ? Color.secondary : Color.red)
                        }
                    }
                }

                if isValidURL {
                    Section {
                        Button {
                            if let validURL = URL(string: url) {
                                UIApplication.shared.open(validURL)
                            }
                        } label: {
                            Label("Test Link", systemImage: "arrow.up.forward.app")
                        }
                    }
                }
            }
            .navigationTitle(link == nil ? "Add Link" : "Edit Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLink()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Invalid URL", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid URL before saving.")
            }
        }
    }

    private var isValidURL: Bool {
        guard !url.isEmpty else { return false }
        guard let urlObject = URL(string: url) else { return false }
        return urlObject.scheme != nil
    }

    private var canSave: Bool {
        // Can save if URL is empty (will be validated on save) or if it's valid
        // At least one field should have content
        return !url.trimmingCharacters(in: .whitespaces).isEmpty || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var schemeAndHost: String? {
        guard let urlObject = URL(string: url),
              let host = urlObject.host() else { return nil }

        // Return scheme + host (e.g., "https://github.com", "http://example.com")
        if let scheme = urlObject.scheme {
            return "\(scheme)://\(host)"
        }
        return host
    }

    private func autoFillNameIfNeeded() {
        // Only auto-fill if name is empty
        guard name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        if let schemeHost = schemeAndHost {
            name = schemeHost
        }
    }

    private func saveLink() {
        let trimmedURL = url.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // If URL is not empty, it must be valid
        if !trimmedURL.isEmpty && !isValidURL {
            showValidationError = true
            return
        }

        if let existingLink = link {
            // Update existing link
            existingLink.name = trimmedName.isEmpty ? nil : trimmedName
            existingLink.url = trimmedURL.isEmpty ? nil : trimmedURL
            onSave(existingLink)
        } else {
            // Create new link
            let newLink = Link(
                name: trimmedName.isEmpty ? nil : trimmedName,
                url: trimmedURL.isEmpty ? nil : trimmedURL
            )
            onSave(newLink)
        }

        dismiss()
    }
}

#Preview("New Link") {
    LinkFormView { _ in }
        .modelContainer(for: [Link.self], inMemory: true)
}

#Preview("Edit Link") {
    let link = Link(name: "Official Website", url: "https://example.com")
    return LinkFormView(link: link) { _ in }
        .modelContainer(for: [Link.self], inMemory: true)
}
