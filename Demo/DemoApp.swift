import SwiftUI
import VerificationThroughput
import VerificationThroughputUI

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            VerificationConsoleView(workspace: DemoWorkspace.make())
        }
    }
}

/// The fixture the console plans against.
///
/// This lives in the **app**, not the library, and that is deliberate.
/// `VerificationThroughput` ships no sample repository of its own, so nothing it
/// renders can be mistaken for a measurement it took. Everything below is an
/// invented mid-size iOS monorepo: eight feature modules, eight test bundles,
/// plausible durations, and a runner budget tight enough that the admission
/// controller has something to decide.
///
/// The shape is real even though the numbers are not. A `Networking` module
/// everything depends on, a `Checkout` module that carries most of the test
/// time, and a UI bundle that carries the rest — that is what these graphs look
/// like, and it is why change-impact selection pays for itself.
enum DemoWorkspace {

    // MARK: - Targets

    private enum Module {
        static let designSystem = TargetID("DesignSystem")
        static let networking = TargetID("Networking")
        static let persistence = TargetID("Persistence")
        static let analytics = TargetID("Analytics")
        static let checkout = TargetID("Checkout")
        static let search = TargetID("Search")
        static let account = TargetID("Account")
        static let app = TargetID("App")
    }

    private enum Bundle {
        static let designSystem = TargetID("DesignSystemTests")
        static let networking = TargetID("NetworkingTests")
        static let persistence = TargetID("PersistenceTests")
        static let analytics = TargetID("AnalyticsTests")
        static let checkout = TargetID("CheckoutTests")
        static let search = TargetID("SearchTests")
        static let account = TargetID("AccountTests")
        static let appUI = TargetID("AppUITests")
    }

    static func make() -> VerificationWorkspace {
        VerificationWorkspace(
            graph: graph,
            profiles: profiles,
            tests: tests,
            policy: policy,
            admissionPolicy: admissionPolicy,
            scenarios: scenarios
        )
    }

    // MARK: - Build graph

    private static var graph: BuildGraph {
        BuildGraph(targets: [
            BuildTarget(
                id: Module.designSystem, kind: .library,
                sourceRoots: ["Sources/DesignSystem"]
            ),
            BuildTarget(
                id: Module.networking, kind: .library,
                sourceRoots: ["Sources/Networking"]
            ),
            BuildTarget(
                id: Module.persistence, kind: .library,
                sourceRoots: ["Sources/Persistence"]
            ),
            BuildTarget(
                id: Module.analytics, kind: .library,
                sourceRoots: ["Sources/Analytics"],
                dependencies: [Module.networking]
            ),
            BuildTarget(
                id: Module.checkout, kind: .library,
                sourceRoots: ["Sources/Checkout"],
                dependencies: [Module.networking, Module.persistence, Module.designSystem]
            ),
            BuildTarget(
                id: Module.search, kind: .library,
                sourceRoots: ["Sources/Search"],
                dependencies: [Module.networking, Module.designSystem]
            ),
            BuildTarget(
                id: Module.account, kind: .library,
                sourceRoots: ["Sources/Account"],
                dependencies: [Module.networking, Module.persistence]
            ),
            BuildTarget(
                id: Module.app, kind: .application,
                sourceRoots: ["Sources/App"],
                dependencies: [
                    Module.checkout, Module.search, Module.account,
                    Module.analytics, Module.designSystem
                ]
            ),

            BuildTarget(
                id: Bundle.designSystem, kind: .testBundle,
                sourceRoots: ["Tests/DesignSystemTests"],
                dependencies: [Module.designSystem]
            ),
            BuildTarget(
                id: Bundle.networking, kind: .testBundle,
                sourceRoots: ["Tests/NetworkingTests"],
                dependencies: [Module.networking]
            ),
            BuildTarget(
                id: Bundle.persistence, kind: .testBundle,
                sourceRoots: ["Tests/PersistenceTests"],
                dependencies: [Module.persistence]
            ),
            BuildTarget(
                id: Bundle.analytics, kind: .testBundle,
                sourceRoots: ["Tests/AnalyticsTests"],
                dependencies: [Module.analytics]
            ),
            BuildTarget(
                id: Bundle.checkout, kind: .testBundle,
                sourceRoots: ["Tests/CheckoutTests"],
                dependencies: [Module.checkout]
            ),
            BuildTarget(
                id: Bundle.search, kind: .testBundle,
                sourceRoots: ["Tests/SearchTests"],
                dependencies: [Module.search]
            ),
            BuildTarget(
                id: Bundle.account, kind: .testBundle,
                sourceRoots: ["Tests/AccountTests"],
                dependencies: [Module.account]
            ),
            BuildTarget(
                id: Bundle.appUI, kind: .testBundle,
                sourceRoots: ["Tests/AppUITests"],
                dependencies: [Module.app]
            )
        ])
    }

