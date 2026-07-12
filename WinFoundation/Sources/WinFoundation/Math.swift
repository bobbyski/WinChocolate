/// C math functions Foundation re-exports on other platforms.
///
/// The ucrt module itself does not build on the current toolchain (see
/// FOUNDATION_SHIMS.md), so the handful of functions ported code reaches
/// for link directly against the C runtime's exports.

@_silgen_name("ceil")
public func ceil(_ x: Double) -> Double

@_silgen_name("floor")
public func floor(_ x: Double) -> Double

@_silgen_name("sin")
public func sin(_ x: Double) -> Double

@_silgen_name("cos")
public func cos(_ x: Double) -> Double

@_silgen_name("sqrt")
public func sqrt(_ x: Double) -> Double

@_silgen_name("atan2")
public func atan2(_ y: Double, _ x: Double) -> Double

@_silgen_name("pow")
public func pow(_ base: Double, _ exponent: Double) -> Double
