# VerificationThroughput — Demo App

**Move one slider and watch a CI pipeline get slower and more expensive at the same time.**

A SwiftUI console for [`verification-throughput-kit`][lib]. Pick a change set, and the
app shows — live, on one screen — which test bundles that change can actually break, how
they pack into shards, what the run costs, and whether the merge queue will even let it
in right now.

The three numbers it puts together are, in most teams, in three different places: the
shard count is in a YAML file, the spend is in a billing dashboard, and the merge-queue
wait is in somebody's head. That separation is exactly why nobody notices when raising
the shard count made the pipeline *worse*.

---

## Why this matters

Linear's write-up of what agent-authored PRs did to their CI is the clearest statement
of the problem: test suites almost quadrupled since January, and the fix rested on driving the
fixed cost per shard down and *then* doubling the shard count.
([Linear][linear] · [HN][hn])

On iOS that lever doesn't exist. The per-shard fixed cost is simulator boot plus code
signing plus toolchain warm-up — minutes, not seconds — and the runner pool is finite,
so shards beyond its width queue into a second wave and re-pay the boot tax.

Drag the **shard count** off "choose from the curve" and you can watch it happen. On the
screen the app opens with — a shared networking change, six impacted bundles, four
concurrent runners:

| Shards | Makespan | Billed runner-time | Cost |
|---|---|---|---|
| 3 | 10m 30s | 31m 10s | $2.04 |
| **4** | **9m 40s** | 34m 10s | $2.23 |
| 5 | 13m 20s | 37m 10s | $2.41 |
| 6 | 12m 40s | 40m 10s | $2.66 |

Four is the floor. Five is **38% slower and 8% dearer** than four — for the privilege of
holding an extra runner. The green bar in the curve panel marks the floor; every bar to
its right is a runner you paid for that made the run worse.

*(The library's own unit test uses a cleaner case — eight equal bundles, where four
shards → eight is exactly 60% slower and 60% dearer. This app uses an uneven, more
realistic spread, so the numbers differ; both are recomputed live from the same code.)*

---

## What you can do in it

The app opens on the **impacted** tier, not `full` — at `full` the change-set picker
would change nothing, because the full tier runs everything regardless.

| Control | What moves |
|---|---|
| **Change set** | Six scenarios. The change-impact panel shows how many bundles each selects, and the cost tracks it: shared networking change 6 bundles / $2.23, design-token tweak 4 / $1.79, narrow feature edit 2 / $0.99, leaf module only 2 / $0.86, docs 0 / $0.00 — and `fastlane/Fastfile` all 8 / $2.60, with an explicit note that the plan could not be narrowed because no target owns that path. |
| **Tier** | `full` / `impacted` / `smoke`. The smoke tier never runs empty, because a green that tested nothing is the worst output the system can produce. |
| **Job class** | `speculative` / `pull-request` / `merge-queue`. Only merge-queue traffic reaches the reserved capacity. |
| **Shard count** | Take it off automatic and push it past the pool width to see the makespan curve turn back up (table above). |
| **Budget pressure** | Slide it and the admission decision walks `full` → `impacted` → `smoke` → deferred. It opens on a degrade at 40%. |

The **contract panel** is the half of this that only matters now that agents write most
of the tests. Sharding is not merely *helped* by isolated tests — it is invalid without
them, and the failure shows up as flakiness rather than as a bug. The fixture declares
twelve tests, six of which violate the contract: five blocking, one advisory, and two
bundles pinned onto a single shard because they touch shared mutable state. They are
pinned, not dropped — refusing to run them would be the worse failure.

One detail worth noticing: the same hazard (a test that reaches the real network)
appears twice in the fixture, once agent-authored and once human-authored, and the panel
shows them at **different severities**. That is the package's most arguable design
decision, made visible rather than buried — the reasoning and its costs are in the
[library README][lib].

## Screenshots

**There are none, and this section exists to say so rather than to quietly omit it.**

This repository was authored in an automated session that was refused the desktop access
needed to launch a Simulator. The refusal, verbatim:

> Computer-use access to "Xcode 26.3", "Simulator" can't be approved during a scheduled
> run. To grant it, send a message in this conversation (the approval card will appear),
> or add the app to the scheduled task's settings. (Retrying returns this same result.)