    // MARK: - Historical durations (p95, excluding per-shard fixed cost)

    /// Durations are deliberately within about 1.75× of each other.
    ///
    /// A fixture with one dominant bundle is easy to write and useless to look
    /// at: that bundle sets the makespan at every shard count above one, the
    /// curve goes flat, and the console cannot demonstrate the trade-off it
    /// exists to show. Real monorepos that have already done the obvious work
    /// look like this — a spread, not a cliff — and a spread is where the
    /// shard-count decision is actually interesting.
    private static var profiles: [TestTargetProfile] {
        [
            TestTargetProfile(id: Bundle.designSystem, historicalDuration: 180_000, testCount: 214),
            TestTargetProfile(id: Bundle.networking, historicalDuration: 200_000, testCount: 308),
            TestTargetProfile(id: Bundle.persistence, historicalDuration: 220_000, testCount: 176),
            TestTargetProfile(id: Bundle.analytics, historicalDuration: 160_000, testCount: 88),
            TestTargetProfile(id: Bundle.checkout, historicalDuration: 260_000, testCount: 512),
            TestTargetProfile(id: Bundle.search, historicalDuration: 240_000, testCount: 190),
            TestTargetProfile(id: Bundle.account, historicalDuration: 190_000, testCount: 143),
            TestTargetProfile(id: Bundle.appUI, historicalDuration: 280_000, testCount: 64)
        ]
    }

    // MARK: - Declared test metadata

    /// A representative slice, not the whole suite. Five blocking violations
    /// and one advisory, chosen so the console shows every branch of the
    /// contract: a hazard that pinning fixes, hazards it cannot fix, and the
    /// authorship rule producing two different severities for the same hazard.
    private static var tests: [TestCaseDescriptor] {
        let agent = Authorship.agent(model: "in-house-coding-agent")
        return [
            // Clean, human.
            TestCaseDescriptor(
                identifier: "DesignSystemTests.testTokenContrast",
                targetID: Bundle.designSystem, declaredTimeout: 2_000
            ),
            TestCaseDescriptor(
                identifier: "AnalyticsTests.testEventCoalescing",
                targetID: Bundle.analytics, declaredTimeout: 3_500
            ),

            // Clean, agent-authored — the contract is not hostile to agents,
            // only to undeclared hazards.
            TestCaseDescriptor(
                identifier: "NetworkingTests.testRetryBackoffCeiling",
                targetID: Bundle.networking, declaredTimeout: 6_000, authorship: agent
            ),
            TestCaseDescriptor(
                identifier: "NetworkingTests.test429IsNotRetriedImmediately",
                targetID: Bundle.networking, declaredTimeout: 4_000, authorship: agent
            ),
            TestCaseDescriptor(
                identifier: "PersistenceTests.testMigrationIsIdempotent",
                targetID: Bundle.persistence, declaredTimeout: 12_000, authorship: agent
            ),
            TestCaseDescriptor(
                identifier: "CheckoutTests.testTaxRounding",
                targetID: Bundle.checkout, declaredTimeout: 1_500, authorship: agent
            ),

            // Blocking: shared mutable state. Pinning fixes this, so the
            // owning bundles get co-located rather than rejected.
            //
            // These sit on two of the *smaller* bundles on purpose. Pinning
            // the two largest would fuse them into one item that dominates the
            // makespan at every shard count, flattening the curve and hiding
            // the shard-count trade-off behind a constraint. Here the
            // constraint is visible in the plan without swallowing it.
            TestCaseDescriptor(
                identifier: "AnalyticsTests.testSeedsSharedEventStore",
                targetID: Bundle.analytics, declaredTimeout: 8_000,
                touchesSharedMutableState: true, authorship: agent
            ),
            TestCaseDescriptor(
                identifier: "DesignSystemTests.testMutatesGlobalAppearanceProxy",
                targetID: Bundle.designSystem, declaredTimeout: 6_000,
                touchesSharedMutableState: true, authorship: agent
            ),

            // Blocking, but pinning does not help: a live network call and a
            // runtime past the ceiling are both real defects.
            TestCaseDescriptor(
                identifier: "PersistenceTests.testSyncsAgainstStagingBucket",
                targetID: Bundle.persistence, declaredTimeout: 20_000,
                usesRealNetwork: true, authorship: agent
            ),
            TestCaseDescriptor(
                identifier: "AppUITests.testFullPurchaseJourney",
                targetID: Bundle.appUI, declaredTimeout: 90_000, authorship: agent
            ),

            // Blocking: no declared ceiling, so the packer has nothing to pack.
            TestCaseDescriptor(
                identifier: "AccountTests.testPasswordResetJourney",
                targetID: Bundle.account, declaredTimeout: nil, authorship: agent
            ),

            // Advisory: the same hazard as the staging-bucket test above, but
            // a human wrote it and a reviewer signed it off.
            TestCaseDescriptor(
                identifier: "SearchTests.testRelevanceAgainstStagingIndex",
                targetID: Bundle.search, declaredTimeout: 25_000,
                usesRealNetwork: true, authorship: .human
            )
        ]
    }

