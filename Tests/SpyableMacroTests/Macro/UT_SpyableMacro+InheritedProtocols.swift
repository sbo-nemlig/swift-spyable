import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SpyableMacro

final class UT_SpyableMacroInheritedProtocols: XCTestCase {
  private let sut = ["Spyable": SpyableMacro.self]

  func testMacroWithInheritedProtocols() {
    let protocolDeclarations = """
      protocol TestProtocol {
          func testMethod()
      }
      
      protocol TestTwoProtocol {
          func testTwoMethod()
      }
      
      protocol CombinedProtocol {
          func combinedMethod()
      }
      """

    assertMacroExpansion(
      """
      \(protocolDeclarations)
      
      @Spyable(inheritedTypes: ["TestSpy", "TestTwoSpy"])
      protocol CombinedProtocol {
          func combinedMethod()
      }
      """,
      expandedSource: """
        \(protocolDeclarations)
        
        protocol CombinedProtocol {
            func combinedMethod()
        }

        class CombinedProtocolSpy: CombinedProtocol, @unchecked Sendable {
            init() {
            }
            var testMethodCallsCount = 0
            var testMethodCalled: Bool {
                return testMethodCallsCount > 0
            }
            var testMethodClosure: (() -> Void)?
            func testMethod() {
                testMethodCallsCount += 1
                testMethodClosure?()
            }
            var testTwoMethodCallsCount = 0
            var testTwoMethodCalled: Bool {
                return testTwoMethodCallsCount > 0
            }
            var testTwoMethodClosure: (() -> Void)?
            func testTwoMethod() {
                testTwoMethodCallsCount += 1
                testTwoMethodClosure?()
            }
            var combinedMethodCallsCount = 0
            var combinedMethodCalled: Bool {
                return combinedMethodCallsCount > 0
            }
            var combinedMethodClosure: (() -> Void)?
            func combinedMethod() {
                combinedMethodCallsCount += 1
                combinedMethodClosure?()
            }
        }
        """,
      macros: sut
    )
  }

  func testMacroWithInheritedProtocolsComplex() {
    let protocolDeclarations = """
      protocol BaseProtocol {
          var name: String { get set }
          func initialize(name: String)
      }
      
      protocol ExtendedProtocol {
          func fetchData() async throws -> [String]
      }
      
      protocol FinalProtocol {
          func process()
      }
      """

    assertMacroExpansion(
      """
      \(protocolDeclarations)
      
      @Spyable(inheritedTypes: ["BaseSpy", "ExtendedSpy"])
      protocol FinalProtocol {
          func process()
      }
      """,
      expandedSource: """
        \(protocolDeclarations)
        
        protocol FinalProtocol {
            func process()
        }

        class FinalProtocolSpy: FinalProtocol, @unchecked Sendable {
            init() {
            }
            var name: String {
                get {
                    underlyingName
                }
                set {
                    underlyingName = newValue
                }
            }
            var underlyingName: (String)!
            var initializeNameCallsCount = 0
            var initializeNameCalled: Bool {
                return initializeNameCallsCount > 0
            }
            var initializeNameReceivedArguments: (name: String)?
            var initializeNameReceivedInvocations: [(name: String)] = []
            var initializeNameClosure: ((String) -> Void)?
            func initialize(name: String) {
                initializeNameCallsCount += 1
                initializeNameReceivedArguments = (name)
                initializeNameReceivedInvocations.append((name))
                initializeNameClosure?(name)
            }
            var fetchDataCallsCount = 0
            var fetchDataCalled: Bool {
                return fetchDataCallsCount > 0
            }
            var fetchDataThrowableError: (any Error)?
            var fetchDataReturnValue: [String]!
            var fetchDataClosure: (() async throws -> [String])?
            func fetchData() async throws -> [String] {
                fetchDataCallsCount += 1
                if let fetchDataThrowableError {
                    throw fetchDataThrowableError
                }
                if fetchDataClosure != nil {
                    return try await fetchDataClosure!()
                } else {
                    return fetchDataReturnValue
                }
            }
            var processCallsCount = 0
            var processCalled: Bool {
                return processCallsCount > 0
            }
            var processClosure: (() -> Void)?
            func process() {
                processCallsCount += 1
                processClosure?()
            }
        }
        """,
      macros: sut
    )
  }

  func testMacroWithInheritedProtocolsAndExplicitInheritance() {
    let protocolDeclarations = """
      protocol TestProtocol {
          func testMethod()
      }
      
      protocol CombinedProtocol {
          func combinedMethod()
      }
      """

    assertMacroExpansion(
      """
      \(protocolDeclarations)
      
      @Spyable(inheritedTypes: ["TestSpy", "BaseClass"])
      protocol CombinedProtocol {
          func combinedMethod()
      }
      """,
      expandedSource: """
        \(protocolDeclarations)
        
        protocol CombinedProtocol {
            func combinedMethod()
        }

        class CombinedProtocolSpy: CombinedProtocol, @unchecked Sendable {
            init() {
            }
            var testMethodCallsCount = 0
            var testMethodCalled: Bool {
                return testMethodCallsCount > 0
            }
            var testMethodClosure: (() -> Void)?
            func testMethod() {
                testMethodCallsCount += 1
                testMethodClosure?()
            }
            var combinedMethodCallsCount = 0
            var combinedMethodCalled: Bool {
                return combinedMethodCallsCount > 0
            }
            var combinedMethodClosure: (() -> Void)?
            func combinedMethod() {
                combinedMethodCallsCount += 1
                combinedMethodClosure?()
            }
        }
        """,
      macros: sut
    )
  }
}