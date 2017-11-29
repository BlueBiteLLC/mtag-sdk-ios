//
//  mTag_SDKTests.swift
//  mTag-SDKTests
//
//  Created by Sam Krantz on 11/17/17.
//  Copyright © 2017 Blue Bite LLC. All rights reserved.
//

import XCTest
@testable import mTag_SDK

class mTag_SDKTests: XCTestCase, BlueBiteInteractionDelegate {

    var basicTagSuccessExpectation: XCTestExpectation?

    // MARK: BlueBiteInteractionDelegate
    func interactionDataWasReceived(withResults result: [String : Any]) {
        basicTagSuccessExpectation?.fulfill()
        print("response was received: \(result)")
    }

    func didFailToReceiveInteractionData(_ error: String) {
        print("Delegate failure was called: \(error)")
    }

    // MARK: TEST SETUP
    override func setUp() {
        super.setUp()
        API.delegate = self
        API.enableDebug = true
    }
    
    override func tearDown() {
        super.tearDown()
    }

    // MARK: TESTING
    /*
     A call to API.interactionWasReceived(withUrl url:) should:
        - Properly parse the URL's mTag ID.
        - Submit the parsed mTag ID and other tag metadata to the interactions route.
        - Return any available Campaign, Location, Device Location, or Tag Verification Status to the delegate.
    */
    func testSimpleUrl() {
        basicTagSuccessExpectation = self.expectation(description: "Should return an expected success response for a basic mTag URL.")
        let url = "https://mtag.io/njaix4"
        API.interactionWasReceived(withUrl: url)
        self.waitForExpectations(timeout: 10.0, handler: nil)
    }

    /*
     Calls to API.convertIdToBase10(_ id:) should:
        - Receive a potential mTag ID and successfully parse it and convert it to Base 10.
        - Return nil if the id is not a valid mTag ID.
    */
    func testConvertIdToBase10() {
        // test valid base10 id
        var res = API.convertIdToBase10("12345678")
        XCTAssertEqual(Int(res!), 12345678)

        //test valid base36 id
        res = API.convertIdToBase10("eeeee") //24186470
        XCTAssertEqual(Int(res!), 24186470)

        //test invalid id with same length as base10 id
        res = API.convertIdToBase10("1234567#")
        XCTAssertNil(res)

        //test invalid id too short
        res = API.convertIdToBase10("123")
        XCTAssertNil(res)
        //test invalid id too long
        res = API.convertIdToBase10("1234567890")
        XCTAssertNil(res)
    }

    /*
     Calls to API.parseIdFrom(url:) should:
        - Parse the mTag ID from the provided url, for all valid url formats.
        - Return nil otherwise.
    */
    func testParseIdFromUrl() {
        let expectedId: String = "32403784"
        // test good simple url
        var res = API.parseIdFrom(url: "https://mtag.io/njaix4")
        XCTAssertEqual(res!, expectedId)

        // test good auth url
        res = API.parseIdFrom(url: "https://mtag.io/njaix4?id=1234567&num=890123&sig=456789")
        XCTAssertEqual(res!, expectedId)

        // test good hid url
        res = API.parseIdFrom(url: "https://mtag.io/njaix4?tagId=999999&tac=888888")
        XCTAssertEqual(res!, expectedId)

        // test good counter url
        res = API.parseIdFrom(url: "https://mtag.io/njaix4/12345678x1234564444")
        XCTAssertEqual(res!, expectedId)

        // test good hid url with extra arguments
        res = API.parseIdFrom(url: "https://mtag.io/njaix4?tagId=999999&tac=888888&something=else")
        XCTAssertEqual(res!, expectedId)

        // test failure due to unknown url syntax
        res = API.parseIdFrom(url: "https://bb.io/p/1/foo?bar=1")
        XCTAssertNil(res)
    }

    /*
     A call to any of the handle<urlType>(withUrlParts urlParts:) functions should:
        - Verify the url is valid and parse it into a parameters dictionary.
        - Fail otherwise.
    */
    // TODO VERIFY WHAT HAPPENS WHEN THE HANDLE FUNC FAILS
    func testUrlHandlingFunctions() {
        // test good auth url
        var targetUrl: String = "https://mtag.io/njaix4?id=1234567&num=890123&sig=456789"
        var res = API.handleAuthUrl(withUrlParts: targetUrl.components(separatedBy: "/"))
        XCTAssertEqual(res, ["tag_signature": "456789", "tag_version": "890123", "tag_uid": "1234567"])

        // test good hid url
        targetUrl = "https://mtag.io/njaix4?tagId=654321&tac=123456"
        res = API.handleHidUrl(withUrlParts: targetUrl.components(separatedBy: "/"))
        XCTAssertEqual(res, ["tac": "123456", "tagID": "654321"])

        // test good counter url
        targetUrl = "https://mtag.io/njaix4/12345678x1234561234"
        res = API.handleCounterUrl(withUrlParts: targetUrl.components(separatedBy: "/"))
        XCTAssertEqual(res, ["uid": "12345678", "count": "123456"])

        // test bad auth url
        targetUrl = "https://mtag.io/njaix4?badkey=failure&id=1234567&num=890123&sig=456789"
        res = API.handleAuthUrl(withUrlParts: targetUrl.components(separatedBy: "/"))
        XCTAssertEqual(res, ["tag_signature": "456789", "tag_version": "890123", "tag_uid": "1234567"])

        // test bad hid url
        targetUrl = "https://mtag.io/njaix4?tagId=654321&badfield=yes&tac=123456"
        res = API.handleHidUrl(withUrlParts: targetUrl.components(separatedBy: "/"))
        XCTAssertEqual(res, ["tac": "123456", "tagID": "654321"])

        // test bad counter url
        targetUrl = "https://mtag.io/njaix4/12345678x1234561234?thisShouldnt=beHere"
        res = API.handleCounterUrl(withUrlParts: targetUrl.components(separatedBy: "/"))
        XCTAssertEqual(res, ["uid": "12345678", "count": "123456"])
    }
}
