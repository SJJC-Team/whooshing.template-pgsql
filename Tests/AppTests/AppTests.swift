@testable import App
import VaporTesting
import Testing
import Fluent
import WhooshingServer

@Suite("App Tests with DB", .serialized)
struct AppTests {
    private func withApp(_ test: (Whooshing<Https>, Application) async throws -> ()) async throws {
        let woo = try await Whooshing.make(.testing(DebuggingParameters.httpsDebuggingData(dbServiceConfigs: Woo.dbServices))).get()
        do {
            try await Configuration.https(woo, app: woo.app)
            try await woo.app.autoMigrate()
            try await test(woo, woo.app)
            try await woo.app.autoRevert()
        } catch {
            try? await woo.app.autoRevert()
            try await woo.asyncShutdown().get()
            throw error
        }
        try await woo.asyncShutdown().get()
    }
    
    @Test("Test Hello World Route")
    func helloWorld() async throws {
        try await withApp { woo, app in
            try await app.testing().test(.GET, "hello", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Hello, world!")
            })
        }
    }
    
    @Test("Getting all the Users")
    func getAllUsers() async throws {
        try await withApp { woo, app in
            let sampleUsers = [User(email: "email1@example.com", age: 20), User(email: "email2@example.com", age: 21)]
            try await sampleUsers.create(on: app.db)
            
            try await app.testing().test(.GET, "users", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([UserDTO].self) == sampleUsers.map { $0.toDTO() } )
            })
        }
    }
    
    @Test("Creating a User")
    func createUser() async throws {
        let newDTO = UserDTO(email: "email1@example.com", age: 20)
        
        try await withApp { woo, app in
            try await app.testing().test(.POST, "users/register", beforeRequest: { req in
                try req.content.encode(newDTO)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let models = try await User.query(on: app.db).all()
                #expect(models.map({ $0.toDTO() }) == [newDTO])
            })
        }
    }
    
    @Test("Deleting a User")
    func deleteUser() async throws {
        let testUsers = [User(email: "email1@example.com", age: 20), User(email: "email2@example.com", age: 21)]
        
        try await withApp { woo, app in
            try await testUsers.create(on: app.db)
            
            try await app.testing().test(.DELETE, "users/\(testUsers[0].email)", afterResponse: { res async throws in
                #expect(res.status == .noContent)
                let userShouldNotExist = try await User.query(on: app.db).filter(\.$email == testUsers[0].email).first()
                #expect(userShouldNotExist == nil)
            })
        }
    }
}
