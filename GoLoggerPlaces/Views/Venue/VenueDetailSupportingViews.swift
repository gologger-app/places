import SwiftUI

// MARK: - Supporting Views

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.body)
            }

            Spacer()
        }
    }
}

struct WeatherInfoCell: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.caption)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(8)
        .background(.thinMaterial)
        .cornerRadius(8)
    }
}

struct SunTimeRow: View {
    let icon: String
    let label: String
    let time: String
    var isSubtle: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isSubtle ? .secondary : .orange)
                .font(isSubtle ? .caption : .subheadline)
                .frame(width: 20)

            Text(label)
                .font(isSubtle ? .caption : .subheadline)
                .foregroundColor(isSubtle ? .secondary : .primary)

            Spacer()

            Text(time)
                .font(isSubtle ? .caption : .subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSubtle ? .secondary : .primary)
        }
    }
}
