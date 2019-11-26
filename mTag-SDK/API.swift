//
//  API.swift
//  mTag-SDK
//
//Copyright 2018 Blue Bite LLC.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//
//  Created by Sam Krantz on 11/17/17.
//  Copyright © 2017 Blue Bite LLC. All rights reserved.
//

import Alamofire
import Foundation

/**
 Class handles verifying, parsing, registering, and passing results back for Interactions
 registered with the mTag-SDK.
 */
open class API: NSObject {

  // MARK: CONSTANTS
  // Num parts in a SMT auth url
  static let SMT_COUNTER_SEGMENTS: Int = 5
  // length of a base 10 format mTag ID
  static let MTAG_ID_B10_LENGTH: Int = 8
  // length of a base 36 format mTag ID
  static let MTAG_ID_B36_LENGTH: Int = 6
  // length of tech prefix affixed to mTag ID
  static let TECH_PREFIX: Int = 1

  public static var delegate: BlueBiteInteractionDelegate?

  // user-accessible constant to enable debug output
  public static var enableDebug: Bool = false

  // user-accessible flag to enable overwriting Alamofire's default User-Agent
  public static var overrideUserAgent: Bool = false

  // user-accessible flag to enable overwriting the request's cookie.
  // mostly included for compatibility with Decode
  public static var overrideHeaderCookie: Bool = false

  /**
   Simple logger to prevent extra noise during production.
   */
  class func _log(_ message: String, level: String = "DEFAULT") {
    if level == "DEBUG" && !enableDebug {
      return
    }
    print("\(level) API: \(message)")
  }

  /**
   Function receives a URL, passes it to be parsed into request parameters, and submits it to the BlueBite API.
   - parameter withUrl url: The url to be parsed and submitted.
   */
  open class func interactionWasReceived(withUrl url: String) {
    _log("Interaction was received with URL: \(url)", level: "DEBUG")
    let urlParts = url.components(separatedBy: "/")

    // if we have a url with a < 6 length slug we can pass the whole url to the interaction
    if let slug: String = String(url.split(separator: "?")[0].split(separator: "/").last!) {
      if slug.count < MTAG_ID_B36_LENGTH {
        return registerInteraction(withUrl: url)
      }
    }

    // make sure the URL has a mTag ID or at least something that looks like an mTag ID
    guard let mTagId = parseIdFrom(url: url) else {
      _log("Unable to parse mTag ID from url: \(url)", level: "ERROR")
      delegate?.didFailToReceiveInteractionData("Unable to parse mTag Id from url \(url).")
      return
    }

    var params: [String: String] = [:]

    if urlParts.count == SMT_COUNTER_SEGMENTS {  // counter url
      params = handleCounterUrl(withUrlParts: urlParts)
    }
    else if urlParts.last!.contains("&") {  // it's either an HID or an auth url
      if urlParts.last!.contains("&sig") {
        params = handleAuthUrl(withUrlParts: urlParts)
      }
      else if urlParts.last!.contains("&tac") {
        params = handleHidUrl(withUrlParts: urlParts)
      }
      else { // some other formatting we don't know about
        delegate?.didFailToReceiveInteractionData("Unknown URL structure: \(url)")
        return
      }
    }
    else {
      // Simple mTag url (https:// mtag.io/nxyz123), fall through since we have mTag ID already
      _log("Handling Simple Url", level: "DEBUG")
    }
    registerInteraction(withTagId: mTagId, andParams: params)
  }

  /**
   Parses the mTag ID from the provided URL.
   - parameter url: URL to parse the mTag ID from.
   - Returns: mTag ID as String, or nil.
   */
  class func parseIdFrom(url: String) -> String? {
    var urlTail = url.components(separatedBy: "/").last!

    if urlTail.count <= MTAG_ID_B10_LENGTH + TECH_PREFIX || urlTail.count <= MTAG_ID_B36_LENGTH + TECH_PREFIX {
      urlTail.remove(at: urlTail.startIndex) // drop tech type
      return convertIdToBase10(urlTail)
    }
    else if urlTail.contains("&sig") || urlTail.contains("&tac") { // auth or hid
      let idAndTechType = urlTail.components(separatedBy: "?")[0]
      return convertIdToBase10(String(idAndTechType.dropFirst()))
    }
    else if url.components(separatedBy: "/").count == SMT_COUNTER_SEGMENTS { // counter
      let idAndTechType = url.components(separatedBy: "/").dropLast().last!
      return convertIdToBase10(String(idAndTechType.dropFirst()))
    }

    return nil
  }

  /**
   Converts the mTag ID from base36 to base10 if necessary.
   - parameter _ id: mTag ID to convert.
   - Returns: mTag ID in base10, or nil if the ID was invalid.
   */
  class func convertIdToBase10(_ id: String) -> String? {
    if id.count == MTAG_ID_B10_LENGTH {
      // make sure the id is actually in base10 and not just the right length
      if let _ = Int(id) {
        return id
      }
      else {
        return nil
      }
    }
    else if id.count <= MTAG_ID_B36_LENGTH {
      return String(strtoul(id, nil, 36))
    }
    else {
      _log("Unable to convert Id \(id)", level: "ERROR")
      return nil
    }
  }

  /**
   Parses an Auth URL into a dictionary.
   ex: https:// mtag.io/n10130797?id=<UID>&num=<Number>&sig=<Signature>
   */
  class func handleAuthUrl(withUrlParts urlParts: [String]) -> [String: String] {
    _log("Handling Auth Url", level: "DEBUG")

    let urlArgs = urlParts.last!.components(separatedBy: "?").last!.components(separatedBy: "&")

