//
//  HelloCommand.swift
//  App
//
//  Created by Finer  Vine on 2020/6/24.
//

import Foundation
import Vapor

final class HelloCommand: Command {
        
    struct Signature: CommandSignature {
        /*
         swift run Run hello john
         # Hello john!
         */
        @Argument(name: "name", help: "The name to say hello")
        var name: String
        
        /*
         swift run Run hello john --greeting Hi
         # Hi john!
         */
        @Option(name: "greeting", short: "g", help: "Greeting used")
        var greeting: String?
        
        /*
         swift run Run hello john --greeting Hi --capitalized
         # Hi John!
         
         swift run Run hello john -g Szia -c
         # Szia John!
         */
        @Flag(name: "capitalize", short: "c", help: "Capitalizes the name")
        var capitalize: Bool
    }

    let help = "This command will say hello to a given name."

    func run(using context: CommandContext, signature: Signature) throws {
        let greeting = signature.greeting ?? "Hello"
        var name = signature.name
        if signature.capitalize {
            name = name.capitalized
        }
        print("\(greeting) \(name)!")
    }
}
