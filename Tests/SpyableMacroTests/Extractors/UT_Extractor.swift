import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics
import XCTest

@testable import SpyableMacro

final class UT_Extractor: XCTestCase {
  private var mockContext: MockMacroExpansionContext!
  
  override func setUp() {
    super.setUp()
    mockContext = MockMacroExpansionContext()
  }

  func testExtractProtocolDeclarationSuccessfully() throws {
    let declaration = DeclSyntax(
      """
      protocol Foo {}
      """
    )

    XCTAssertNoThrow(_ = try Extractor().extractProtocolDeclaration(from: declaration))
  }

  func test_extractProtocolDeclaration_fails() throws {
    var receivedError: Error?

    let declaration = DeclSyntax(
      """
      struct Foo {}
      """
    )

    XCTAssertThrowsError(_ = try Extractor().extractProtocolDeclaration(from: declaration)) {
      receivedError = $0
    }
    let unwrappedReceivedError = try XCTUnwrap(receivedError as? SpyableDiagnostic)
    XCTAssertEqual(unwrappedReceivedError, .onlyApplicableToProtocol)
  }

  // MARK: - extractInheritedTypesArray Tests
  
  func test_extractInheritedTypesArray_withValidStringLiteral_returnsArrayWithSingleValue() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable(inheritedTypes: "BaseClass")
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertEqual(result, ["BaseClass"])
    XCTAssertTrue(mockContext.diagnostics.isEmpty)
  }
  
  func test_extractInheritedTypesArray_withValidStringArray_returnsArray() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable(inheritedTypes: ["BaseClass", "Protocol"])
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertEqual(result, ["BaseClass", "Protocol"])
    XCTAssertTrue(mockContext.diagnostics.isEmpty)
  }
  
  func test_extractInheritedTypesArray_withEmptyArray_returnsEmptyArray() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable(inheritedTypes: [])
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertEqual(result, [])
    XCTAssertTrue(mockContext.diagnostics.isEmpty)
  }
  
  func test_extractInheritedTypesArray_withNoArguments_returnsNil() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertNil(result)
    XCTAssertTrue(mockContext.diagnostics.isEmpty)
  }
  
  func test_extractInheritedTypesArray_withMissingInheritedTypesArgument_returnsNil() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable(accessLevel: .public)
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertNil(result)
    XCTAssertTrue(mockContext.diagnostics.isEmpty)
  }
  
  func test_extractInheritedTypesArray_withNonStringLiteralInArray_returnsNilAndDiagnoses() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable(inheritedTypes: [someVariable])
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertNil(result)
    XCTAssertEqual(mockContext.diagnostics.count, 1)
    XCTAssertEqual(
      mockContext.diagnostics.first?.message,
      SpyableDiagnostic.inheritedTypesArgumentRequiresStaticStringArray.message
    )
  }
  
  func test_extractInheritedTypesArray_withNonStringArray_returnsNilAndDiagnoses() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable(inheritedTypes: someVariable)
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertNil(result)
    XCTAssertEqual(mockContext.diagnostics.count, 1)
    XCTAssertEqual(
      mockContext.diagnostics.first?.message,
      SpyableDiagnostic.inheritedTypesArgumentRequiresStaticStringArray.message
    )
  }
  
  func test_extractInheritedTypesArray_withEmptyString_returnsArrayWithEmptyString() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable(inheritedTypes: "")
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertEqual(result, [""])
    XCTAssertTrue(mockContext.diagnostics.isEmpty)
  }
  
  func test_extractInheritedTypesArray_withComplexClassName_returnsArrayWithValue() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable(inheritedTypes: "MyModule.BaseClass<T>")
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertEqual(result, ["MyModule.BaseClass<T>"])
    XCTAssertTrue(mockContext.diagnostics.isEmpty)
  }
  
  func test_extractInheritedTypesArray_withMultipleComplexClassNames_returnsArray() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable(inheritedTypes: ["MyModule.BaseClass<T>", "AnotherModule.Protocol", "SimpleClass"])
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertEqual(result, ["MyModule.BaseClass<T>", "AnotherModule.Protocol", "SimpleClass"])
    XCTAssertTrue(mockContext.diagnostics.isEmpty)
  }
  
  func test_extractInheritedTypesArray_withMixedValidInvalidElements_returnsNilAndDiagnoses() {
    // Given
    let attribute = AttributeSyntax(
      """
      @Spyable(inheritedTypes: ["ValidClass", someVariable])
      """
    )
    
    // When
    let result = Extractor().extractInheritedTypesArray(from: attribute, in: mockContext)
    
    // Then
    XCTAssertNil(result)
    XCTAssertEqual(mockContext.diagnostics.count, 1)
    XCTAssertEqual(
      mockContext.diagnostics.first?.message,
      SpyableDiagnostic.inheritedTypesArgumentRequiresStaticStringArray.message
    )
  }
}

// MARK: - Mock Context

private class MockMacroExpansionContext: MacroExpansionContext {
  var diagnostics: [Diagnostic] = []
  
  func diagnose(_ diagnostic: Diagnostic) {
    diagnostics.append(diagnostic)
  }
  
  func location<Node: SyntaxProtocol>(
    of node: Node,
    at position: PositionInSyntaxNode,
    filePathMode: SourceLocationFilePathMode
  ) -> AbstractSourceLocation? {
    return nil
  }
  
  func location(
    for token: TokenSyntax,
    at position: PositionInSyntaxNode,
    filePathMode: SourceLocationFilePathMode
  ) -> AbstractSourceLocation? {
    return nil
  }
  
  var lexicalContext: [Syntax] = []
  
  func makeUniqueName(_ providedName: String) -> TokenSyntax {
    return TokenSyntax.identifier(providedName)
  }
}
