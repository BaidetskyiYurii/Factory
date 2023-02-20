import XCTest
@testable import Factory

class Services1 {
    @Injected(\.myServiceType) var service
    @Injected(\.mockService) var mock
    @Injected(\CustomContainer.test) var test
    init() {}
}

class Services2 {
    @LazyInjected(\.myServiceType) var service
    @LazyInjected(\.mockService) var mock
    @LazyInjected(\CustomContainer.test) var test
    init() {}
}

class Services3 {
    @WeakLazyInjected(\.sharedService) var service
    @WeakLazyInjected(\.mockService) var mock
    @WeakLazyInjected(\CustomContainer.test) var test
    init() {}
}

class Services5 {
    @Injected(\.optionalService) var service
    init() {}
}

class ServicesP {
    @LazyInjected(\.servicesC) var service
    let name = "Parent"
    init() {}
    func test() -> String? {
        service.name
    }
}

class ServicesC {
    @WeakLazyInjected(\.servicesP) var service: ServicesP?
    @WeakLazyInjected(\CustomContainer.test) var testService
    init() {}
    let name = "Child"
    func test() -> String? {
        service?.name
    }
}

extension Container {
    fileprivate var services1: Factory<Services1> { unique { Services1() } }
    fileprivate var services2: Factory<Services2> { unique { Services2() } }
    fileprivate var services3: Factory<Services3> { unique { Services3() } }
    fileprivate var servicesP: Factory<ServicesP> { shared { ServicesP() } }
    fileprivate var servicesC: Factory<ServicesC> { shared { ServicesC() } }
}

protocol ProtocolP: AnyObject {
    var name: String { get }
    func test() -> String?
}

class ProtocolClassP: ProtocolP {
    let child = Container.shared.protocolC()
    let name = "Parent"
    init() {}
    func test() -> String? {
        child.name
    }
}

protocol ProtocolC: AnyObject {
    var parent: ProtocolP? { get set }
    var name: String { get }
    func test() -> String?
}

class ProtocolClassC: ProtocolC {
    weak var parent: ProtocolP?
    init() {}
    let name = "Child"
    func test() -> String? {
        parent?.name
    }
}

extension Container {
    fileprivate var protocolP: Factory<ProtocolP> {
        shared {
            let p = ProtocolClassP()
            p.child.parent = p
            return p
        }
    }
    fileprivate var protocolC: Factory<ProtocolC> {
        shared { ProtocolClassC() }
    }
}

final class FactoryInjectionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Container.shared = Container()
    }

    func testBasicInjection() throws {
        let services = Services1()
        XCTAssertEqual(services.service.text(), "MyService")
        XCTAssertEqual(services.mock.text(), "MockService")
        XCTAssertEqual(services.test.text(), "MockService32")
    }

    func testLazyInjection() throws {
        let services = Services2()
        XCTAssertEqual(services.service.text(), "MyService")
        XCTAssertEqual(services.mock.text(), "MockService")
        XCTAssertEqual(services.test.text(), "MockService32")
    }

    func testLazyInjectionOccursOnce() throws {
        let services = Services2()
        let id1 = services.service.id
        let id2 = services.service.id
        XCTAssertTrue(id1 == id2)
    }

    func testOptionalInjection() throws {
        let services = Services5()
        XCTAssertTrue(services.service?.text() == "MyService")
    }

    func testWeakLazyInjection() throws {
        var parent: ServicesP? = Container.shared.servicesP()
        let child = Container.shared.servicesC()
        let test = CustomContainer.shared.test()
        XCTAssertEqual(parent?.test(), "Child")
        XCTAssertEqual(child.test(), "Parent")
        XCTAssertEqual(child.testService?.text(), test.text())
        parent = nil
        XCTAssertNil(child.test())
    }

    func testWeakLazyInjectionProtocol() throws {
        var parent: ProtocolP? = Container.shared.protocolP()
        let child: ProtocolC? = Container.shared.protocolC()
        XCTAssertTrue(parent?.test() == "Child")
        XCTAssertTrue(child?.test() == "Parent")
        parent = nil
        XCTAssertNil(child?.test())
    }

    func testInjectionSet() throws {
        let service = Container.shared.services1()
        let oldId = service.service.id
        let newService = MyService()
        let newId = newService.id
        service.service = newService
        XCTAssertTrue(service.service.id != oldId)
        XCTAssertTrue(service.service.id == newId)
    }

    func testLazyInjectionSet() throws {
        let service = Container.shared.services2()
        let oldId = service.service.id
        let newService = MyService()
        let newId = newService.id
        service.service = newService
        XCTAssertTrue(service.service.id != oldId)
        XCTAssertTrue(service.service.id == newId)
    }

    func testWeakLazyInjectionSet() throws {
        let strongReference: MyServiceType? = Container.shared.sharedService()
        XCTAssertNotNil(strongReference)
        let service = Container.shared.services3()
        let oldId = service.service?.id
        let newService = MyService()
        let newId = newService.id
        service.service = newService
        XCTAssertTrue(service.service?.id != oldId)
        XCTAssertTrue(service.service?.id == newId)
    }

    func testInjectionResolve() throws {
        let object = Container.shared.services1()
        let oldId = object.service.id
        // force resolution
        object.$service.resolve()
        // should have new instance
        let newId = object.service.id
        XCTAssertTrue(oldId != newId)
    }

    func testLazyInjectionResolve() throws {
        let object = Container.shared.services2()
        let oldId = object.service.id
        // force resolution
        object.$service.resolve()
        // should have new instance
        let newId = object.service.id
        XCTAssertTrue(oldId != newId)
    }

    func testWeakLazyInjectionResolve() throws {
        var strongReference: MyServiceType? = Container.shared.sharedService()
        XCTAssertNotNil(strongReference)
        let oldId = strongReference?.id

        let service = Container.shared.services3()
        let newID = service.service?.id
        XCTAssertTrue(oldId == newID)

        service.service = nil

        service.$service.resolve()
        XCTAssertNotNil(service.service)
        XCTAssertTrue(service.service?.id == newID)

        strongReference = nil
        XCTAssertNil(service.service)

        service.$service.resolve()

        XCTAssertNil(service.service)
    }

}
