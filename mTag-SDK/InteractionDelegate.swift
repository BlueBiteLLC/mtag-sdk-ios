//
//  InteractionDelegate.swift
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
