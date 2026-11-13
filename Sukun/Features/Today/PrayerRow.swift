import SukunKit
import SwiftUI

struct PrayerRow: View {
    let slot: PrayerSlot
    let isCurrent: Bool
    let isPast: Bool
    let formatter: PrayerTimeFormatter
    let notificationEnabled: Bool
    let onToggleNotification: ((Bool) -> Void)?
    /// "Suhoor ends" / "Iftar" under Fajr and Maghrib while Ramadan mode is active.
    var ramadanLabel: LocalizedStringKey? = nil
    /// Fajr only (iOS 26.1+): tapping the symbol opens the Fajr sheet instead of toggling the bell.
    var onOpenFajr: (() -> Void)? = nil
    /// Fajr only: the next alarm time ("04:59") while the alarm is set; shows an alarm symbol instead of the bell.
    var alarmTime: String? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            HStack(spacing: 12) {
                Image(systemName: slot.kind.symbolName)
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(isCurrent ? Palette.text : Palette.secondaryText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(slot.kind.localizedName)
                        .font(.system(.body, design: .rounded, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(textColor)
                    if let ramadanLabel {
                        Text(ramadanLabel)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
            }
            .opacity(fade)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            HStack(spacing: 12) {
                if let onOpenFajr {
                    Button(action: onOpenFajr) {
                        Group {
                            if let alarmTime {
                                VStack(spacing: 1) {
                                    Image(systemName: "alarm.fill").font(.footnote)
                                    Text(verbatim: alarmTime).font(.caption2.weight(.semibold).monospacedDigit())
                                }
                                .foregroundStyle(Palette.accentText)
                            } else {
                                Image(systemName: notificationEnabled ? "bell.fill" : "bell")
                                    .font(.footnote)
                                    .foregroundStyle(notificationEnabled ? Palette.accentText : Palette.secondaryText.opacity(0.35))
                                    .opacity(fade)
                            }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else if let onToggleNotification {
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
                    .opacity(fade)
                }
                // Fixed-width time column: "5:23 AM" and "11:58 AM" take the same space,
                // so the bells line up vertically.
                ZStack(alignment: .trailing) {
                    ForEach(formatter.widthSamples, id: \.self) { Text($0).hidden() }
                    Text(formatter.string(from: slot.date))
                }
                .font(.sukunTime)
                .foregroundStyle(textColor)
                .opacity(fade)
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
        .animation(.sukun(reduceMotion: reduceMotion), value: isCurrent)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        // Voice Control: visible name, plain description and common spellings ("Show actions for Night prayer").
        .accessibilityInputLabels(slot.kind.voiceControlNames.map { Text(verbatim: $0) })
        .accessibilityValue(accessibilityValue)
        .modifier(ReminderAccessibility(enabled: notificationEnabled, toggle: onOpenFajr == nil ? onToggleNotification : nil))
        .modifier(FajrSheetAccessibility(open: onOpenFajr))
    }

    /// Past prayers fade back; with "Increase Contrast" they use readable grey instead (see textColor).
    /// A set Fajr alarm stays fully visible: it rings tomorrow, it isn't past.
    private var fade: Double { isPast && contrast != .increased ? 0.5 : 1 }

    private var accessibilityValue: Text {
        if let alarmTime { return Text("Alarm \(alarmTime)") }
        if onToggleNotification == nil && onOpenFajr == nil { return Text(verbatim: "") }
        return notificationEnabled ? Text("Notification on") : Text("Notification off")
    }

    /// With "Increase Contrast" past prayers recede in color (readable grey) instead of fading.
    private var textColor: Color { isPast && contrast == .increased ? Palette.secondaryText : Palette.text }

    private var accessibilityText: Text {
        let time = formatter.string(from: slot.date)
        if isCurrent { return Text("\(slot.kind.localizedName), \(time), current prayer") }
        return Text("\(slot.kind.localizedName), \(time)")
    }
}

/// The bell stays inside the row's single VoiceOver element. Rows with a bell read as a switch: a double tap
/// toggles the reminder, and the same choice sits in the Actions rotor (and Voice Control's "Show actions").
/// Sunrise has no bell, so it gets neither.
private struct ReminderAccessibility: ViewModifier {
    let enabled: Bool
    let toggle: ((Bool) -> Void)?

    func body(content: Content) -> some View {
        if let toggle {
            content
                .accessibilityAddTraits(.isToggle)
                .accessibilityAction { toggle(!enabled) }
                .accessibilityAction(named: enabled ? Text("Turn notification off") : Text("Turn notification on")) {
                    toggle(!enabled)
                }
        } else {
            content
        }
    }
}

/// Fajr with the alarm available: the row is a button that opens the Fajr sheet (off / notification / alarm).
private struct FajrSheetAccessibility: ViewModifier {
    let open: (() -> Void)?

    func body(content: Content) -> some View {
        if let open {
            content
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { open() }
                .accessibilityAction(named: Text("Set alarm")) { open() }
        } else {
            content
        }
    }
}
