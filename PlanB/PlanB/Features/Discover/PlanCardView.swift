import UIKit
import SwiftUI

/// The big card in the deck.
struct PlanCardView: View {
    let plan: Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(colors: plan.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(plan.emoji)
                    .font(.system(size: 84))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .frame(height: 170)
            .overlay(alignment: .topTrailing) {
                if plan.isCustom {
                    TagChip(text: "Vuestro", symbol: "pencil")
                        .padding(12)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(plan.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(plan.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                PlanTagsRow(plan: plan)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(.rect(cornerRadius: Metrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.radius)
                .strokeBorder(.white.opacity(0.12))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Budget · duration · place · mood.
struct PlanTagsRow: View {
    let plan: Plan

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                TagChip(text: plan.budget.label, symbol: "eurosign.circle.fill")
                TagChip(text: plan.duration.label, symbol: "clock.fill")
                TagChip(text: plan.place.label, symbol: plan.place.symbol)
                TagChip(text: plan.mood.label, symbol: plan.mood.symbol, tint: plan.colors.first)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(true)
    }
}