    var params: [String: String] = [:]
    let expectedArgs = ["id": "uid", "num": "tag_version", "sig": "vid"]
    for urlArg in urlArgs {
      let splitArg = urlArg.components(separatedBy: "=")
      let argName = String(splitArg[0])
      let argValue = String(splitArg[1])
      if let apiKeyname = expectedArgs[argName] {
        params[apiKeyname] = argValue
      }
    }
    return params
  }

  /**
   Parses a HID URL into a dictionary.
   ex: https:// mtag.io/n10130797?tagId=<value>&tac=<value>
   */
  class func handleHidUrl(withUrlParts urlParts: [String]) -> [String: String] {
    _log("Handling Hid Url", level: "DEBUG")
    let urlArgs = urlParts.last!.components(separatedBy: "?").last!.components(separatedBy: "&")

    var params: [String: String] = [:]
    let expectedArgs = ["tagID": "hid", "tac": "vid"]
    for urlArg in urlArgs {
      let splitArg = urlArg.components(separatedBy: "=")
      let argName = String(splitArg[0])
      let argValue = String(splitArg[1])
      if let apiKeyname = expectedArgs[argName] {
        params[apiKeyname] = argValue
      }
    }
    return params
  }

  /**
   Parses a Counter URL into a dictionary.
   ex: https:// mtag.io/n10130797/<UID>x<Number_6char><Fix2>
   */
  class func handleCounterUrl(withUrlParts urlParts: [String]) -> [String: String] {
    _log("Handling Counter Url", level: "DEBUG")
    var params: [String: String] = [:]
    let urlEnd = urlParts.last!
    // make sure to trim any extra params
    let fullVid = urlEnd.components(separatedBy: "?").first!

    params["vid"] = fullVid
    return params
  }

  /**
   Handles the case where we need to pass an unmutated URL to the interactions route.
   */
  class func registerInteraction(withUrl url: String) {
    let params : [String: String] = [
      "url": url
    ]
    return registerInteraction(withParams: params)
  }

  /**
   Handles formatting the interaction's request params for most URL formats.
   */
  class func registerInteraction(withTagId tagId: String, andParams params: [String: String]) {
    _log("Hitting Interactions route", level: "DEBUG")
    var mutableParams:[String: String] = params
    mutableParams["tech"] = "n"
    mutableParams["tag_id"] = tagId
    return registerInteraction(withParams: mutableParams)
  }

  /**
   Handles formatting request headers and submitting the actual interaction to the mTag API.  Passes response along to proper delegate.
   */
  class func registerInteraction(withParams params: [String: String]) {
    _log("registering interaction with params: \(params)", level: "DEBUG")
    // override the user agent if the user chooses
    var additionalHeaders : [String: String] = [:]
    if self.overrideUserAgent {
      additionalHeaders["User-Agent"] = "mTag-SDK request/Alamofire4.x"
    }
    if self.overrideHeaderCookie {
      additionalHeaders["Cookie"] = ""
    }

    let targetUrl = "https://api.mtag.io/v2/interactions"
    Alamofire.request(targetUrl, method: HTTPMethod.post, parameters: params, headers: additionalHeaders).responseJSON { response in
      if let json = response.result.value {
        if let jsonAsDict = json as? [String: Any] {
          let formattedResponse = parseAPIResponse(jsonAsDict)
          delegate?.interactionDataWasReceived(withResults: formattedResponse)
          return
        }
        // if we hit here we have a response but it must be empty or not a json object
        _log("Unexpected API response: \(json)", level: "ERROR")
        delegate?.didFailToReceiveInteractionData("Unexpected API response: \(json)")
        return
      }
      else if response.error != nil {
        self._log("Interaction Registration Request failed: \(String(describing: response.error))", level: "ERROR")
        delegate?.didFailToReceiveInteractionData("Alamofire was unable to process the request.")
        return
      }
      else {
        delegate?.didFailToReceiveInteractionData("Something went wrong.")
      }
    }
  }

  /**
   Parses the API response into a more digestible dictionary.
   */
  class func parseAPIResponse(_ jsonAsDict: [String: Any]) -> [String: Any] {
    var formattedResponse: [String : Any] = [:]

    let device = jsonAsDict["device"] as? [String: Any] ?? nil
    formattedResponse["deviceCountry"] = device?["country"] as? String ?? nil

    // get tagVerified.  Should return as Int but check for String just for robustness
    if let verified = jsonAsDict["tag_verified"] as? Int {
      formattedResponse["tagVerified"] = verified == 1 ? true : false
    }
    else if let verified = jsonAsDict["tag_verified"] as? String {
      formattedResponse["tagVerified"] = verified.lowercased() == "true" ? true : false
    }
    else {
      // probably wasn't included so just leave it out
    }

    formattedResponse["location"] = jsonAsDict["location"] as? [String: Any] ?? nil

    // make sure we get either a single campaign or multiple campaigns (if there are multiple)
    if let campaigns = jsonAsDict["campaigns"] as? [String: Any] {
      formattedResponse["campaigns"] = campaigns
    }
    else {
      formattedResponse["campaigns"] = jsonAsDict["campaigns"] as? [Any] ?? nil
    }

    // TODO: This could be deprecated by using Struct/encoding, but this seems safer
    if var location = formattedResponse["location"] as? [String: Any] {
      // data and system might be arrays or might be dicts, so try casting to both
      if let cleanDataAsArray = location["data"] as? [String] ?? nil {
        location["data"] = cleanDataAsArray
      }
      else {  // must be either not included or nil
        location["data"] = location["data"] as? [String: Any] ?? nil
      }

      if let cleanSystemAsArray: [String] = location["system"] as? [String] ?? nil {
        location["system"] = cleanSystemAsArray
      }
      else {
        location["system"] = location["system"] as? [String: Any] ?? nil
      }
      
      formattedResponse["location"] = location
    }
    return formattedResponse
  }
}
