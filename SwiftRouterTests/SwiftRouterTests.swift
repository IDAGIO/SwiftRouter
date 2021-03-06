//
//  SwiftRouterTests.swift
//  SwiftRouterTests
//
//  Created by skyline on 15/9/24.
//  Copyright © 2015年 skyline. All rights reserved.
//

import XCTest
@testable import SwiftRouter

class SwiftRouterTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testRouteController() {
        let router = Router.sharedInstance
        router.map("/", controllerClass: AboutViewController.self)
        router.map("/about", controllerClass: AboutViewController.self)
        router.map("/user/:userId", controllerClass: UserViewController.self)
        router.map("/story/:storyId", controllerClass: StoryViewController.self)
        router.map("/user/:userId/story", controllerClass: StoryListViewController.self)

        router.map("/anotherScreenFromStoryboard/:identifier", controllerClass: StoryboardViewController.self)
        
        XCTAssertTrue(router.matchController("/")!.isKindOfClass(AboutViewController.self))
        XCTAssertTrue(router.matchController("/about")!.isKindOfClass(AboutViewController.self))
        XCTAssertTrue(router.matchController("/user/1/?username=hello")!.isKindOfClass(UserViewController.self))
        XCTAssertTrue(router.matchController("/user/1/?username=hello&foo")!.isKindOfClass(UserViewController.self))
        XCTAssertTrue(router.matchController("/user/1")!.isKindOfClass( UserViewController.self))
        XCTAssertTrue(router.matchController("/story/2")!.isKindOfClass( StoryViewController.self))
        XCTAssertTrue(router.matchController("/user/2/story")!.isKindOfClass( StoryListViewController.self))
        XCTAssertTrue(router.matchController("/anotherScreenFromStoryboard/1010")!.isKindOfClass( StoryboardViewController.self))
        
        let vc = router.matchController("/user/1?username=hello&password=123") as! UserViewController
        XCTAssertEqual(vc.userId, "1")
        XCTAssertEqual(vc.username, "hello")
        XCTAssertEqual(vc.password, "123")
        
        let vc2 = router.matchController("/user/1?password=234#username=hello&password=123&foo") as! UserViewController
        XCTAssertEqual(vc2.userId, "1")
        XCTAssertEqual(vc2.username, "hello")
        XCTAssertEqual(vc2.password, "234") // overwritten by querystring
        
        let storyboardController = router.matchControllerFromStoryboard("/anotherScreenFromStoryboard/1010", storyboardName: "MyStoryboard") as! StoryboardViewController
        XCTAssertEqual(storyboardController.identifier, "1010")
        // Test user defined runtime attribute value (set in storyboard)
        XCTAssertEqual(storyboardController.valueDefinedInStoryboard, "Just testing")
        
        let storyboardController2 = router.matchControllerFromStoryboard("/anotherScreenFromStoryboard/1010") as! StoryboardViewController
        XCTAssertEqual(storyboardController2.valueDefinedInStoryboard, "Default storyboard text")
    }
    
    func testRouteHandler() {
        let router = Router.sharedInstance
        router.map("/user/add", handler: { (params:[String: String]?) -> (Bool) in
            XCTAssertNotNil(params)
            if let params = params {
                XCTAssertEqual(params["username"], "hello")
                XCTAssertEqual(params["password"], "123")
            }
            return true
        })
        
        let handler = router.matchHandler("/user/add")
        XCTAssertNotNil(handler)
        
        let success = router.routeURL("/user/add?username=hello&password=123")
        XCTAssertTrue(success)
        
        let failed = router.routeURL("/unknown")
        XCTAssertFalse(failed)
    }
    
    func testRemoveAllHandlers() {
        let router = Router.sharedInstance
        router.map("/user/:userId", controllerClass: UserViewController.self)
        XCTAssertTrue(router.matchController("/user/1")!.isKindOfClass( UserViewController.self))

        router.removeAllRoutes()
        XCTAssertNil(router.matchController("/user/1"))
    }
}
