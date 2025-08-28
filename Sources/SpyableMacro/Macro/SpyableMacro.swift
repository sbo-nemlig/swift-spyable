import SwiftSyntax
import SwiftSyntaxMacros

public enum SpyableMacro: PeerMacro {
  private static let extractor = Extractor()
  private static let spyFactory = SpyFactory()

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Extract the protocol declaration
    let protocolDeclaration = try extractor.extractProtocolDeclaration(from: declaration)

    // Extract inherited types from the attribute
    let inheritedTypes = extractor.extractInheritedTypesArray(from: node, in: context)
    
    // For inherited spy classes, we need to look them up in the source file
    // Since Swift macros can't directly access other declarations, we'll implement
    // a different approach: extract protocol names from inheritedTypes that end with "Spy"
    // and find their corresponding protocols in the current file
    var inheritedProtocols: [ProtocolDeclSyntax] = []
    
    if let inheritedTypes = inheritedTypes {
      inheritedProtocols = try extractInheritedProtocols(
        from: inheritedTypes,
        in: context,
        currentDeclaration: declaration
      )
    }

    // Generate the initial spy class declaration with inherited types and protocols
    var spyClassDeclaration = try spyFactory.classDeclaration(
      for: protocolDeclaration,
      inheritedTypes: inheritedTypes,
      inheritedProtocols: inheritedProtocols
    )

    // Apply access level modifiers if needed
    if let accessLevel = determineAccessLevel(
      for: node, protocolDeclaration: protocolDeclaration, context: context)
    {
      spyClassDeclaration = rewriteSpyClass(spyClassDeclaration, withAccessLevel: accessLevel)
    }

    // Handle preprocessor flag
    if let preprocessorFlag = extractor.extractPreprocessorFlag(from: node, in: context) {
      return [wrapInIfConfig(spyClassDeclaration, withFlag: preprocessorFlag)]
    }

    return [DeclSyntax(spyClassDeclaration)]
  }
  
  /// Extracts protocol declarations corresponding to inherited spy classes.
  /// For example, if inheritedTypes contains "TestSpy", this will try to find "Test" protocol.
  /// This builds the complete inheritance chain by recursively finding all inherited protocols.
  private static func extractInheritedProtocols(
    from inheritedTypes: [String],
    in context: some MacroExpansionContext,
    currentDeclaration: some DeclSyntaxProtocol
  ) throws -> [ProtocolDeclSyntax] {
    var protocols: [ProtocolDeclSyntax] = []
    var visited: Set<String> = [] // Prevent infinite recursion
    
    // Get the source file containing the current declaration  
    guard let sourceFile = currentDeclaration.root.as(SourceFileSyntax.self) else {
      return protocols
    }
    
    // Recursively collect all protocols in the inheritance chain
    func collectProtocols(from spyNames: [String]) {
      for spyName in spyNames {
        // Skip if already processed
        if visited.contains(spyName) {
          continue
        }
        visited.insert(spyName)
        
        // If the inherited type ends with "Spy", try to find the corresponding protocol
        if spyName.hasSuffix("Spy") {
          let protocolName = String(spyName.dropLast(3)) // Remove "Spy" suffix
          
          // Search for the protocol in the source file using visitor pattern
          let protocolFinder = ProtocolFinder(targetName: protocolName)
          protocolFinder.walk(sourceFile)
          
          if let foundProtocol = protocolFinder.foundProtocol {
            protocols.append(foundProtocol)
          }
        }
      }
    }
    
    collectProtocols(from: inheritedTypes)
    return protocols
  }
}

/// Helper visitor to find protocol declarations by name
private class ProtocolFinder: SyntaxVisitor {
  let targetName: String
  var foundProtocol: ProtocolDeclSyntax?
  
  init(targetName: String) {
    self.targetName = targetName
    super.init(viewMode: .sourceAccurate)
  }
  
  override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
    if node.name.text == targetName && foundProtocol == nil {
      foundProtocol = node
      return .skipChildren  // Found it, no need to continue in this subtree
    }
    return .visitChildren
  }
}

extension SpyableMacro {
  /// Determines the access level to use for the spy class.
  private static func determineAccessLevel(
    for node: AttributeSyntax,
    protocolDeclaration: ProtocolDeclSyntax,
    context: MacroExpansionContext
  ) -> DeclModifierSyntax? {
    if let accessLevelFromNode = extractor.extractAccessLevel(from: node, in: context) {
      return accessLevelFromNode
    } else {
      return extractor.extractAccessLevel(from: protocolDeclaration)
    }
  }

  /// Applies the specified access level to the spy class declaration.
  private static func rewriteSpyClass(
    _ spyClassDeclaration: DeclSyntaxProtocol,
    withAccessLevel accessLevel: DeclModifierSyntax
  ) -> ClassDeclSyntax {
    let rewriter = AccessLevelModifierRewriter(newAccessLevel: accessLevel)
    return rewriter.rewrite(spyClassDeclaration).cast(ClassDeclSyntax.self)
  }

  /// Wraps a declaration in an `#if` preprocessor directive.
  private static func wrapInIfConfig(
    _ spyClassDeclaration: ClassDeclSyntax,
    withFlag flag: String
  ) -> DeclSyntax {
    return DeclSyntax(
      IfConfigDeclSyntax(
        clauses: IfConfigClauseListSyntax {
          IfConfigClauseSyntax(
            poundKeyword: .poundIfToken(),
            condition: ExprSyntax(stringLiteral: flag),
            elements: .statements(
              CodeBlockItemListSyntax {
                DeclSyntax(spyClassDeclaration)
              }
            )
          )
        }
      )
    )
  }
}
