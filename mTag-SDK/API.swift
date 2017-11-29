//
//  API.swift
//  mTag-SDK
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
  static let MTAG_ID_B36_LENGTH: Int = 5
  // length of tech prefix affixed to mTag ID
  static let TECH_PREFIX: Int = 1

  open static var delegate: BlueBiteInteractionDelegate?

  // user-accessible constant to enable debug output
  open static var enableDebug: Bool = false

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
    _log("urlParts: \(urlParts)", level: "DEBUG")

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

    if urlTail.count == MTAG_ID_B10_LENGTH + TECH_PREFIX || urlTail.count == MTAG_ID_B36_LENGTH + TECH_PREFIX {
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
    else if id.count == MTAG_ID_B36_LENGTH {
      return String(strtoul(id, nil, 36))
    }
    else {
      _log("Unable to convert Id \(id)", level: "ERROR")
      return nil
    }
  }

  // TODO VERIFY PARAM KEYS USING ANDROID NFC VERIFICATION CODE
  /**
   Parses an Auth URL into a dictionary.
   ex: https:// mtag.io/n10130797?id=<UID>&num=<Number>&sig=<Signature>
   */
  class func handleAuthUrl(withUrlParts urlParts: [String]) -> [String: String] {
    _log("Handling Auth Url", level: "DEBUG")

    let urlArgs = urlParts.last!.components(separatedBy: "?").last!.components(separatedBy: "&")

    var params: [String: String] = [:]
    let expectedArgs = ["id": "tag_uid", "num": "tag_version", "sig": "tag_signature"]
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
    var urlArgs = urlParts.last!.components(separatedBy: "?").last!.components(separatedBy: "&")

    var params: [String: String] = [:]
    let expectedArgs = ["tagId": "tagID", "tac": "tac"]
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
   ex: https:// mtag.io/n10130797/<UID>x<Number_6char><Fix2> (drop Fix2)
   */
  class func handleCounterUrl(withUrlParts urlParts: [String]) -> [String: String] {
    _log("Handling Counter Url", level: "DEBUG")
    var params: [String: String] = [:]
    let uidAndCounter = urlParts.last!.components(separatedBy: "x")

    let uid = uidAndCounter[0]
    let counterWithFix = uidAndCounter[1]
    let counter = String(counterWithFix.dropLast(counterWithFix.count - 6))

    params["uid"] = uid
    params["count"] = counter
    return params
  }

  /**
   Handles the actual registration of the interaction, and passes the parsed response to the delegate.
   */
  class func registerInteraction(withTagId tagId: String, andParams params: [String: String]) {
    _log("Hitting Interactions route", level: "DEBUG")
    var mutableParams:[String: String] = params
    mutableParams["tech"] = "n"
    mutableParams["tag_id"] = tagId

    _log("Params: \(mutableParams)", level: "DEBUG")

    let targetUrl = "https://api.mtag.io/v2/interactions"
    Alamofire.request(targetUrl, method: HTTPMethod.post, parameters: mutableParams).responseJSON { response in
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
        self._log("Interaction Registration Request failed: \(response.error)", level: "ERROR")
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

    formattedResponse["tagVerified"] = jsonAsDict["tag_verified"] as? String ?? nil
    formattedResponse["campaigns"] = jsonAsDict["campaigns"] as? [String: Any] ?? nil
    formattedResponse["location"] = jsonAsDict["location"] as? [String: Any] ?? nil

    // TODO: This could be deprecated by using Struct/encoding, but this seems safer
    if var location = formattedResponse["location"] as? [String: Any] {
      // data and system keys are arrays and should be explicitly converted to them
      let cleanData: [String] = location["data"] as? [String] ?? []
      let cleanSystem: [String] = location["system"] as? [String] ?? []
      location["data"] = cleanData
      location["system"] = cleanSystem
      formattedResponse["location"] = location
    }

    return formattedResponse
  }
}
