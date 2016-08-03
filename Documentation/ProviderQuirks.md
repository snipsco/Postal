# Provider quirks

## Rationale
Email protocol is standardized. However providers implementations often provides extension or variations of these standards.

Postal tries to handle some of the edge cases whenever possible but some specificities have to be handled by the developer according to her choices.

This page is meant to regroup all the documentation we found about these quirks in order to make it easier to find a reference for each case.

## OAuth

For some of the most common providers, [OAuth](https://en.wikipedia.org/wiki/OAuth) is the *mandatory* way to connect:

### GMAIL

#### Using OAuth

Reference: [Google OAuth reference](https://developers.google.com/gmail/xoauth2_protocol)

You can use your favorite library to handle the oauth flow:

- [OAuthSwift](https://github.com/OAuthSwift/OAuthSwift)
- [SwiftyOAuth](https://github.com/delba/SwiftyOAuth)
- [And many more...](https://github.com/search?utf8=%E2%9C%93&q=oauth+swift)

**Scope**: The access token will need the following scope to allow an access to imap: `https://mail.google.com/`. 

You will then have to use your oauth access token as the password and your email as the login when connecting.

#### Using password

You can still use your account password if 2fa is not enabled. You will have to allow less secure apps to access your mail first. [The documentation is available here.](https://support.google.com/accounts/answer/6010255?hl=en)

However OAuth is the prefered production solution and you should not ask your users to do this. This solution should only be used for tests or prototyping.

### YAHOO

It should be possible to access yahoo using email and password if 2fa is disabled.

However if 2fa is enabled, you will have to use OAuth. The app is not so easy to create in the yahoo developer interface.

- [A workaround exists here to create an OAuth application that have an email scope despite its absence in yahoo developer interface](http://stackoverflow.com/questions/36058534/how-can-yahoo-mail-be-accessed-by-imap-using-oauth-or-oauth2-authentication)
- [A more official way to do it](https://developer.yahoo.com/oauth/guide/cck-form.html)

**OAuth Quirk:** at this date (07-02-2016) Yahoo OAuth form for mobile does not have a "switch account" or "disconnect" button. It may be problematic in the cases where you expect the user to connect multiple Yahoo email accounts.
If you use `SFSafariViewController`, it will put your users in a loop where she can't switch to a new account (because of the cookies left by the previous flow).

**Workaround**: if you want to connect multiple yahoo email accounts, you will have to use a `UIWebView` or `WKWebView` and clear your cookies before opening your oauth flow.


## Two factor auth

Two factor authentication can cause of lot of trouble when handling connection.
Most of the time, it is solved by the web flow displayed by the provider and you won't have to handle this.

### iCloud

In the case of iCloud, the 2fa option exists, but no OAuth flow is provided.
You will have to ask your user to generate an app-specific passwer [using this link](http://support.apple.com/kb/ht6186)

## Other Provider limitations and variations

### iCloud

There seem to be a hard limit (in bytes) to imap responses. We set a batch size of max. 500 items in the code.

### Common folder names

- Every provider seem to have a different identifier for the spam/junk folder. We discovered a set of default values but this setting can be specified in the imap configuration.

- Every provider seem to have a different identifier for the default/inbox folder. Most of the time the default value of `"INBOX"` will work as a good default when no other folder is found. The best method is to list folders and filter find one having the `.AllMail` attribute, or `.Inbox` if it could not be found.