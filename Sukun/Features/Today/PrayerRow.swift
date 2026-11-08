import SukunKit
import SwiftUI

struct PrayerRow: View {
    let slot: PrayerSlot
    let isNext: Bool
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
                    .foregroundStyle(isNext ? Palette.accentText : Palette.secondaryText)
                    .accessibilityHidden(true)
                Text(slot.kind.localizedName)
                    .smallCaps(color: isNext ? Palette.accentText : Palette.text)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            HStack(spacing: 12) {
                if let onToggleNotification {
                    Button {
                        onToggleNotification(!notificationEnabled)
                    } label: {
                        Image(systemName: notificationEnabled ? "bell.fill" : "bell.slash")
                            .font(.footnote)
                            .foregroundStyle(notificationEnabled ? Palette.accentText : Palette.secondaryText.opacity(0.6))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
            if isNext {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.highlight)
            }
        }
        .opacity(isPast && !isNext ? 0.5 : 1)
        .animation(.sukun(reduceMotion: reduceMotion), value: isNext)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(onToggleNotification == nil ? Text(verbatim: "") : (notificationEnabled ? Text("Notification on") : Text("Notification off")))
        .accessibilityAddTraits(isNext ? .isSelected : [])
        .accessibilityAction(named: notificationEnabled ? Text("Turn notification off") : Text("Turn notification on")) {
            onToggleNotification?(!notificationEnabled)
        }
    }

    private var accessibilityText: Text {
        let time = formatter.string(from: slot.date)
        if isNext { return Text("\(slot.kind.localizedName), \(time), next prayer") }
        return Text("\(slot.kind.localizedName), \(time)")
    }
}
