# mtag-sdk-ios
iOS SDK for the  mTag Platform

### Installation

Simply clone this repo and add `mTag-SDK` as a framework for your project (or add it as a local pod to your podspec if using CocoaPods).

Note that this pod includes `Alamofire ~> 4.5` as a dependency.

### Usage

Use of this SDK is fairly straightforward:

1. Add the framework to your Project, either via manually adding the framework or [via a local cocoapod](https://guides.cocoapods.org/using/the-podfile.html#using-the-files-from-a-folder-local-to-the-machine)
2. import `mTag_SDK`
3. Extend your target Class with `BlueBiteInteractionDelegate` and implement its two methods: `interactionDataWasReceived(withResults result: [String: Any])` and `didFailToReceiveInteractionData(_ error: String)`.  These two methods receive the response payload on a successful Interaction registration, and handle any errors that might have occurred during a failed Interaction registration, respectively.
4. Set the API delegate to reference the class that implements `BlueBiteInteractionDelegate` like
```
API.delegate = self
```
5. If desired, enable Debugging output by setting the `API.enableDebug` flag to `true`.
6. Pass the Interaction URL to be registered to `API.interactionWasReceived(withUrl url: String)`
7. Handle the response passed to the proper `BlueBiteInteractionDelegate` method.
