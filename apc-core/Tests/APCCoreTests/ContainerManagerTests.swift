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

    func testListContainerDirectoryParsesLsOutput() {
        let lsOutput = """
        total 8
        drwxr-xr-x   22 root     root          4096 Jun 15 02:44 .
        drwxr-xr-x   22 root     root          4096 Jun 15 02:44 ..
        drwxr-xr-x    2 root     root          4096 Apr 15 04:51 bin
        -rwxr-xr-x    1 root     root          1620 May 22 18:25 entrypoint.sh
        """
        // listContainerDirectory runs `exec <id> ls -la <path>` — keyed by "exec".
        let manager = makeManager(responses: ["exec": lsOutput])

        let entries = manager.listContainerDirectory(id: "web", path: "/")
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

        XCTAssertNil(byName["."])                                   // "." is dropped
        XCTAssertEqual(byName[".."]?.isDirectory, true)             // ".." kept for navigation
        XCTAssertEqual(byName["bin"]?.isDirectory, true)
        XCTAssertEqual(byName["entrypoint.sh"]?.isDirectory, false)
        XCTAssertEqual(byName["entrypoint.sh"]?.size, "1.6 KB")     // bytes humanised
        XCTAssertEqual(entries.first?.name, "..")                   // ".." sorts first
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

    func testGetImagesPrefixStripVariants() {
        let imageJSON = """
        [
          { "reference": "docker.io/library/nginx:latest", "descriptor": { "size": 5242880 } },
          { "reference": "docker.io/corentinth/it-tools:latest", "descriptor": { "size": 12582912 } },
          { "reference": "ghcr.io/owner/app:1.0", "descriptor": { "size": 3145728 } }
        ]
        """
        let manager = makeManager(responses: ["image": imageJSON])
        let byRepo = Dictionary(uniqueKeysWithValues: manager.getImages().map { ($0.repository, $0) })

        XCTAssertEqual(byRepo["nginx"]?.tag, "latest")                 // docker.io/library/ stripped
        XCTAssertEqual(byRepo["corentinth/it-tools"]?.tag, "latest")   // docker.io/ stripped, user/repo kept
        XCTAssertEqual(byRepo["ghcr.io/owner/app"]?.tag, "1.0")        // non-docker.io host preserved
    }

    func testGetImagesSizeUnderOneMBShowsKBNotNA() {
        let imageJSON = """
        [ { "reference": "small:latest", "descriptor": { "size": 512000 } },
          { "reference": "empty:latest", "descriptor": { "size": 0 } } ]
        """
        let manager = makeManager(responses: ["image": imageJSON])
        let byRepo = Dictionary(uniqueKeysWithValues: manager.getImages().map { ($0.repository, $0) })

        XCTAssertEqual(byRepo["small"]?.size, "500.0 KB")   // sub-MB humanised, not "N/A"
        XCTAssertEqual(byRepo["empty"]?.size, "N/A")        // only a non-positive size is unknown
    }

    func testSplitImageReferenceHandlesRegistryPortAndDigest() {
        // Plain docker.io cases stay exactly as before.
        XCTAssertEqual(ContainerManager.splitImageReference("docker.io/library/nginx:latest").repository, "nginx")
        XCTAssertEqual(ContainerManager.splitImageReference("docker.io/library/nginx:latest").tag, "latest")

        // A registry host:port must not be mistaken for a repo:tag.
        let port = ContainerManager.splitImageReference("localhost:5000/myapp:1.0")
        XCTAssertEqual(port.repository, "localhost:5000/myapp")
        XCTAssertEqual(port.tag, "1.0")

        // No tag defaults to "latest"; non-docker host preserved.
        let noTag = ContainerManager.splitImageReference("ghcr.io/owner/app")
        XCTAssertEqual(noTag.repository, "ghcr.io/owner/app")
        XCTAssertEqual(noTag.tag, "latest")

        // Digest reference keeps the repository; the digest is shown as a short tag.
        let digest = ContainerManager.splitImageReference("docker.io/library/redis@sha256:abcdef0123456789")
        XCTAssertEqual(digest.repository, "redis")
        XCTAssertTrue(digest.tag.hasPrefix("@"))
    }

    func testGetContainersDoesNotWriteRoutingOnItsOwn() {
        let listJSON = """
        [ { "configuration": { "id": "web", "image": { "reference": "nginx:latest" },
            "publishedPorts": [ { "hostPort": 8081, "containerPort": 80 } ] }, "status": "running" } ]
        """
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("apc-tests-\(UUID().uuidString)")
        let manager = ContainerManager(engine: FakeContainerEngine(responses: ["list": listJSON]),
                                       stateDirectory: tmp)
        let routingURL = tmp.appendingPathComponent("routing.json")
        // init() syncs routing once; remove it and prove a pure read doesn't recreate it.
        try? FileManager.default.removeItem(at: routingURL)
        _ = manager.getContainers()
        _ = manager.getContainers()
        XCTAssertFalse(FileManager.default.fileExists(atPath: routingURL.path),
                       "getContainers() must be a pure read and not write routing.json")
    }

    func testGetContainersReturnsEmptyLogsAndFetchesOnDemand() {
        let listJSON = """
        [ { "configuration": { "id": "web", "image": { "reference": "nginx:latest" } }, "status": "running" } ]
        """
        let manager = makeManager(responses: ["list": listJSON, "logs": "line-1\nline-2\n"])

        // The list path no longer carries logs (no per-container fan-out)...
        XCTAssertEqual(manager.getContainers().first?.logs, [])
        // ...they are fetched on demand instead.
        XCTAssertEqual(manager.getContainerLogs(id: "web"), ["line-1", "line-2"])
    }

    func testReconcileRoutingRecoversAnOutOfBandDeletedFile() {
        let listJSON = """
        [ { "configuration": { "id": "web", "image": { "reference": "nginx:latest" },
            "publishedPorts": [ { "hostPort": 8081, "containerPort": 80 } ] }, "status": "running" } ]
        """
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("apc-tests-\(UUID().uuidString)")
        let manager = ContainerManager(engine: FakeContainerEngine(responses: ["list": listJSON]),
                                       stateDirectory: tmp)
        let routingURL = tmp.appendingPathComponent("routing.json")

        // init() already wrote it; delete it out-of-band and confirm reconcile rewrites it
        // even though the route set is unchanged (the dedup must not mask a missing file).
        try? FileManager.default.removeItem(at: routingURL)
        manager.reconcileRouting()
        XCTAssertTrue(FileManager.default.fileExists(atPath: routingURL.path))
        let json = (try? String(contentsOf: routingURL, encoding: .utf8)) ?? ""
        XCTAssertTrue(json.contains("web.apc.local") && json.contains("8081"))
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

    func testHostPortSkipsUnparseableMappings() {
        // First parseable host port wins; non-numeric entries are skipped, not crashing.
        XCTAssertEqual(container(name: "web", ports: ["weird", "9090:80"]).hostPort, 9090)
        XCTAssertNil(container(name: "web", ports: ["notaport"]).hostPort)
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

/// routing.json is read by the Go reverse proxy as `{ "routes": { host: port } }`.
/// Lock the Swift writer's schema to that shape so the two stay in sync.
final class RoutingConfigTests: XCTestCase {

    func testEncodesToGoSchemaAndRoundTrips() throws {
        let config = RoutingConfig(routes: ["web.apc.local": 8081, "db.apc.local": 5432])
        let data = try JSONEncoder().encode(config)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let routes = try XCTUnwrap(json["routes"] as? [String: Int])  // exactly one top-level key: "routes"
        XCTAssertEqual(Array(json.keys), ["routes"])
        XCTAssertEqual(routes["web.apc.local"], 8081)
        XCTAssertEqual(routes["db.apc.local"], 5432)

        XCTAssertEqual(try JSONDecoder().decode(RoutingConfig.self, from: data), config)
    }
}
