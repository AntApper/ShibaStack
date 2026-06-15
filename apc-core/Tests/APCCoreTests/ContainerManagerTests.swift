import XCTest
@testable import APCCore

/// Test adapter at the `ContainerEngine` seam: returns canned CLI output keyed by
/// subcommand, so `ContainerManager`'s mapping logic runs with no real runtime.
final class FakeContainerEngine: ContainerEngine, @unchecked Sendable {
    /// Keyed by the subcommand (the first argument), e.g. "list", "image", "logs".
    var responses: [String: String]
    private(set) var calls: [[String]] = []

    init(responses: [String: String]) {
        self.responses = responses
    }

    func run(_ arguments: [String]) -> String? {
        calls.append(arguments)
        return responses[arguments.first ?? ""]
    }
}

final class ContainerManagerTests: XCTestCase {

    /// A fresh manager wired to a fake engine and a throwaway state directory,
    /// so nothing touches the real `~/.apc`.
    private func makeManager(responses: [String: String]) -> ContainerManager {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("apc-tests-\(UUID().uuidString)")
        return ContainerManager(engine: FakeContainerEngine(responses: responses), stateDirectory: tmp)
    }

    func testGetContainersMapsCLIJSONThroughTheSeam() {
        let listJSON = """
        [
          {
            "configuration": {
              "id": "web",
              "image": { "reference": "docker.io/library/nginx:latest" },
              "publishedPorts": [ { "hostPort": 8081, "containerPort": 80 } ]
            },
            "status": "running"
          }
        ]
        """
        let manager = makeManager(responses: ["list": listJSON, "logs": ""])

        let containers = manager.getContainers()

        XCTAssertEqual(containers.count, 1)
        let web = try! XCTUnwrap(containers.first)
        XCTAssertEqual(web.name, "web")
        XCTAssertEqual(web.image, "nginx:latest")          // registry prefix stripped
        XCTAssertEqual(web.state, "running")               // status normalised
        XCTAssertEqual(web.ports, ["8081:80"])             // host:guest reassembled
    }

    func testGetContainersIsEmptyWhenEngineReturnsNothing() {
        let manager = makeManager(responses: [:])
        XCTAssertEqual(manager.getContainers().count, 0)
    }

    func testGetImagesStripsPrefixAndSplitsTag() {
        let imageJSON = """
        [ { "reference": "docker.io/library/redis:7.2", "descriptor": { "size": 5242880 } } ]
        """
        let manager = makeManager(responses: ["image": imageJSON])

        let images = manager.getImages()

        XCTAssertEqual(images.count, 1)
        let redis = try! XCTUnwrap(images.first)
        XCTAssertEqual(redis.repository, "redis")
        XCTAssertEqual(redis.tag, "7.2")
        XCTAssertEqual(redis.size, "5.0 MB")
    }
}

/// The host/guest wire contract — one typed codec, exercised without a socket.
final class GuestProtocolTests: XCTestCase {

    func testCommandEncodesAsNewlineTerminatedJSON() throws {
        let line = try GuestProtocol.encodeLine(GuestCommand(action: "exec", name: "web", cmd: ["ls", "-la"]))
        XCTAssertEqual(line.last, 0x0A) // framed with '\n'
        let decoded = try JSONDecoder().decode(GuestCommand.self, from: line.dropLast())
        XCTAssertEqual(decoded, GuestCommand(action: "exec", name: "web", cmd: ["ls", "-la"]))
    }

    func testResponseDecodesGuestReplyWithOmittedFields() throws {
        // The guest omits empty output/error (Go `omitempty`); they must default to "".
        let ok = try GuestProtocol.decode(Data(#"{"success":true,"output":"hi"}"#.utf8))
        XCTAssertEqual(ok, GuestResponse(success: true, output: "hi"))

        let fail = try GuestProtocol.decode(Data(#"{"success":false,"error":"boom"}"#.utf8))
        XCTAssertFalse(fail.success)
        XCTAssertEqual(fail.error, "boom")
        XCTAssertEqual(fail.output, "")
    }
}

/// The deepened `Container` model owns port parsing and `*.apc.local` naming —
/// these run without any engine at all (pure, in-process).
final class ContainerDomainTests: XCTestCase {

    private func container(name: String, ports: [String]) -> Container {
        Container(id: name, name: name, image: "x", state: "running",
                  ports: ports, cpuUsage: 0, memoryUsage: 0, logs: [])
    }

    func testHostPortReadsHostSideOfFirstMapping() {
        XCTAssertEqual(container(name: "web", ports: ["8081:80"]).hostPort, 8081)
        XCTAssertEqual(container(name: "web", ports: ["9090"]).hostPort, 9090) // bare port
        XCTAssertNil(container(name: "web", ports: []).hostPort)
    }

    func testPrimaryDomainFromName() {
        XCTAssertEqual(container(name: "api", ports: []).primaryDomain, "api.apc.local")
    }

    func testRouteMappingsNamesPrimaryAndSecondaryPorts() {
        let routes = container(name: "web", ports: ["8081:80", "5050:5000"]).routeMappings
        XCTAssertEqual(routes["web.apc.local"], 8081)        // first port owns the bare domain
        XCTAssertEqual(routes["web-5050.apc.local"], 5050)   // later ports get suffixed
    }
}
