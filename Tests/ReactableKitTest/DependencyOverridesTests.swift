//
//  DependencyOverridesTests.swift
//  ReactableKit
//

import Foundation
import Testing
@testable import DependencyInjectableKit

private protocol NameProviding: Sendable {
    var name: String { get }
}

private struct NameProvider: NameProviding {
    let name: String
}

extension NameProvider: DependencyInjectable {
    static var real: NameProviding { NameProvider(name: "real") }
    static var preview: NameProviding { NameProvider(name: "real") }
    static var test: NameProviding { NameProvider(name: "real") }
}

private struct OtherNameProvider: DependencyInjectable {
    static var real: NameProviding { NameProvider(name: "other") }
    static var preview: NameProviding { NameProvider(name: "other") }
    static var test: NameProviding { NameProvider(name: "other") }
}

@MainActor
private final class MainActorNameProvider: MainActorDependencyInjectable {
    let name: String
    init(name: String) { self.name = name }
    static var real: MainActorNameProvider { MainActorNameProvider(name: "real") }
}

extension GlobalDependencyKey {
    fileprivate var nameProvider: NameProviding { self[NameProvider.self] }
    fileprivate var otherNameProvider: NameProviding { self[OtherNameProvider.self] }
    @MainActor fileprivate var mainActorNameProvider: MainActorNameProvider { self[MainActorNameProvider.self] }
}

private final class Owner {
    @Dependency(\.nameProvider) var provider
}

struct DependencyOverridesTests {
    @Test
    func withoutOverride_resolvesEnvironmentValue() {
        #expect(GlobalDependencyKey().nameProvider.name == "real")
    }

    @Test
    func override_appliesInsideScopeOnly() {
        withDependencies {
            $0[NameProvider.self] = NameProvider(name: "mock")
        } operation: {
            @Dependency(\.nameProvider) var provider
            #expect(provider.name == "mock")
            #expect(GlobalDependencyKey().nameProvider.name == "mock")
        }
        #expect(GlobalDependencyKey().nameProvider.name == "real")
    }

    @Test
    func override_leavesOtherDependenciesUntouched() {
        withDependencies {
            $0[NameProvider.self] = NameProvider(name: "mock")
        } operation: {
            #expect(GlobalDependencyKey().otherNameProvider.name == "other")
        }
    }

    @Test
    func dependencyResolvedInsideScope_keepsValueAfterScope() {
        let owner = withDependencies {
            $0[NameProvider.self] = NameProvider(name: "mock")
        } operation: {
            Owner()
        }
        #expect(owner.provider.name == "mock")
    }

    @Test
    func nestedScope_inheritsAndReplacesOuterOverrides() {
        withDependencies {
            $0[NameProvider.self] = NameProvider(name: "outer")
            $0[OtherNameProvider.self] = NameProvider(name: "outer-other")
        } operation: {
            withDependencies {
                $0[NameProvider.self] = NameProvider(name: "inner")
            } operation: {
                #expect(GlobalDependencyKey().nameProvider.name == "inner")
                #expect(GlobalDependencyKey().otherNameProvider.name == "outer-other")
            }
            #expect(GlobalDependencyKey().nameProvider.name == "outer")
        }
    }

    @Test
    func settingNil_removesOverride() {
        withDependencies {
            $0[NameProvider.self] = NameProvider(name: "outer")
        } operation: {
            withDependencies {
                $0[NameProvider.self] = nil
            } operation: {
                #expect(GlobalDependencyKey().nameProvider.name == "real")
            }
        }
    }

    @Test
    func asyncScope_propagatesAcrossSuspensionAndChildTasks() async {
        await withDependencies {
            $0[NameProvider.self] = NameProvider(name: "mock")
        } operation: {
            await Task.yield()
            #expect(GlobalDependencyKey().nameProvider.name == "mock")

            async let childName = GlobalDependencyKey().nameProvider.name
            #expect(await childName == "mock")

            let unstructuredName = await Task { GlobalDependencyKey().nameProvider.name }.value
            #expect(unstructuredName == "mock")

            let detachedName = await Task.detached { GlobalDependencyKey().nameProvider.name }.value
            #expect(detachedName == "real")
        }
    }

    @Test
    func concurrentScopes_doNotSeeEachOthersOverrides() async {
        let names = await withTaskGroup(of: (Int, [String]).self) { group in
            for index in 0..<20 {
                group.addTask {
                    await withDependencies {
                        $0[NameProvider.self] = NameProvider(name: "mock-\(index)")
                    } operation: {
                        var seen: [String] = []
                        for _ in 0..<10 {
                            await Task.yield()
                            seen.append(GlobalDependencyKey().nameProvider.name)
                        }
                        return (index, seen)
                    }
                }
            }
            return await group.reduce(into: [Int: [String]]()) { $0[$1.0] = $1.1 }
        }
        for (index, seen) in names {
            #expect(seen.allSatisfy { $0 == "mock-\(index)" })
        }
    }

    @Test @MainActor
    func mainActorDependency_isOverridden() async {
        await withDependencies {
            $0[MainActorNameProvider.self] = MainActorNameProvider(name: "mock")
        } operation: {
            await Task.yield()
            MainActor.assertIsolated()
            @Dependency(\.mainActorNameProvider) var provider
            #expect(provider.name == "mock")
        }
        #expect(GlobalDependencyKey().mainActorNameProvider.name == "real")
    }
}
