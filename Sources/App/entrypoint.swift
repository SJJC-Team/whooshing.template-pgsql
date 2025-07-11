import Vapor
import Logging
import NIOCore
import NIOPosix
import Cryptos
import ErrorHandle
import FileStorage
import WhooshingServer

/// 该函数为入口函数，是整个 Vapor 服务的执行起始点
/// 该函数根据环境变量(API, HTTPS)分别设置服务类型，并进行初始化
/// 环境变量可在 Package.swift 中设置
/// 不同服务的 Application 实例可以分别通过 Woo.api, Woo.inline, Woo.https 来取得
/// 要对不同的实例进行额外配置，在 configure.swift 进行额外配置
///
/// 服务运行时，会根据启动参数决定所运行的模式
/// 根据不同的启动参数有：
///
/// swift run App serve --env production
/// swift run App serve --env development
/// swift run App serve --env testing
///
/// 分别对应 生产，开发，测试 环境
/// 若是 xcode 构建，则默认为 development 环境

@main
enum Entrypoint {
    enum Err: String, ErrList {
        case illegalService = "不合法的服务模块"
    }
    
    /// 配置该服务模块是否接受运行在测试环境中，可将其改为 false
    /// 这样，若检测到环境为 testing 将会直接 fatalError
    /// 另请详见 ``Whooshing.Mode``
    static let testingAllowed = true
    
    // 初始化你的 PostgreSQL 配置，此处设置，将连接到所有的服务模块，你也可以提供为不同的子模块提供不同的数据库
    // 这些参数仅在独立测试环境中可用
    // 生产环境中将由 Whooshing 系统提供加密数据库
    //
    // 该配置设置 PostgreSQL 服务配置，而每个数据库服务中可有多个数据库，通过 dbParameters 进行设置
    //
    // PostgreSQL 连接的主机名在生产和开发环境中仅仅允许在本地(localhost)
    // 而在测试环境中，可指定要用于测试的 Pg 服务器主机名
    // 该字段将会在生产环境中失效，因此标记为 "unsafeTestOnly"
    // unsafeTestOnlyHost 将会根据环境变量检测是否连接到特定的主机名，主要用于 Github Workflow 的自动测试检查
    static let dbServices: [Environment.DBService] = [
        .init(
            name: "testing",
            port: 5432,
            dbParameters: [
                .init(
                    name: "postgres",
                    user: "clwang",
                    password: "password",
                    unsafeTestOnlyHost: ProcessInfo.processInfo.environment["GITHUB_PG_TESTING_HOST"] ?? "localhost"
                )
            ]
        )
    ]
    
    static func main() async throws {
        var mode = Whooshing<Inline>.Mode.detect(testingAllowed ? UnsafeDebuggingOnly.inlineDebuggingData(dbServiceConfigs: dbServices) : nil)
        try LoggingSystem.bootstrap(from: &mode.envrionment)
        Woo.isIndependentDebug = mode.envrionment != .production && testingAllowed
        let inline = try await Whooshing.make(mode).get()
        do {
            try await Configuration.inline(inline, app: inline.app)
        } catch {
            inline.logger.report(error: error)
            try? await inline.asyncShutdown().get()
            throw error
        }
        Woo.inline = inline
        
        #if API
        var apiMode = Whooshing<Api>.Mode.detect(testingAllowed ? UnsafeDebuggingOnly.apiDebuggingData(dbServiceConfigs: dbServices) : nil)
        apiMode.envrionment = mode.envrionment
        let api = try await Whooshing.make(apiMode, with: inline).get()
        do {
            try await Configuration.api(api, app: api.app)
        } catch {
            api.logger.report(error: error)
            try? await api.asyncShutdown().get()
            throw error
        }
        Woo.api = api
        #endif
        
        #if HTTPS
        var httpsMode = Whooshing<Https>.Mode.detect(testingAllowed ? UnsafeDebuggingOnly.httpsDebuggingData(dbServiceConfigs: dbServices) : nil)
        httpsMode.envrionment = mode.envrionment
        let https = try await Whooshing.make(httpsMode).get()
        do {
            try await Configuration.https(https, app: https.app)
        } catch {
            https.logger.report(error: error)
            try? await https.asyncShutdown().get()
            throw error
        }
        Woo.https = https
        #endif
        
        // 并行启动服务
        #if !API && !HTTPS
        try await inline.executeWithAsyncShutdown()
        #else
        async let _ = inline.executeWithAsyncShutdown()
        #endif
        
        #if API
        async let _ = api.executeWithAsyncShutdown()
        #endif
        
        #if HTTPS
        async let _ = https.executeWithAsyncShutdown()
        #endif
        
    }
}

