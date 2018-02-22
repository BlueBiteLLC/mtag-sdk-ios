# mtag-sdk-ios
iOS SDK for the  mTag Platform

### Installation

Simply clone this repo and add `mTag-SDK` as a framework for your project.

Note that this pod includes `Alamofire ~> 4.5` as a dependency.

### Usage

Use of this SDK is fairly straightforward:

1. Extend your target Class to implement the `BlueBiteInteractionDelegate`'s two methods: `interactionDataWasReceived(withResults result: [String: Any])` and `didFailToReceiveInteractionData(_ error: String)`.  These two methods receive the response payload on a successful Interaction registration, and handle any errors that might have occurred during a failed Interaction registration, respectively.
2. Set the API delegate to reference the class that implements `BlueBiteInteractionDelegate` like
```
API.delegate = self
```
3. If desired, enable Debugging output by setting the `API.enableDebug` flag to `true`.
4. Pass the Interaction URL to be registered to `API.interactionWasReceived(withUrl url: String)`
5. Handle the response passed to the proper `BlueBiteInteractionDelegate` method.
