/**
 * Copyright IBM Corporation 2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import XCTest
import Foundation
import KituraContracts

@testable import Kitura
@testable import KituraNet

class TestCodableRouter: KituraTest {
    static var allTests: [(String, (TestCodableRouter) -> () throws -> Void)] {
        return [
            ("testBasicPost", testBasicPost),
            ("testBasicPostIdentifier", testBasicPostIdentifier),
            ("testBasicGet", testBasicGet),
            ("testBasicGetArray", testBasicGetArray),
            ("testBasicSingleGet", testBasicSingleGet),
            ("testBasicDelete", testBasicDelete),
            ("testBasicSingleDelete", testBasicSingleDelete),
            ("testBasicPut", testBasicPut),
            ("testBasicPatch", testBasicPatch),
            ("testJoinPath", testJoinPath),
            ("testRouteWithTrailingSlash", testRouteWithTrailingSlash),
            ("testRouteParameters", testRouteParameters),
            ("testCodablePutBodyParsing", testCodablePutBodyParsing),
            ("testCodablePatchBodyParsing", testCodablePatchBodyParsing),
            ("testCodablePostBodyParsing", testCodablePostBodyParsing),
            ("testCodableGetQueryParameters", testCodableGetQueryParameters),
            ("testCodableDeleteQueryParameters", testCodableDeleteQueryParameters)
        ]
    }

    // Need to initialise to avoid compiler error
    var router = Router()
    var userStore: [Int: User] = [:]

    // Reset for each test
    override func setUp() {
        router = Router()
        userStore = [1: User(id: 1, name: "Mike"), 2: User(id: 2, name: "Chris"), 3: User(id: 3, name: "Ricardo")]
    }

    struct User: Codable {
        let id: Int
        let name: String

        init(id: Int, name: String) {
            self.id = id
            self.name = name
        }
    }

    struct OptionalUser: Codable {
        let id: Int?
        let name: String?

        init(id: Int?, name: String?) {
            self.id = id
            self.name = name
        }
    }

    struct Status: Codable {
        let description: String
        init(_ desc: String) {
            description = desc
        }
    }

    struct MyQuery: Query, Equatable {
        public let intField: Int
        public let optionalIntField: Int?
        public let stringField: String
        public let intArray: [Int]
        public let dateField: Date
        public let optionalDateField: Date?
        public let nested: Nested

        public static func ==(lhs: MyQuery, rhs: MyQuery) -> Bool {
            return  lhs.intField == rhs.intField &&
                lhs.optionalIntField == rhs.optionalIntField &&
                lhs.stringField == rhs.stringField &&
                lhs.intArray == rhs.intArray &&
                lhs.dateField.timeIntervalSince1970 == rhs.dateField.timeIntervalSince1970 &&
                lhs.optionalDateField?.timeIntervalSince1970 == rhs.optionalDateField?.timeIntervalSince1970 &&
                lhs.nested == rhs.nested
        }
    }

    struct Nested: Codable, Equatable {
        public let nestedIntField: Int
        public let nestedStringField: String

        public static func ==(lhs: Nested, rhs: Nested) -> Bool {
            return lhs.nestedIntField == rhs.nestedIntField && lhs.nestedStringField == rhs.nestedStringField
        }
    }

    func testBasicPost() {
        router.post("/users") { (user: User, respondWith: (User?, RequestError?) -> Void) in
            print("POST on /users for user \(user)")
            self.userStore[user.id] = user
            respondWith(user, nil)
        }

        performServerTest(router, timeout: 30) { expectation in
            let expectedUser = User(id: 4, name: "David")
            guard let userData = try? JSONEncoder().encode(expectedUser) else {
                XCTFail("Could not generate user data from string!")
                return
            }

            self.performRequest("post", path: "/users", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssert(response.headers.contains { (key: String, value: [String]) in return key == "Content-Type" && value.contains("application/json") })
                XCTAssertEqual(response.statusCode, HTTPStatusCode.created, "HTTP Status code was \(String(describing: response.statusCode))")
                var data = Data()
                guard let length = try? response.readAllData(into: &data) else {
                    XCTFail("Error reading response length!")
                    return
                }

                XCTAssert(length > 0, "Expected some bytes, received \(String(describing: length)) bytes.")
                    guard let user = try? JSONDecoder().decode(User.self, from: data) else {
                    XCTFail("Could not decode response! Expected response decodable to User, but got \(String(describing: String(data: data, encoding: .utf8)))")
                    return
                }

                // Validate the data we got back from the server
                XCTAssertEqual(user.name, expectedUser.name)
                XCTAssertEqual(user.id, expectedUser.id)

                expectation.fulfill()
            }, requestModifier: { request in
                request.headers["Content-Type"] = "application/json; charset=utf-8"
                request.write(from: userData)
            })
        }
    }

    func testBasicPostIdentifier() {
        router.post("/users") { (user: User, respondWith: (Int?, User?, RequestError?) -> Void) in
            print("POST on /users for user \(user)")
            self.userStore[user.id] = user
            respondWith(user.id, user, nil)
        }

        performServerTest(router, timeout: 30) { expectation in
            let expectedUser = User(id: 4, name: "David")
            guard let userData = try? JSONEncoder().encode(expectedUser) else {
                XCTFail("Could not generate user data from string!")
                return
            }

            self.performRequest("post", path: "/users", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssert(response.headers.contains { (key: String, value: [String]) in return key == "Content-Type" && value.contains("application/json") })
                XCTAssertEqual(response.statusCode, HTTPStatusCode.created, "HTTP Status code was \(String(describing: response.statusCode))")
                var data = Data()
                guard let length = try? response.readAllData(into: &data) else {
                    XCTFail("Error reading response length!")
                    return
                }

                XCTAssert(length > 0, "Expected some bytes, received \(String(describing: length)) bytes.")
                guard let user = try? JSONDecoder().decode(User.self, from: data) else {
                    XCTFail("Could not decode response! Expected response decodable to User, but got \(String(describing: String(data: data, encoding: .utf8)))")
                    return
                }

                guard let location = response.headers["Location"] else {
                    XCTFail("Could not find Location header. Expected Location header to be set to the created User id.")
                    return
                }
                XCTAssertEqual(location[0], String(expectedUser.id))

                // Validate the data we got back from the server
                XCTAssertEqual(user.name, expectedUser.name)
                XCTAssertEqual(user.id, expectedUser.id)

                expectation.fulfill()
            }, requestModifier: { request in
                request.headers["Content-Type"] = "application/json; charset=utf-8"
                request.write(from: userData)
            })
        }
    }

    func testBasicGet() {
        router.get("/status") { (respondWith: (Status?, RequestError?) -> Void) in
            print("GET on /status")

            respondWith(Status("GOOD"), nil)
        }

        performServerTest(router, timeout: 30) { expectation in
            let expectedStatus = Status("GOOD")

            self.performRequest("get", path: "/status", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssert(response.headers.contains { (key: String, value: [String]) in return key == "Content-Type" && value.contains("application/json") })
                XCTAssertEqual(response.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response.statusCode))")
                var data = Data()
                guard let length = try? response.readAllData(into: &data) else {
                    XCTFail("Error reading response length!")
                    return
                }

                XCTAssert(length > 0, "Expected some bytes, received \(String(describing: length)) bytes.")
                guard let status = try? JSONDecoder().decode(Status.self, from: data) else {
                    XCTFail("Could not decode response! Expected response decodable to a Status object, but got \(String(describing: String(data: data, encoding: .utf8)))")
                    return
                }
                // Validate the data we got back from the server
                XCTAssertEqual(status.description, expectedStatus.description)

                expectation.fulfill()
            })
        }
    }

    func testBasicGetArray() {
        router.get("/users") { (respondWith: ([User]?, RequestError?) -> Void) in
            print("GET on /users")

            respondWith(self.userStore.map({ $0.value }), nil)
        }

        performServerTest(router, timeout: 30) { expectation in
            let expectedUsers = self.userStore.map({ $0.value }) // TODO: Write these out explicitly?

            self.performRequest("get", path: "/users", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssert(response.headers.contains { (key: String, value: [String]) in return key == "Content-Type" && value.contains("application/json") })
                XCTAssertEqual(response.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response.statusCode))")
                var data = Data()
                guard let length = try? response.readAllData(into: &data) else {
                    XCTFail("Error reading response length!")
                    return
                }

                XCTAssert(length > 0, "Expected some bytes, received \(String(describing: length)) bytes.")
                guard let users = try? JSONDecoder().decode([User].self, from: data) else {
                    XCTFail("Could not decode response! Expected response decodable to array of Users, but got \(String(describing: String(data: data, encoding: .utf8)))")
                    return
                }

                // Validate the data we got back from the server
                for (index, user) in users.enumerated() {
                    XCTAssertEqual(user.id, expectedUsers[index].id)
                    XCTAssertEqual(user.name, expectedUsers[index].name)
                }

                expectation.fulfill()
            })
        }
    }

    func testBasicSingleGet() {
        router.get("/users") { (id: Int, respondWith: (User?, RequestError?) -> Void) in
            print("GET on /users")
            guard let user = self.userStore[id] else {
                XCTFail("ERROR!!! Couldn't find user with id \(id)")
                respondWith(nil, .notFound)
                return
            }
            respondWith(user, nil)
        }

        performServerTest(router, timeout: 30) { expectation in
            guard let expectedUser = self.userStore[1] else {
                XCTFail("ERROR!!! Couldn't find user with id 1")
                return
            }

            self.performRequest("get", path: "/users/1", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssert(response.headers.contains { (key: String, value: [String]) in return key == "Content-Type" && value.contains("application/json") })
                XCTAssertEqual(response.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response.statusCode))")
                var data = Data()
                guard let length = try? response.readAllData(into: &data) else {
                    XCTFail("Error reading response length!")
                    return
                }

                XCTAssert(length > 0, "Expected some bytes, received \(String(describing: length)) bytes.")
                guard let user = try? JSONDecoder().decode(User.self, from: data) else {
                    XCTFail("Could not decode response! Expected response decodable to array of Users, but got \(String(describing: String(data: data, encoding: .utf8)))")
                    return
                }

                // Validate the data we got back from the server
                XCTAssertEqual(user.id, expectedUser.id)
                XCTAssertEqual(user.name, expectedUser.name)

                expectation.fulfill()
            })
        }
    }

    func testBasicDelete() {

        router.delete("/users") { (respondWith: (RequestError?) -> Void) in
            self.userStore.removeAll()
            respondWith(nil)
        }

        performServerTest(router, timeout: 30) { expectation in

            self.performRequest("delete", path: "/users", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssertEqual(response.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response.statusCode))")
                var data = Data()
                guard let length = try? response.readAllData(into: &data) else {
                    XCTFail("Error reading response length!")
                    return
                }

                XCTAssert(length == 0, "Expected zero bytes, received \(String(describing: length)) bytes.")

                expectation.fulfill()
            })
        }
    }

    func testBasicSingleDelete() {

        router.delete("/users") { (id: Int, respondWith: (RequestError?) -> Void) in
            guard let _ = self.userStore.removeValue(forKey: id) else {
                respondWith(.notFound)
                return
            }
            respondWith(nil)
        }

        performServerTest(router, timeout: 30) { expectation in

            self.performRequest("delete", path: "/users/1", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssertEqual(response.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response.statusCode))")
                var data = Data()
                guard let length = try? response.readAllData(into: &data) else {
                    XCTFail("Error reading response length!")
                    return
                }

                XCTAssert(length == 0, "Expected zero bytes, received \(String(describing: length)) bytes.")

                expectation.fulfill()
            })
        }
    }

    func testBasicPut() {

        router.put("/users") { (id: Int, user: User, respondWith: (User?, RequestError?) -> Void) in
            self.userStore[id] = user
            respondWith(user, nil)
        }

        performServerTest(router, timeout: 30) { expectation in
            // Let's create a User instance
            let expectedUser = User(id: 1, name: "David")
            // Create JSON representation of User instance
            guard let userData = try? JSONEncoder().encode(expectedUser) else {
                XCTFail("Could not generate user data from string!")
                return
            }

            self.performRequest("put", path: "/users/1", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssert(response.headers.contains { (key: String, value: [String]) in return key == "Content-Type" && value.contains("application/json") })
                XCTAssertEqual(response.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response.statusCode))")
                var data = Data()
                guard let length = try? response.readAllData(into: &data) else {
                    XCTFail("Error reading response length!")
                    return
                }

                XCTAssert(length > 0, "Expected some bytes, received \(String(describing: length)) bytes.")
                guard let user = try? JSONDecoder().decode(User.self, from: data) else {
                    XCTFail("Could not decode response! Expected response decodable to User, but got \(String(describing: String(data: data, encoding: .utf8)))")
                    return
                }

                // Validate the data we got back from the server
                XCTAssertEqual(user.name, expectedUser.name)
                XCTAssertEqual(user.id, expectedUser.id)

                expectation.fulfill()
            }, requestModifier: { request in
                request.headers["Content-Type"] = "application/json; charset=utf-8"
                request.write(from: userData)
            })
        }
    }

    func testBasicPatch() {

        router.patch("/users") { (id: Int, patchUser: OptionalUser, respondWith: (User?, RequestError?) -> Void) -> Void in
            guard let existingUser = self.userStore[id] else {
                respondWith(nil, .notFound)
                return
            }
            if let patchUserName = patchUser.name {
                let updatedUser = User(id: id, name: patchUserName)
                self.userStore[id] = updatedUser
                respondWith(updatedUser, nil)
            } else {
                respondWith(existingUser, nil)
            }
        }

        performServerTest(router, timeout: 30) { expectation in
            // Let's create a User instance
            let patchUser = User(id: 2, name: "David")
            // Create JSON representation of User instance
            guard let userData = try? JSONEncoder().encode(patchUser) else {
                XCTFail("Could not generate user data from string!")
                return
            }

            self.performRequest("patch", path: "/users/2", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssert(response.headers.contains { (key: String, value: [String]) in return key == "Content-Type" && value.contains("application/json") })
                XCTAssertEqual(response.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response.statusCode))")
                var data = Data()
                guard let length = try? response.readAllData(into: &data) else {
                    XCTFail("Error reading response length!")
                    return
                }

                XCTAssert(length > 0, "Expected some bytes, received \(String(describing: length)) bytes.")
                guard let user = try? JSONDecoder().decode(User.self, from: data) else {
                    XCTFail("Could not decode response! Expected response decodable to User, but got \(String(describing: String(data: data, encoding: .utf8)))")
                    return
                }

                // Validate the data we got back from the server
                XCTAssertEqual(user.name, patchUser.name)
                XCTAssertEqual(user.id, 2)

                expectation.fulfill()
            }, requestModifier: { request in
                request.headers["Content-Type"] = "application/json; charset=utf-8"
                request.write(from: userData)
            })
        }
    }

    func testJoinPath() {
        let router = Router()
        XCTAssertEqual(router.join(path: "a", with: "b"), "a/b")
        XCTAssertEqual(router.join(path: "a/", with: "/b"), "a/b")
        XCTAssertEqual(router.join(path: "a", with: "/b"), "a/b")
        XCTAssertEqual(router.join(path: "a/", with: "b"), "a/b")
    }

    func testRouteWithTrailingSlash() {
        router.get("/users/") { (id: Int, respondWith: (User?, RequestError?) -> Void) in
            // Returning an error that's not .notFound so we know this route has been hit
            respondWith(nil, .conflict)
        }
        performServerTest(router, timeout: 30) { expectation in
            self.performRequest("get", path: "/users/1", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssertEqual(response.statusCode, HTTPStatusCode.conflict, "Expected the '/users' route to be executed even though we passed '/users/'")

                expectation.fulfill()
            })
        }
    }

    func testRouteParameters() {
        //Add this erroneous route which should not be hit by the test, should log an error but we can't test the log so we checkout for a 404 not found.
        router.get("/users/:id") { (id: Int, respondWith: (User?, RequestError?) -> Void) in
            print("GET on /users")
            //Returning an error that's not .notFound so the test will fail in a timely manner if this route is hit
            respondWith(nil, .conflict)
        }

        performServerTest(router, timeout: 30) { expectation in
            self.performRequest("get", path: "/users/1", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssertEqual(response.statusCode, HTTPStatusCode.notFound, "HTTP Status code was \(String(describing: response.statusCode))")

                expectation.fulfill()
            })
        }
    }

    func testCodablePutBodyParsing() {
        router.all(middleware: BodyParser())
        router.put("/users") { (id: Int, user: User, respondWith: (User?, RequestError?) -> Void) in
            print("POST on /users for user \(user)")
            // Let's keep the test simple
            // We just want to test that we can register a handler that
            // receives and sends back a Codable instance
            self.userStore[user.id] = user
            respondWith(user, nil)
        }

        performServerTest(router, timeout: 30) { expectation in
            // Let's create a User instance
            let expectedUser = User(id: 4, name: "David")
            // Create JSON representation of User instance
            guard let userData = try? JSONEncoder().encode(expectedUser) else {
                XCTFail("Could not generate user data from string!")
                return
            }

            self.performRequest("put", path: "/users/2", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssertEqual(response.statusCode, HTTPStatusCode.internalServerError, "HTTP Status code was \(String(describing: response.statusCode))")

                expectation.fulfill()
            }, requestModifier: { request in
                request.headers["Content-Type"] = "application/json; charset=utf-8"
                request.write(from: userData)
            })
        }
    }

    func testCodablePatchBodyParsing() {
        router.all(middleware: BodyParser())

        router.patch("/users") { (id: Int, patchUser: OptionalUser, respondWith: (User?, RequestError?) -> Void) -> Void in
            guard let existingUser = self.userStore[id] else {
                respondWith(nil, .notFound)
                return
            }
            if let patchUserName = patchUser.name {
                let updatedUser = User(id: id, name: patchUserName)
                self.userStore[id] = updatedUser
                respondWith(updatedUser, nil)
            } else {
                respondWith(existingUser, nil)
            }
        }

        performServerTest(router, timeout: 30) { expectation in
            // Let's create a User instance
            let patchUser = User(id: 2, name: "David")
            // Create JSON representation of User instance
            guard let userData = try? JSONEncoder().encode(patchUser) else {
                XCTFail("Could not generate user data from string!")
                return
            }

            self.performRequest("patch", path: "/users/2", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssertEqual(response.statusCode, HTTPStatusCode.internalServerError, "HTTP Status code was \(String(describing: response.statusCode))")

                expectation.fulfill()
            }, requestModifier: { request in
                request.headers["Content-Type"] = "application/json; charset=utf-8"
                request.write(from: userData)
            })
        }
    }

    func testCodablePostBodyParsing() {
        router.all(middleware: BodyParser())

        router.post("/users") { (user: User, respondWith: (User?, RequestError?) -> Void) in
            print("POST on /users for user \(user)")
            // Let's keep the test simple
            // We just want to test that we can register a handler that
            // receives and sends back a Codable instance
            self.userStore[user.id] = user
            respondWith(user, nil)
        }

        performServerTest(router, timeout: 30) { expectation in
            // Let's create a User instance
            let expectedUser = User(id: 4, name: "David")
            // Create JSON representation of User instance
            guard let userData = try? JSONEncoder().encode(expectedUser) else {
                XCTFail("Could not generate user data from string!")
                return
            }

            self.performRequest("post", path: "/users", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                XCTAssertEqual(response.statusCode, HTTPStatusCode.internalServerError, "HTTP Status code was \(String(describing: response.statusCode))")

                expectation.fulfill()
            }, requestModifier: { request in
                request.headers["Content-Type"] = "application/json; charset=utf-8"
                request.write(from: userData)
            })
        }
    }

    func testCodableGetQueryParameters() {

        /// Currently the milliseconds are cut off by our date formatter
        /// This synchronizes it for testing with the codable route
        let date: Date = Coder().dateFormatter.date(from: Coder().dateFormatter.string(from: Date()))!

        let expectedQuery = MyQuery(intField: 23, optionalIntField: nil, stringField: "a string", intArray: [1, 2, 3], dateField: date, optionalDateField: date, nested: Nested(nestedIntField: 333, nestedStringField: "nested string"))

        guard let queryStr: String = try? QueryEncoder().encode(expectedQuery) else {
            XCTFail("ERROR!!! Could not encode query object to string")
            return
        }

        router.get("/query") { (query: MyQuery, respondWith: ([MyQuery]?, RequestError?) -> Void) in
            XCTAssertEqual(query, expectedQuery)
            respondWith([query], nil)
        }

        performServerTest(router, timeout: 20, asyncTasks: { expectation in
            self.performRequest("get", path: "/query\(queryStr)", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }

                var data = Data()
                guard let length = try? response.readAllData(into: &data) else {
                    XCTFail("Error reading response length!")
                    return
                }

                XCTAssert(length > 0, "Expected some bytes, received \(String(describing: length)) bytes.")

                guard let myQuery = try? JSONDecoder().decode([MyQuery].self, from: data) else {
                    XCTFail("Could not decode response! Expected response decodable to MyQuery, but got \(String(describing: String(data: data, encoding: .utf8)))")
                    return
                }
                XCTAssertEqual(myQuery, [expectedQuery])
                XCTAssert(response.headers.contains { (key: String, value: [String]) in return key == "Content-Type" && value.contains("application/json") })
                XCTAssertEqual(response.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response.statusCode))")
                expectation.fulfill()
            })
      }, { expectation in
          self.performRequest("get", path: "/query?param=badRequest", callback: { response in
              guard let response = response else {
                  XCTFail("ERROR!!! ClientRequest response object was nil")
                  return
              }
              XCTAssertEqual(response.statusCode, HTTPStatusCode.badRequest, "HTTP Status code was \(String(describing: response.statusCode))")
              expectation.fulfill()
          })
        })
    }

    func testCodableDeleteQueryParameters() {

        /// Currently the milliseconds are cut off by our date formatter
        /// This synchronizes it for testing with the codable route
        let date: Date = Coder().dateFormatter.date(from: Coder().dateFormatter.string(from: Date()))!

        let expectedQuery = MyQuery(intField: 23, optionalIntField: nil, stringField: "a string", intArray: [1, 2, 3], dateField: date, optionalDateField: date, nested: Nested(nestedIntField: 333, nestedStringField: "nested string"))

        guard let queryStr: String = try? QueryEncoder().encode(expectedQuery) else {
            XCTFail("ERROR!!! Could not encode query object to string")
            return
        }

        router.delete("/query") { (query: MyQuery, respondWith: (RequestError?) -> Void) in
            XCTAssertEqual(query, expectedQuery)
            respondWith(nil)
        }

        performServerTest(router, timeout: 20, asyncTasks: { expectation in
            self.performRequest("delete", path: "/query\(queryStr)", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }
                XCTAssertEqual(response.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response.statusCode))")
                expectation.fulfill()
            })
        },{ expectation in
            self.performRequest("delete", path: "/query?param=badRequest", callback: { response in
                guard let response = response else {
                    XCTFail("ERROR!!! ClientRequest response object was nil")
                    return
                }
                XCTAssertEqual(response.statusCode, HTTPStatusCode.badRequest, "HTTP Status code was \(String(describing: response.statusCode))")
                expectation.fulfill()
            })
        })
    }
}
