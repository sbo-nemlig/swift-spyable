import Spyable

protocol SimpleProtocol {
    func simpleMethod()
}

@Spyable(inheritedTypes: ["SimpleProtocolSpy"])
protocol CombinedProtocol {
    func combinedMethod()
}