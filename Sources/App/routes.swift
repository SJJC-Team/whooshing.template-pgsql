import Vapor
import WhooshingServer
import Fluent

func routes<T>(_ woo: Whooshing<T>, _ app: Application) throws where T: ServiceType {
    app.get { req async in
        "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    app.get("user") { req -> UserDTO in
        let email = try req.query.decode(UserEmailDTO.self)
        guard let user = try await User.query(on: req.db).filter(\.$email == email.email).first() else {
            throw Abort(.badRequest, reason: "用户不存在")
        }
        return UserDTO(email: user.email, age: user.age)
    }
    
    app.post("register") { req async throws -> String in
        let userDTO = try req.content.decode(UserDTO.self)
        let user = User(email: userDTO.email, age: userDTO.age)
        try await user.save(on: req.db)
        return "Registered"
    }
}
