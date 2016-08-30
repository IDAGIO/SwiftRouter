//
//  SwiftRouter.swift
//  Swift-Playground
//
//  Created by skyline on 15/9/23.
//  Copyright © 2015年 skyline. All rights reserved.
//

import Foundation
import UIKit

var appUrlSchemes:[String] = {
    if let info:[String:AnyObject] = Bundle.main.infoDictionary as? [String: AnyObject] {
        var schemes = [String]()
        if let url = info["CFBundleURLTypes"] as? [[String:AnyObject]]? , url != nil {
            for d in url! {
                if let scheme = d["CFBundleURLSchemes"]?[0] as? String{
                    schemes.append(scheme)
                }
            }
        }
        return schemes
    }
    return []
}()

enum RouterError:Error {
    case schemeNotRecognized
    case entryAlreayExisted
    case invalidRouteEntry
    func message() -> String {
        switch (self) {
        case .schemeNotRecognized:
            return "SchemeNotRecognized"
        case .entryAlreayExisted:
            return "EntryAlreayExisted"
        case .invalidRouteEntry:
            return "InvalidRouteEntry"
        }
    }
}

class RouteEntry {
    var pattern: String? = nil
    var handler: (([String:String]?) -> Bool)? = nil
    var klass: AnyClass? = nil
    
    init(pattern:String?, cls: AnyClass?=nil, handler:((_ params: [String:String]?) -> Bool)?=nil) {
        self.pattern = pattern
        self.klass = cls
        self.handler = handler
    }
}

extension RouteEntry: Swift.CustomStringConvertible, Swift.CustomDebugStringConvertible {
    internal var description: String {
        let empty = ""
        if let k = self.klass {
            return "\(self.pattern ?? empty) -> \(k)"
        }
        if let h = self.handler {
            return "\(self.pattern ?? empty) -> \(h)"
        }
        fatalError(RouterError.invalidRouteEntry.message())
    }
    
    internal var debugDescription: String {
        return description
    }
}

extension String {
    func stringByFilterAppSchemes() -> String {
        for scheme in appUrlSchemes {
            if self.hasPrefix(scheme + ":") {
                return self.substring(from: self.characters.index(self.startIndex, offsetBy: (scheme.characters.count + 2)))
            }
        }
        return self
    }
}

open class Router {
    open static let sharedInstance = Router()
    
    fileprivate let kRouteEntryKey = "_entry"
    
    fileprivate var routeMap = NSMutableDictionary()

    open func map(_ route: String, controllerClass: AnyClass) {
        self.doMap(route, cls: controllerClass)
    }
    
    open func map(_ route: String, handler:(([String:String]?) -> (Bool))?) {
        self.doMap(route, handler: handler)
    }
    
    internal func doMap(_ route: String, cls: AnyClass?=nil, handler:(([String:String]?) -> (Bool))?=nil) -> Void {
        var r = RouteEntry(pattern: "/", cls: nil)
        if let k = cls {
            r = RouteEntry(pattern: route, cls: k)
        } else {
            r = RouteEntry(pattern: route, handler: handler)
        }
        let pathComponents = self.pathComponentsInRoute(route)
        self.insertRoute(pathComponents, entry: r, subRoutes: self.routeMap)
    }
    
    fileprivate func insertRoute(_ pathComponents: [String], entry: RouteEntry, subRoutes: NSMutableDictionary, index: Int = 0){

        if index >= pathComponents.count {
            fatalError(RouterError.entryAlreayExisted.message())
        }
        let pathComponent = pathComponents[index]
        if subRoutes[pathComponent] == nil {
            if pathComponent == pathComponents.last {
                subRoutes[pathComponent] = NSMutableDictionary(dictionary: [kRouteEntryKey: entry])
                print("Adding Route: \(entry.description)")
                return
            }
            subRoutes[pathComponent] = NSMutableDictionary()
        }
        // recursive
        self.insertRoute(pathComponents, entry: entry, subRoutes: subRoutes[pathComponent] as! NSMutableDictionary, index: index+1)
    }
    
    
    open func matchController(_ route: String) -> AnyObject? {
        var params = self.paramsInRoute(route)
        if let entry = self.findRouteEntry(route, params: &params) {
            let name = NSStringFromClass(entry.klass!)
            let clz = NSClassFromString(name) as! NSObject.Type
            let instance = clz.init()
            instance.setValuesForKeys(params)
            return instance
        }
        return nil;
    }
    
