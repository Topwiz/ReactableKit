import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum DependencyMacroError: Error, CustomStringConvertible {
    case notAVariable
    case notASingleBinding
    case missingTypeAnnotation
    case hasInitializer
    case hasAccessors
    case missingKeyPathArgument

    var description: String {
        switch self {
        case .notAVariable:
            return "@Dependency can only be applied to a property"
        case .notASingleBinding:
            return "@Dependency requires exactly one property per declaration"
        case .missingTypeAnnotation:
            return "@Dependency requires an explicit type annotation"
        case .hasInitializer:
            return "@Dependency cannot be applied to a property with an initial value"
        case .hasAccessors:
            return "@Dependency cannot be applied to a computed property"
        case .missingKeyPathArgument:
            return "@Dependency requires a key path argument, e.g. @Dependency(\\.service)"
        }
    }
}

private struct DependencyDeclaration {
    let identifier: TokenSyntax
    let type: TypeSyntax
    let keyPath: ExprSyntax
    let modifiers: DeclModifierListSyntax

    var storageName: TokenSyntax {
        TokenSyntax.identifier("_\(identifier.text)Storage")
    }
}

private func parse(
    _ node: AttributeSyntax,
    _ declaration: some DeclSyntaxProtocol
) throws -> DependencyDeclaration {
    guard let variable = declaration.as(VariableDeclSyntax.self) else {
        throw DependencyMacroError.notAVariable
    }
    guard variable.bindings.count == 1, let binding = variable.bindings.first else {
        throw DependencyMacroError.notASingleBinding
    }
    guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
        throw DependencyMacroError.notAVariable
    }
    guard let type = binding.typeAnnotation?.type else {
        throw DependencyMacroError.missingTypeAnnotation
    }
    guard binding.initializer == nil else {
        throw DependencyMacroError.hasInitializer
    }
    guard binding.accessorBlock == nil else {
        throw DependencyMacroError.hasAccessors
    }
    guard
        let arguments = node.arguments?.as(LabeledExprListSyntax.self),
        let keyPath = arguments.first?.expression
    else {
        throw DependencyMacroError.missingKeyPathArgument
    }
    return DependencyDeclaration(
        identifier: identifier,
        type: type.trimmed,
        keyPath: keyPath.trimmed,
        modifiers: variable.modifiers
    )
}

public struct DependencyMacro: PeerMacro, AccessorMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let parsed = try parse(node, declaration)
        return [
            """
            private let \(parsed.storageName) = DependencyStorage<\(parsed.type)>(\(parsed.keyPath))
            """
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let parsed = try parse(node, declaration)
        return [
            """
            get { \(parsed.storageName).value }
            """
        ]
    }
}

@main
struct DependencyInjectablePlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [DependencyMacro.self]
}
