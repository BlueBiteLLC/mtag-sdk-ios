//
//  InteractionDelegate.swift
//  mTag-SDK
//
//  Created by Sam Krantz on 11/17/17.
//  Copyright © 2017 Blue Bite LLC. All rights reserved.
//

import Foundation

/**
 Delegate handles responses, both successful and errors, from the mTag-SDK.
 */
public protocol BlueBiteInteractionDelegate {
  /**
   Called when an Interaction has been successfully registered with the BlueBite API.
   - Parameter withResults result: Dictionary containing relevant information provided in the Interaction response.
   */
  func interactionDataWasReceived(withResults result: [String: Any])
  /**
   Called when an Interaction has failed to be registered with the BlueBite API.

   This could be caused by a general API failure, an invalid URL, or a general Alamofire failure.
   - Parameter _ error: Error message.
   */
  func didFailToReceiveInteractionData(_ error: String)
}
