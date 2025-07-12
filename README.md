# Whooshing with PostgreSQL ORM 服务模块模版
基于 [Vapor](https://vapor.codes/) 以及 [WhooshingServer](https://github.com/SJJC-Team/whooshing.toolbox-server) 构建的服务模块模版，且提供 PostgreSQL 数据库 ORM 支持。

用于快速初始化一个 Whooshing 系统的服务模块且与其深度集成，可创建 API / HTTPS / INLINE 三种子模块类型且支持进行独立开发环境测试。

已集成以下 Whooshing 核心库：

- [whooshing.toolbox-server](https://github.com/SJJC-Team/whooshing.toolbox-server)
- [whooshing.toolbox-file-storage](https://github.com/SJJC-Team/whooshing.toolbox-file-storage)
- [whooshing.toolbox-basic](https://github.com/SJJC-Team/whooshing.toolbox-basic)
- [whooshing.toolbox-pgsql](https://github.com/SJJC-Team/whooshing.toolbox-pgsql)
- [whooshing-vapor](https://github.com/SJJC-Team/whooshing-vapor)

本项目高度依赖  [Vapor](https://vapor.codes/)，另请参阅 [Vapor 官方文档](https://docs.vapor.codes/)

--------

### 项目简介

通过少量配置即可启动开发、调试与部署。另见 [whooshing.toolbox-server](https://github.com/SJJC-Team/whooshing.toolbox-server)

支持构建独立的服务子模块，可与 Whooshing 系统中的其他模块无缝对接，默认集成：

- ✅ Vapor 启动框架
- ✅ Whooshing 的服务模块创建机制
- ✅ Debug 配置与模块测试数据
- ✅ 环境变量自动识别与配置切换
- ✅ 多模块并行启动支持（如 API + INLINE）

------

### 快速开始

1. **克隆本模版项目**

   ```sh
   git clone https://github.com/SJJC-Team/whooshing.template-basic.git MyService
   cd MyService
   ```

2. **修改模块名称 (可选)**

   修改 [Package.swift](Package.swift) 的 name 字段与 target 名称来命名你的模块：

   ```swift
   name: "whooshing.my-service"
   ```

   同时修改 [pm2.config.json](pm2.config.json)  的 name 字段，确保名称与 Package  的名称相同

   ```json
   "name": "whooshing.template-pgsql"
   ```

3. **设置模块类型**

   在 [Package.swift](Package.swift) 文件顶部设置你要启用的子模块类型：

   ```swift
   let WhooshingModules: [WhooshingModuleType] = [
       .api,
       .https
   ]
   ```

   > INLINE 子模块是必须的，因此未提供 INLINE 子模块的可选配置
   >
   > 关于子模块，请见  [whooshing.toolbox-server](https://github.com/SJJC-Team/whooshing.toolbox-server)

4. **调整 PGSQL 的服务连接参数**

   在 [entrypoint.swift](entrypoint.swift) 文件调整数据库连接参数：

   ```swift
   /// 初始化你的 PostgreSQL 配置，此处设置，将连接到所有的服务模块，你也可以提供为不同的子模块提供不同的数据库
   /// 这些参数仅在独立测试环境中可用
   /// 生产环境中将由 Whooshing 系统提供加密数据库
   ///
   /// 该配置设置 PostgreSQL 服务配置，而每个数据库服务中可有多个数据库，通过 dbParameters 进行设置
   ///
   /// PostgreSQL 连接的主机名在生产和开发环境中仅仅允许在本地(localhost)
   /// 而在测试环境中，可指定要用于测试的 Pg 服务器主机名
   /// 该字段将会在生产环境中失效，因此标记为 "testingHost"
   ///
   /// fileStorageKey 用于文件加密系统的加密主密钥，为方便测试，硬编码至此。在生产环境中，这些均为无效
   /// 只有需要作为 FileStorage 的数据库才需要配置 fileStorageKey，若不设置则表示不支持在其上创建文件加密系统
   /// 作为测试目的，这些密钥可以重复
   static let dbServices: [Environment.DBService] = [
       .init(
           name: "default",
           port: 5432,
           dbParameters: [
               .init(
                   name: "postgres",
                   user: "postgres",
                   password: "password",
                   testingHost: "localhost"
               ),
               .init(
                   name: "file_storage",
                   user: "postgres",
                   password: "password",
                   testingHost: "localhost",
                   fileStorageKey: Crypto.Symm.Key(data: Data(base64Encoded: "UA/0Si+aUkrJou9W2pCDjrTkDBiAfZxdoD1MEFyHP58=")!)
               )
           ]
       )
   ]
   ```

   > 此处的示例连接参数指定该模块连接运行在本地的 PostgreSQL 数据库服务(连接到端口号 5432)，该服务中有两个数据库，分别为：
   >
   > * 本机的 `postgres`
   > * 本机的 `file_storage`，用于创建文件加密存储系统
   >
   > 所有的连接参数必须真实有效，可以连接到所指示的数据库，否则会导致服务在启动时崩溃
   >
   > 请仔细阅读注释指导，根据你自己的数据库服务调整连接参数

   **再次重申，这些参数仅在独立测试环境中被使用，在生产环境中不会使用这些参数**

5. **配置数据库迁移**

   在 [configure.swift](configure.swift) 中登记以及应用数据库的初始化，以创建或迁移数据库表结构

   ```swift
   /// 数据库的迁移配置登记，用于初始化数据库的表结构
   /// 每个数据库可能被多个子服务所连接(inline, api, https)，但一个数据库一般应当仅初始化一次
   /// 避免多个子服务抢占初始化表结构
   /// Whooshing 系统将会为每个所配置的数据库调用该配置函数，以及该数据库被连接的子服务
   /// 保证所提供的数据库绝不重复，因此你可以在这里安全地分别为每个数据库登记迁移
   /// 这里登记了迁移并不会马上应用到真实数据库中，请见下一步 `migrationApply(in:)`
   static func migrationRegister(in database: Environment.DB, for services: [any WhooshingService]) async throws {
       if database.id.string == "default/postgres" {
           /// 作为示例，只对在 default 数据库服务中的 postgres 数据库进行初始化，
           /// 使用 database.id 做分辨，id 规则遵循 数据库服务名 + / + 数据库名
           /// 至于有哪些数据库请详见你的 `configure.yaml`(生产环境) 中 `pgsql` 下的配置，
           /// 或 `entrypoint.swift`(测试环境) 中 `Woo.dbServices` 下的配置
           /// 此处，default 数据库服务中的另一个数据库(file_storage)无需进行额外初始化
           /// FileStorage 模块会自行初始化
           services.first!.app.migrations.add(User.MIG(), to: database.id)
       }
   }
   
   /// 数据库迁移登记完成之后，将这些迁移应用到真实数据库中
   static func migrationApply(for service: any WhooshingService) async throws {
       // 第一次运行，若你的 PostgreSQL 服务中没有创建该表，则需要进行 autoMigrate
       // 此举将自动创建所需要的数据库表，一般来说只需运行一次即可，若表结构已经存在可注释这一行
       try await service.app.autoMigrate()
   }
   ```

   > 请仔细阅读注释引导，并照你的需求进行修改

6. **文件加密系统配置**

   在 [storages.swift](storages.swift) 中调整文件系统的配置：

   ```swift
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
   ```

   > 你可以创建多个，也可以删除默认的 `default` 存储模块
   >
   > 需要调用时，只需使用 `FileStorage.default` 即可，关于 `FileStorage` 请详见 [whooshing.toolbox-file-storage](https://github.com/SJJC-Team/whooshing.toolbox-file-storage)

7. **模块配置**

   在 [configure.yaml](configure.yaml) 中根据你的需求进行配置

   > 关于具体的配置细节，请详细参照其中的注释文档

8. **运行项目**

   使用 Xcode 或命令行运行：

   ```sh
   swift run App serve --env development
   ```

   或指定环境：

   ```sh
   swift run App serve --env production
   ```

   Xcode 启动默认即为开发环境 (development)

   > 在  [entrypoint.swift](Sources/App/entrypoint.swift) 的 `DebuggingParameters` 中定义了默认 rootKey、token、凭据等调试数据，实际部署时应替换或禁用调试代码。
   >
   > 具体的调试细节，请参见文档注释

------

### 项目结构预览

```
├── configure.swift       // 模块配置入口
├── storages.swift				// 文件加密系统配置文件
├── entrypoint.swift      // 项目入口与服务启动控制
├── routes.swift          // 路由注册
├── Package.swift         // Swift Package 描述文件
├── AppTests/             // 测试代码
```

--------

### 路由测试

模版项目默认包含简单的测试路由：

```swift
GET /
返回 "It works!"

GET /hello
返回 "Hello, world!"
```

你可以在 routes.swift 中添加自定义路由。

-------

### 模块配置说明

配置逻辑集中在 configure.swift：

```swift
static func api(_ woo: Whooshing<Api>, app: Application)
static func https(_ woo: Whooshing<Https>, app: Application)
static func inline(_ woo: Whooshing<Inline>, app: Application)
```

用于初始化每个模块的依赖、路由、日志等内容

--------

### 单元测试支持

项目已包含测试目标，可在 AppTests 中添加 Vapor 路由测试：

```sh
swift test
```

-----

### 运行环境

* **macOS** (> 11.0)
* **iOS** (> 14.0)
* **Linux** (> 20)
* **Swift** (> 5.9)
* **watchOS** (> 6.0) **[未测试]**
* **tvOS**(> 13) **[未测试]**

-------

### 联系与反馈

如有使用问题或建议，请通过 [GitHub Issues](https://github.com/SJJC-Team/whooshing.toolbox-server/issues) 提交反馈。

或发至邮箱 [contact@official.whooshings.space](mailto:contact@official.whooshings.space)
