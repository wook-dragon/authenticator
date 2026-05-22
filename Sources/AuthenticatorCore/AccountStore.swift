import Foundation

/// 계정 영속화를 추상화한 outbound port. 구현체는 Platform 모듈에서 제공한다.
public protocol AccountStore: AnyObject {
    func load() throws -> [OTPAccount]
    func save(_ accounts: [OTPAccount]) throws
}
