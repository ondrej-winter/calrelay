import CryptoKit
import Foundation

public struct CalendarReconciliationPolicyVersion: Equatable, Sendable {
    /// Version 2 restricts ordinary hub deletion ownership to current work markers, preserving
    /// personal-prefix and other non-local valid marked hub events as authoritative sources. It
    /// retains exact-target, delete-first actions ordered by hub then declaration-ordered work
    /// roles within each phase. Review and increment this value whenever identical validated
    /// settings and snapshots can change executable actions, targets, or order; presentation-only
    /// changes do not require an increment.
    public static let current = CalendarReconciliationPolicyVersion(rawValue: "ordinary-reconciliation-policy-v2")

    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct CalendarStandingAuthorizationBinding: Equatable, Sendable, CustomStringConvertible,
    CustomDebugStringConvertible
{
    private static let representationVersion = "v1"
    private let persistedRepresentation: String

    public static func derive(
        settings: CalendarRelaySettings, resolvedCalendars: [PhysicalCalendarReference],
        policyVersion: CalendarReconciliationPolicyVersion
    ) -> CalendarStandingAuthorizationBinding {
        derive(
            configurationIdentity: OrdinaryConfigurationMutationIdentity(settings),
            topologyIdentity: ResolvedCalendarTopologyIdentity(resolvedCalendars), policyVersion: policyVersion)
    }

    static func derive(
        configurationIdentity: OrdinaryConfigurationMutationIdentity,
        topologyIdentity: ResolvedCalendarTopologyIdentity, policyVersion: CalendarReconciliationPolicyVersion
    ) -> CalendarStandingAuthorizationBinding {
        var input = LengthPrefixedIdentityInput()
        input.append(Self.representationVersion)
        for component in configurationIdentity.stableIdentityComponents { input.append(component) }
        input.append(policyVersion.rawValue)
        for component in topologyIdentity.stableIdentityComponents { input.append(component) }

        let digest = SHA256.hash(data: input.data).map { String(format: "%02x", $0) }.joined()
        return CalendarStandingAuthorizationBinding(validatedRepresentation: "\(Self.representationVersion):\(digest)")
    }

    private init(validatedRepresentation: String) { persistedRepresentation = validatedRepresentation }

    init?(persistedRepresentation: String) {
        let prefix = "\(Self.representationVersion):"
        guard persistedRepresentation.hasPrefix(prefix) else { return nil }
        let digest = persistedRepresentation.dropFirst(prefix.count)
        guard digest.count == 64, digest.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else { return nil }
        self.init(validatedRepresentation: persistedRepresentation)
    }

    var persistenceValue: String { persistedRepresentation }

    public var description: String { "<opaque-standing-authorization-binding>" }
    public var debugDescription: String { description }
}

struct ResolvedCalendarTopologyIdentity: Equatable, Sendable {
    private let calendars: [PhysicalCalendarReference]

    init(_ calendars: [PhysicalCalendarReference]) { self.calendars = calendars }

    var stableIdentityComponents: [String] {
        ["calendarCount", String(calendars.count)]
            + calendars.flatMap { ["calendar", $0.authorizationIdentityComponent] }
    }
}

struct CalendarStandingAuthorizationDryRun: Sendable {
    let result: OrdinaryReconciliationResult
    let topologyIdentity: ResolvedCalendarTopologyIdentity
}

private struct LengthPrefixedIdentityInput {
    private(set) var data = Data()

    mutating func append(_ value: Int) { append(String(value)) }

    mutating func append(_ value: String) {
        let bytes = Data(value.utf8)
        data.append(Data(String(bytes.count).utf8))
        data.append(0x3a)
        data.append(bytes)
    }
}
