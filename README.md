# Whooshing with PostgreSQL ORM 服务模块模版
基于 [Vapor](https://vapor.codes/) 以及 [WhooshingServer](https://github.com/SJJC-Team/whooshing.toolbox-server) 构建的服务模块模版，且提供 PostgreSQL 数据库 ORM 支持。

用于快速初始化一个 Whooshing 系统的服务模块且与其深度集成，可创建 API / HTTPS / INLINE 三种子模块类型且支持进行独立开发环境测试。

已集成以下 Whooshing 核心库：

- [whooshing.toolbox-server](https://github.com/SJJC-Team/whooshing.toolbox-server)
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

   在 [Package.swift](Package.swift) 文件调整参数：

   ```swift
   .............
   
   // 初始化你的 PostgreSQL 配置，此处设置，将连接到所有的服务模块，你也可以提供为不同的子模块提供不同的数据库
   // 这些参数仅在独立测试环境中可用
   // 生产环境中将由 Whooshing 系统提供加密数据库
   //
   // PostgreSQL 连接的主机名在生产和开发环境中仅仅允许在本地(localhost)
   // 而在测试环境中，可指定要用于测试的 Pg 服务器主机名
   // 该字段将会在生产环境中失效，因此标记为 "unsafeTestOnly"
   // unsafeTestOnlyHost 将会根据环境变量检测是否连接到特定的主机名，主要用于 Github Workflow 的自动测试检查
   static let dataBases: [Environment.DB] = [
       .init(
           name: "postgres",
           port: 5432,
           user: "postgres",
           password: "password",
           unsafeTestOnlyHost: ProcessInfo.processInfo.environment["GITHUB_PG_TESTING_HOST"] ?? "localhost"
       )
   ]
   
   .............
   ```

   > 此处的示例连接参数指定该模块连接运行在本地的 PostgreSQL 数据库服务，连接到数据库 "postgres"，端口号 5432，用户 "postgres", 密码为 "password"
   >
   > 你可以通过 `unsafeTestOnlyHost` 调整连接的主机名，但请不要修改 `ProcessInfo.processInfo.environment["GITHUB_PG_TESTING_HOST"]`，这是为了配合 Github 的自动测试脚本而配置的。此处默认为 "localhost"，但在进行 Github 自动测试时根据其环境修改要连接的主机名。
   > 
   >根据你自己的数据库服务调整连接参数
   
   该模版默认提供了 users 表的创建示例
   
   **再次重申，这些参数仅在独立测试环境中被使用，在生产环境中不会使用这些参数**
   
5. **运行项目**

   使用 Xcode 或命令行运行：

   ```sh
   swift run App serve --env development
   ```

   或指定环境：

   ```sh
   swift run App serve --env production
   ```

   Xcode 启动默认即为开发环境 (development)

   > 在  [entrypoint.swift](Sources/App/entrypoint.swift) 的 `UnsafeDebuggingOnly` 中定义了默认 rootKey、token、凭据等调试数据，实际部署时应替换或禁用调试代码。
   >
   > 具体的调试细节，请参见文档注释

------

### 项目结构预览

```
├── configure.swift       // 模块配置入口
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

* **macOS** (> 10.15)
* **iOS** (> 13.0)
* **Linux** (> 20)
* **Swift** (> 5.9)
* **watchOS** (> 6.0) **[未测试]**
* **tvOS**(> 13) **[未测试]**

-------

### 联系与反馈

如有使用问题或建议，请通过 [GitHub Issues](https://github.com/SJJC-Team/whooshing.toolbox-server/issues) 提交反馈。

或发至邮箱 [contact@official.whooshings.space](mailto:contact@official.whooshings.space)
