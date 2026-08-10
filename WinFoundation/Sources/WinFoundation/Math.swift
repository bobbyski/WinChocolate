/// C math functions Foundation re-exports on other platforms.
///
/// The ucrt module itself does not build on the current toolchain (see
/// FOUNDATION_SHIMS.md), so the handful of functions ported code reaches
/// for link directly against the C runtime's exports.

@_silgen_name("ceil")
public func ceil(_ x: Double) -> Double

@_silgen_name("floor")
/// Performs the `floor` operation.
public func floor(_ x: Double) -> Double

@_silgen_name("sin")
/// Performs the `sin` operation.
public func sin(_ x: Double) -> Double

@_silgen_name("cos")
/// Performs the `cos` operation.
public func cos(_ x: Double) -> Double

@_silgen_name("sqrt")
/// Performs the `sqrt` operation.
public func sqrt(_ x: Double) -> Double

@_silgen_name("atan2")
/// Performs the `atan2` operation.
public func atan2(_ y: Double, _ x: Double) -> Double

@_silgen_name("acos")
/// Performs the `acos` operation.
public func acos(_ x: Double) -> Double

@_silgen_name("tan")
/// Performs the `tan` operation.
public func tan(_ x: Double) -> Double

@_silgen_name("pow")
/// Performs the `pow` operation.
public func pow(_ base: Double, _ exponent: Double) -> Double