/// 记录不同的服务实例，请勿尝试修改其中的内容，除非你知道你在做什么
struct Woo {
    fileprivate(set) nonisolated(unsafe) static var isIndependentDebug = true
    
    fileprivate(set) nonisolated(unsafe) static var inline: Whooshing<Inline>!
    
    #if API
    fileprivate(set) nonisolated(unsafe) static var api: Whooshing<Api>!
    #endif
    
    #if HTTPS
    fileprivate(set) nonisolated(unsafe) static var https: Whooshing<Https>!
    #endif
}

struct UnsafeDebuggingOnly {
    static let rootKey = Crypto.Symm.Key(data: Data(base64Encoded: rootKeyStr)!)
    static let rootKeyStr = "0apYyvRtLuo7l07zuqbEjFIxDFZ1sIWabKM9mMOOIzQ="
    
    static let apiClientCredential = "bRRPIiYbt0t4RzfqeeHSkg=="

    static let apiClientToken = Crypto.Symm.Key(data: Data(base64Encoded: apiClientTokenStr)!)
    static let apiClientTokenStr = "jXTz4vTQk0O/XFIjWQIHLC7z9/E0/4VtEb+LkF8IcA4="

    static let inlineListenPort = 6500
    static let httpsListenPort = 6501
    static let apiListenPort = 6502
    
    static let serviceIds = [
        UUID(uuidString: "F1ECC1D7-6E19-4F50-9B89-68FAA332B415")!,
        UUID(uuidString: "2AC424F7-F26A-4EA4-BE44-202ABC7CC514")!,
        UUID(uuidString: "74854475-1C1A-48E2-BAC9-E9C752942F88")!,
        UUID(uuidString: "C59C74DC-AF7F-4497-854B-75561D9FE995")!,
        UUID(uuidString: "F02F2803-BF88-4B51-A743-B3AA0F3FF804")!
    ]
    
    static func inlineDebuggingData(dbServiceConfigs: [Environment.DBService] = []) -> Inline.Debuging {
        .init(
            rootKey: rootKey,
            config: Environment.Config(
                name: "Testing-Inline-\(inlineListenPort)",
                port: inlineListenPort,
                dbServices: dbServiceConfigs
            ),
            serviceId: serviceIds[0],
            moduleDatas: serviceIds.enumerated().map {
                .init(name: "Testing-Inline-\(inlineListenPort + $0)", serviceId: $1, connection: nil)
            }
        )
    }
    
    static func apiDebuggingData(dbServiceConfigs: [Environment.DBService] = []) -> Api.Debuging {
        .init(
            config: Environment.Config(
                name: "Tesing-Api-\(apiListenPort)",
                port: apiListenPort,
                dbServices: dbServiceConfigs
            )
        ) { authData in
            guard authData.credential.base64EncodedString() == apiClientCredential else {
                throw Abort(.badRequest, reason: "用户凭据无效")
            }
            return try Api.Debuging.testingTokenAuth(with: apiClientTokenStr, encrypted: authData.tokenEncrypted)
        }
    }
    
    static func httpsDebuggingData(dbServiceConfigs: [Environment.DBService] = []) -> Https.Debuging{
        .init(
            config: Environment.Config(
                name: "Testing-Https-\(httpsListenPort)",
                port: httpsListenPort,
                dbServices: dbServiceConfigs
            )
        )
    }
}