Three attempts were made, including one narrowed to Simulator alone. All three were
refused. No `Demo/Screenshots/` directory exists, and no image in this README describes
a screen nobody saw.

## Verification — what actually happened

Stated precisely, because "builds" and "ran" are different claims and only one of them
is true here:

- **CI compiles the app for an iOS Simulator destination against the package resolved
  from GitHub.** The `macos-15` job runs `xcodebuild -resolvePackageDependencies`, prints
  the resulting `Package.resolved` so the resolved version is visible in the log, then
  `xcodebuild build -destination 'generic/platform=iOS Simulator'`. That is what proves
  the remote dependency genuinely resolves and the app links against it.
  → **[Actions tab](../../actions)** for the live result on the current commit.
- **The library's own CI is green on two jobs**: Linux (`swift:6.0`, warnings-as-errors
  on both the build and the test build) and `macos-15` (`swift build` + `swift test`,
  which is what compiles the SwiftUI layer — the Linux job never sees it, since it sits
  behind `#if canImport(SwiftUI)`). 95 tests across 8 suites, 0 failures.
  → **[Library Actions tab](https://github.com/rajatslakhina/verification-throughput-kit/actions)**
- **The app was never launched on a Simulator.** Not by CI — a compile check boots no
  device — and not by hand. Nobody has seen this UI render.
- **The console's numbers were verified by execution, not by reading.** Every figure in
  this README was produced by running the fixture in `DemoApp.swift` against the real
  library and printing the result, including the shard-count table above and the
  per-scenario bundle counts and costs.

`project.pbxproj` was written by hand and checked programmatically for balanced
braces/parens and for dangling object references before being committed (23 objects, all
24-hex-character ids, all defined, all referenced).

## How to run it

```bash
git clone https://github.com/rajatslakhina/verification-throughput-kit-demo-app.git
cd verification-throughput-kit-demo-app
open Demo.xcodeproj
```

Then in Xcode:

1. Wait for **Package Dependencies** to resolve — it fetches
   [`verification-throughput-kit`][lib] from GitHub. This is a genuine **remote**
   `XCRemoteSwiftPackageReference` against a *released version*, not a local path and
   not `branch = main`: an artifact that resolves whatever `main` happens to be that day
   is not reproducible.

   To be exact about what "version" means here, since it is the kind of thing that gets
   overstated: the requirement is `upToNextMajorVersion` from `1.1.0`, i.e. the range
   `1.1.0 ..< 2.0.0`. It resolves to `v1.1.0` today, and it will pick up a future `1.x`
   — which is the intended behaviour for a library dependency, but it is a *range*, not
   a lock. Commit `Package.resolved` if you want the stronger guarantee; the CI job
   prints the resolved version on every run, so the log always says which one was used.
2. Select the **Demo** scheme (committed as a shared scheme, so it is there on a fresh
   clone) and any iOS Simulator.
3. **⌘R**.

Requires Xcode 16 or later; the app targets iOS 17.

## Structure

```
Demo.xcodeproj/                     objectVersion 60, compatibilityVersion "Xcode 15.0"
  xcshareddata/xcschemes/Demo.xcscheme
Demo/DemoApp.swift                  @main + the entire fixture
.github/workflows/ci.yml            macos-15: resolve + build for iOS Simulator
```

One file. `DemoApp.swift` owns the invented monorepo the console plans against — eight
modules, eight test bundles, plausible durations, a declared-test-metadata slice, and a
runner budget tight enough that admission control is a real decision. That fixture lives
here and not in the library on purpose: `verification-throughput-kit` ships no sample
repository, so nothing it renders can be mistaken for a measurement it took.

Every duration and runner rate in this app is invented. They are the right *shape* — a
`Networking` module everything depends on, a `Checkout` bundle carrying most of the test
time — but they are not a measurement of any real codebase, and the cost model's rates
are placeholders, not a price quote.

## Licence

MIT. See [LICENSE](LICENSE).

[lib]: https://github.com/rajatslakhina/verification-throughput-kit
[linear]: https://linear.app/now/ci-bottleneck-reworked
[hn]: https://news.ycombinator.com/item?id=49792067
