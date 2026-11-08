import SukunKit
import SwiftUI

struct PrayerRow: View {
    let slot: PrayerSlot
    let isCurrent: Bool
    let isPast: Bool
    let formatter: PrayerTimeFormatter
    let notificationEnabled: Bool
    let onToggleNotification: ((Bool) -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            HStack(spacing: 12) {
                Image(systemName: slot.kind.symbolName)
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(isCurrent ? Palette.accentText : Palette.secondaryText)
                    .accessibilityHidden(true)
                Text(slot.kind.localizedName)
                    .font(.system(.body, design: .rounded, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Palette.accentText : Palette.text)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            HStack(spacing: 12) {
                if let onToggleNotification {
                    Button {
                        onToggleNotification(!notificationEnabled)
                    } label: {
                        // Quiet when off (a faint outline), clear when on.
                        Image(systemName: notificationEnabled ? "bell.fill" : "bell")
                            .font(.footnote)
                            .foregroundStyle(notificationEnabled ? Palette.accentText : Palette.secondaryText.opacity(0.35))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: notificationEnabled)
                }
                Text(formatter.string(from: slot.date))
                    .font(.sukunTime)
                    .foregroundStyle(Palette.text)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.highlight)
            }
        }
        .opacity(isPast ? 0.5 : 1)
        .animation(.sukun(reduceMotion: reduceMotion), value: isCurrent)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(onToggleNotification == nil ? Text(verbatim: "") : (notificationEnabled ? Text("Notification on") : Text("Notification off")))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityAction(named: notificationEnabled ? Text("Turn notification off") : Text("Turn notification on")) {
            onToggleNotification?(!notificationEnabled)
        }
    }

    private var accessibilityText: Text {
        let time = formatter.string(from: slot.date)
        if isCurrent { return Text("\(slot.kind.localizedName), \(time), current prayer") }
        return Text("\(slot.kind.localizedName), \(time)")
    }
}