    open func matchControllerFromStoryboard(_ route: String, storyboardName: String = "Storyboard") -> AnyObject? {
        var params = self.paramsInRoute(route)
        if let entry = self.findRouteEntry(route, params: &params) {
            let name = NSStringFromClass(entry.klass!)
            let clz = NSClassFromString(name) as! NSObject.Type
            let storyboard = UIStoryboard(name: storyboardName, bundle: Bundle(for: clz))
            let controllerIdentifier = name.components(separatedBy: ".").last!
            let instance = storyboard.instantiateViewController(withIdentifier: controllerIdentifier)
            instance.setValuesForKeys(params)
            return instance
        }
        return nil;
    }
    
    open func matchHandler(_ route: String) -> (([String:String]?) -> (Bool))? {
        var a = [String:String]()
        if let entry = self.findRouteEntry(route, params: &a) {
            return entry.handler
        }
        return nil
    }
    
    func findRouteEntry(_ route: String, params:inout [String:String]) -> RouteEntry? {
        let pathComponents = self.pathComponentsInRoute(route.stringByFilterAppSchemes())
        
        var subRoutes = self.routeMap
        for pathComponent in pathComponents {
            for (k, v) in subRoutes {
                // match handler first
                if subRoutes[pathComponent] != nil {
                    if pathComponent == pathComponents.last {
                        let d = subRoutes[pathComponent] as! NSMutableDictionary
                        let entry = d["_entry"] as! RouteEntry
                        return entry
                    }
                    subRoutes = subRoutes[pathComponent] as! NSMutableDictionary
                    break
                }
                if let s = k as? String, s.hasPrefix(":") {
                    let key = s.substring(from: s.characters.index(s.startIndex, offsetBy: 1))
                    params[key] = pathComponent
                    if let dict = v as? NSMutableDictionary, pathComponent == pathComponents.last {
                        return dict[kRouteEntryKey] as? RouteEntry
                    }
                    subRoutes = subRoutes[s] as! NSMutableDictionary
                    break
                } else {
                    print(RouterError.schemeNotRecognized.message())
                    return nil
                }
            }
        }
        return nil
    }
    
    func paramsInRoute(_ route: String) -> [String: String] {

        var params = [String:String]()
        self.findRouteEntry(route.stringByFilterAppSchemes(), params: &params)

        var path = route

        if let loc = path.range(of: "#") {
            for (key, value) in paramsFromQuery(path.substring(from: path.index(after: loc.lowerBound))) {
                params[key] = value
            }
            path = path.substring(to: loc.lowerBound)
        }

        if let loc = path.range(of: "?") {
            for (key, value) in paramsFromQuery(path.substring(from: path.index(after: loc.lowerBound))) {
                params[key] = value
            }
        }

        return params
    }

    fileprivate func paramsFromQuery(_ query: String) -> [String:String] {
        var params = [String:String]()
        let paramArray = query.components(separatedBy: "&")
        for param in paramArray {
            let kv = param.components(separatedBy: "=")
            if kv.count >= 2 {
                let k = kv[0]
                let v = kv[1]
                params[k] = v
            }
        }
        return params
    }
    
    func pathComponentsInRoute(_ route: String) -> [String] {
        var path:NSString = NSString(string: route)
        if let loc = route.range(of: "#") {
            path = NSString(string: route.substring(to: loc.lowerBound))
        }
        if let loc = route.range(of: "?") {
            path = NSString(string: route.substring(to: loc.lowerBound))
        }
        var result = [String]()
        for (index, pathComponent) in path.pathComponents.enumerated() {
            if index > 0 && pathComponent == "/" { // don't ignore the leading `/` in order to support root matching
                continue
            }
            result.append(pathComponent)
        }
        return result
    }
    
    open func removeAllRoutes() {
        self.routeMap.removeAllObjects()
    }
    
    open func routeURL(_ route:String) -> Bool {
        if let handler = self.matchHandler(route) {
            let params = self.paramsInRoute(route)
            return handler(params)
        }
        return false
    }

    open func routeURL(_ route:String, navigationController: UINavigationController) -> Bool {
        if let vc = self.matchController(route) {
            navigationController.pushViewController(vc as! UIViewController, animated: true)
            return true
        }
        return false
    }
}
