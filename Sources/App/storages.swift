import Vapor
import Logging
import FileStorage
import WhooshingServer

/// 在此处配置文件加密存储模块，可以配置多个，请自行添加所需要的存储模块配置
/// 每个文件加密存储模块都需要将文件索引存入一个数据库中，因此它需要绑定一个数据库实例
/// 使用 `Woo.inline.syncMakeFileStorage` 初始化一个 FileStorage 对象，可在全局使用
/// 需要注意的是，一旦初始化失败将会导致服务崩溃
extension FileStorage {
    
    /// 默认文件存储模块，其加密文件的存储位置在 "default" 文件夹下(沙盒中)
    /// 使用数据库服务 "default" 中的 "file_storage" 数据库存储文件索引
    /// 创建了一个最基本的 Logger，仅将日志记录打印在程序输出中
    /// 自动创建根文件夹(加密文件的存储文件夹，相对于沙盒的路径)如果其不存在
    /// 如果是在独立测试环境中，则启动 debugging 模式，否则使用正常的生产或开发模式
    static let `default`: FileStorage = {
        Woo.inline.syncMakeFileStorage(
            for: db(name: "file_storage", from: "default", in: Woo.inline),
            storagePath: "default",
            logger: {
                var logger = Logger(label: "default")
                logger.logLevel = Woo.logLevel
                return logger
            }(),
            dirCreateAction: .createIfNeed(withIntermediateDirectories: true),
            debugging: Woo.isIndependentDebug
        )
    }()
}

/// 从 `dbServices` 中根据名称取得数据库的配置
///
/// - Parameters:
///     - name: 数据库的名称
///     - service: 数据库服务的名称
///     - woo: 数据库服务所在的服务子模块
/// - Returns: 所创建的数据库服务
///
/// 如果未找到，将直接导致程序崩溃
func db<T>(name: String, from service: String, in woo: Whooshing<T>) -> Environment.DB {
    guard let dbService = (woo.config.dbServices.first { $0.id.string == service }) else {
        fatalError("未找到所指定的数据库服务配置")
    }
    guard let db = (dbService.dbs.first { $0.id == .init(string: "\(service)/\(name)") }) else {
        fatalError("未能找到所指定的数据库配置")
    }
    return db
}
