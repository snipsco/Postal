
![](Documentation/logo.jpg)

[![Carthage](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Pods](https://img.shields.io/badge/Pods-compatible-4BC51D.svg?style=flat)](https://cocoapods.org/) 
[![Swift 2.2.x](https://img.shields.io/badge/Swift-2.2.x-orange.svg?style=flat)](https://swift.org/)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS-lightgrey.svg?style=flat)

Postal is a swift framework providing simple access to common email providers.

## Example

### Connect

```swift
let postal = Postal(configuration: .icloud(login: "myemail@icloud.com", password: "mypassword"))
postal.connect { result in
		switch result {
		case .Success:
		    print("success")
		case .Failure(let error):
		    print("error: \(error)")
		}
}
```

### Search

```swift
let filter = .subject(value: "Foobar") && .from(value: "foo@bar.com")
postal.search("INBOX", filter: filter) { result in
	switch result {
	case .Success(let indexes):
	    print("success: \(indexes)")
	case .Failure(let error):
	    print("error: \(error)")
	}
}
```

### Fetch

```swift
let indexset = NSIndexSet(index: 42)
postal.fetchMessages("INBOX", uids: indexset, flags: [ .headers ], onMessage: { email in
	print("new email received: \(email)")
}, onComplete: error in
	if error = error {
	    print("an error occured: \(error)")
	}
}
```

### What about Mailcore ?

Postal does not addresses the same goal as MailCore. You can take a look at our toughts in the [TechnicalNotes][] document.

### Provider quirks

Email protocol is standardized. However providers implementations often provides extension or variations of these standards.
We tried to build a document to synthesize working around these variations here: [ProviderQuirks][].

### Contributing

Postal has been a great effort and we could really use your help on many areas:

- Finding and reporting bugs.
- New feature suggestions.
- Answering questions on issues.
- Documentation improvements.
- Reviewing pull requests.
- Fixing bugs/new features.
- Improving tests.
- Contribute to elaborate the [Roadmap][].

If any of that sounds cool to you, please send a pull request!

Please note that this project is released with a Contributor Code of Conduct. By participating in this project you agree to abide by its terms that you can find here: [CodeOfConduct][].

## Requirements

- Swift 2.2.x / Xcode 7.3 | Swift 2.3.x / Xcode 8
- OS X 10.10 or later
- iOS 8.0 or later

## Installation

### Framework with Carthage

Postal is [Carthage](https://github.com/Carthage/Carthage) compatible.

- Add `github "snipsco/Postal"` to your Cartfile.
- Run `carthage update`.

### Framework with CocoaPods

Postal also can be used by [CocoaPods](https://cocoapods.org/).

- Add the followings to your Podfile:

    ```ruby
    use_frameworks!
    pod "Postal"
    ```

    - For ReactiveCocoa extensions, this project will include them as dependencies. You can do this via CocoaPods subspecs.

	```ruby
	pod 'Postal/ReactiveCocoa'
	```

- Run `pod install`.

## License

Postal is released under the [MIT License](LICENCE.md).

[Roadmap]: Documentation/Roadmap.md
[TechnicalNotes]: Documentation/TechnicalNotes.md
[ProviderQuirks]: Documentation/ProviderQuirks.md
[CodeOfConduct]: Documentation/CodeOfConduct.md