    // MARK: - Policy

    private static var policy: VerificationPolicy {
        VerificationPolicy(
            // The pipeline is *allowed* to fan out to ten...
            maximumShards: 10,
            // ...but only four simulators can actually run at once, which is
            // what puts the floor in the curve. Raise this and watch the
            // optimum move right.
            concurrencyLimit: 4,
            // Three minutes of boot, signing and warm-up before the first
            // assertion. The number this whole package exists because of.
            fixedCostPerShard: 180_000,
            smokeTargetLimit: 1,
            contract: AgentTestContract(maximumTestRuntime: 45_000),
            runnerClass: .macOS,
            costModel: .illustrative
        )
    }

    private static var admissionPolicy: AdmissionPolicy {
        AdmissionPolicy(
            // Sixty runner-minutes an hour — roughly one and a bit full
            // verifications, which is exactly the squeeze that makes admission
            // control a real decision rather than a formality.
            budgetPerWindow: 3_600_000,
            windowLength: 3_600_000,
            bucketSize: 60_000,
            mergeQueueReserveBasisPoints: 2_500,
            agingThreshold: 2,
            retryBackoff: 60_000,
            maximumTrackedJobs: 4_096,
            minimumTier: .smoke
        )
    }

    // MARK: - Scenarios

    private static var scenarios: [VerificationScenario] {
        [
            // First, and therefore the default. Six impacted bundles is enough
            // for the shard-count curve to have a floor *and* a rise after it,
            // which is the thing worth opening on.
            VerificationScenario(
                id: "networking",
                title: "Shared networking change",
                detail: "Six of the eight bundles can observe this, so selection buys less — and the shard-count decision starts to matter. Turn off \"choose from the curve\" and push the stepper past four to watch the makespan climb back up.",
                changedPaths: ["Sources/Networking/HTTPClient.swift"]
            ),
            VerificationScenario(
                id: "checkout",
                title: "Agent PR — cart reducer",
                detail: "A narrow change inside one feature module. Selection reaches the module's own bundle and the UI bundle above it, and nothing else — two bundles instead of eight.",
                changedPaths: [
                    "Sources/Checkout/CartReducer.swift",
                    "Tests/CheckoutTests/CartReducerTests.swift"
                ]
            ),
            VerificationScenario(
                id: "design-system",
                title: "Design-token tweak",
                detail: "Three modules consume DesignSystem; Persistence and Analytics do not.",
                changedPaths: ["Sources/DesignSystem/ColourTokens.swift"]
            ),
            VerificationScenario(
                id: "analytics",
                title: "Leaf module only",
                detail: "The cheapest useful case: one leaf module and the UI bundle that sits above it.",
                changedPaths: ["Sources/Analytics/EventQueue.swift"]
            ),
            VerificationScenario(
                id: "unowned",
                title: "Unowned path — fastlane",
                detail: "No target claims this file, so the plan widens to the whole suite rather than guessing. Fail-safe, not fail-open.",
                changedPaths: ["fastlane/Fastfile"]
            ),
            VerificationScenario(
                id: "docs",
                title: "Documentation only",
                detail: "Inert paths neither select anything nor widen the plan. The smoke tier still runs something, because a green that tested nothing is the worst output this system can produce.",
                changedPaths: ["docs/adr/0012-shard-policy.md", "README.md"]
            )
        ]
    }
}
