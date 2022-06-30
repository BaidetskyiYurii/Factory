import XCTest
@testable import Factory

final class FactoryMultithreadingTests: XCTestCase {

    let container = MultiThreadedContainer()

    let qa = DispatchQueue(label: "A", qos: .userInteractive, attributes: .concurrent)
    let qb = DispatchQueue(label: "B", qos: .background, attributes: .concurrent)
    let qc = DispatchQueue(label: "C", qos: .userInitiated, attributes: .concurrent)
    let qe = DispatchQueue(label: "E", qos: .userInitiated, attributes: .concurrent)

    override func setUp() {
        super.setUp()
        Container.Registrations.reset()
        Container.Scope.reset()
    }

    func testMultiThreading() throws {
        // basically tests that nothing locks up or crashes while doing registrations and resolutions
        for _ in 0...1000 {
            qa.async {
               MultiThreadedContainer.a.register { A(b: MultiThreadedContainer.b()) }
            }
            qa.async {
                MultiThreadedContainer.b.register { B(c: MultiThreadedContainer.c()) }
                self.qc.async {
                    let b: B = MultiThreadedContainer.b()
                    b.test()
                }
                self.qe.async {
                    let b: B = MultiThreadedContainer.b()
                    b.test()
                }
            }
            qa.async {
                let b: B = MultiThreadedContainer.b()
                b.test()
            }
            qb.async {
                let a: A = MultiThreadedContainer.a()
                a.test()
            }
            qb.async {
                let d: D = MultiThreadedContainer.d()
                d.test()
            }
            qc.async {
                let e: E = MultiThreadedContainer.e()
                self.qe.async {
                    e.test()
                }
                self.qe.async {
                    e.test()
                }
            }
        }

        wait(interval: 1.0) {
            XCTAssert(iterations == 9009)
        }

    }

}

var iterations = 0
let lock = NSRecursiveLock()

func increment() {
    lock.lock()
    iterations += 1
    lock.unlock()
}

fileprivate class A {
    var b: B
    init(b: B) {
        self.b = b
    }
    func test() {
        increment()
    }
}

fileprivate class B {
    var c: C
    init(c: C) {
        self.c = c
    }
    func test() {
        increment()
    }
}

fileprivate class C {
    var d: D
    init(d: D) {
        self.d = d
    }
    func test() {
        increment()
    }
}

fileprivate class D {
    init() {}
    func test() {
        increment()
    }
}

fileprivate class E {
    @LazyInjected(MultiThreadedContainer.d) var d: D
    init() {}
    func test() {
        d.test()
        increment()
    }
}

class MultiThreadedContainer: SharedContainer {
    fileprivate static var a = Factory<A> { A(b: b()) }
    fileprivate static var b = Factory<B> { B(c: c()) }
    fileprivate static var c = Factory<C> { C(d: d()) }
    fileprivate static var d = Factory<D>(scope: .cached) { D() }
    fileprivate static var e = Factory<E> { E() }
}

extension XCTestCase {
    func wait(interval: TimeInterval = 0.1 , completion: @escaping (() -> Void)) {
        let exp = expectation(description: "")
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            completion()
            exp.fulfill()
        }
        waitForExpectations(timeout: interval + 0.1) // add 0.1 for sure asyn after called
    }
}
