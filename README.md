
![](Documentation/logo.jpg)

[![Build Status](https://travis-ci.org/snipsco/Postal.svg?branch=master)](https://travis-ci.org/snipsco/Postal)
[![Carthage](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Pods](https://img.shields.io/badge/Pods-compatible-4BC51D.svg?style=flat)](https://cocoapods.org/)
[![Swift 5.0](https://img.shields.io/badge/Swift-5.0-orange.svg?style=flat)](https://swift.org/)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS-lightgrey.svg?style=flat)

Postal is a swift framework providing simple access to common email providers.

## Example

### Connect

```swift
let postal = Postal(configuration: .icloud(login: "myemail@icloud.com", password: "mypassword"))
postal.connect { result in
    switch result {
    case .success:
        print("success")
    case .failure(let error):
        print("error: \(error)")
    }
}
```

### Search

```swift
let filter = .subject(value: "Foobar") && .from(value: "foo@bar.com")
postal.search("INBOX", filter: filter) { result in
    switch result {
    case .success(let indexes):
        print("success: \(indexes)")
    case .failure(let error):
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

### Want to debug your IMAP session ?

```swift
postal.logger = { log in
    print(log)
}
```

### What about Mailcore ?

Postal does not address the same goal as MailCore. You can take a look at our thoughts in the [TechnicalNotes][] document.

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

- Xcode 10
- OS X 10.10 or later
- iOS 8.0 or later

## Installation

### Carthage

Postal is [Carthage](https://github.com/Carthage/Carthage) compatible.

- Add `github "snipsco/Postal"` to your Cartfile.
- Run `carthage update`.

### CocoaPods

Postal also can be used by [CocoaPods](https://cocoapods.org/).

- Add the followings to your Podfile:

```ruby
use_frameworks!
pod 'Postal'
```

- Run `pod install`. 

### Manual

1. Add the Postal repository as a [submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) of your application’s repository.
	
```bash
git submodule add https://github.com/snipsco/Postal.git
git submodule update --init --recursive
```

1. Drag and drop `Postal.xcodeproj` into your application’s Xcode project or workspace.
1. On the “General” tab of your application target’s settings, add `Postal.framework` to the “Embedded Binaries” section.
1. If your application target does not contain Swift code at all, you should also set the `EMBEDDED_CONTENT_CONTAINS_SWIFT` build setting to “Yes”.

## License

Postal is released under the [MIT License](LICENCE.md).

[Roadmap]: Documentation/Roadmap.md
[TechnicalNotes]: Documentation/TechnicalNotes.md
[ProviderQuirks]: Documentation/ProviderQuirks.md
[CodeOfConduct]: Documentation/CodeOfConduct.md
