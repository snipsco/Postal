# Technical Notes

## How does it work ?

- Postal is a swift wrapper over [libetpan](https://github.com/dinhviethoa/libetpan).
- Libetpan handles all the low-level imap connection and parsing in a synchronous way. 
- Postal wraps some features provided by libetpan and exposes them with an high-level asynchronous API.
- The high level API must be simple and comprehensive swift.
- Libetpan is provided in the repo as a pre-built static library for a better ease-of-use and easier CocoaPods distrbution
- Libetpan can be built from source using the shell scripts found in the [dependencies](https://github.com/snipsco/Postal/tree/master/dependencies) folder.

## About mailcore ?

[Mailcore2](https://github.com/MailCore/mailcore2) is a library wrapping libetpan providing a great set of features when interacting with mails.

The main drawback which made us start a fresh library is that Mailcore is an objective-c wrapper over a C++ wrapper over libetpan.
These layers of complexity makes the library quite awkward to use in cunjunction with swift.

Swift provides a native way to interop with C and libetpan is fully portable. We hope that Postal may be ported to provide its feature set in a fully portable (server swift?) way.

[dependencies]: dependencies/
