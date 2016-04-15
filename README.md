The remote injection plugin allows a remote site to interact with [cordova](https://cordova.apache.org)'s javascript APIs when loaded within your cordova app.  When compared with a cordova app that packages its HTML the downside to loading a remote site is if the network is down your app is down.  This can be an acceptable trade off if your site has a heavy dependency on the web services.  The advantage to this approach is the build, deployment, and previous investment of an existing site doesn't need to change and can continue to work for browser based users providing a smooth transition to an app which provides tighter native integration.

## Features
* Injects cordova and installed plugin JS into the webview for any remotely browsed page allowing them the same access to the cordova object and its plugins as a packaged cordova app.
* Provides a naive dialog prompting the user if they want to retry upon a failed connection.  This could use some work and was the minimal functionality for us to launch.
* Support for iOS and Android platforms.

## Installation
```bash
cordova plugin add cordova-plugin-remote-injection
```

## Configuration
Configuration is done via preferences in your config.xml.

### CRIInjectFirstFiles
```xml
<preference name="CRIInjectFirstFiles" value="www/js/init.js" />
```

Type: String

List of paths to JS files within the project to inject before injecting cordova into the remote site.  To inject multiple separate the files with a ",".

<preference name="CRIInjectFirstFiles" value="www/js/file1.js,www/js/file2.js" />
## FAQ

Will Apple approve the app if it just wraps a site?  Point 2.12 in their [guidelines](https://developer.apple.com/app-store/review/guidelines/#functionality) states:

`2.12 Apps that are not very useful, unique, are simply web sites bundled as Apps, or do not provide any lasting entertainment value may be rejected`

I make no promises for your app but our app was approved by Apple and is in the App Store.  We feel we enhanced our site with the app and are not simply bundling it.  We display the website but also provide notifications to our users for important events, badge count updates for alerts, etc.  Our app is also specifically for the customers of our company and not general use so that may have been a factor in their decision although all we can do is speculate.

## Support

Log issues on [github](https://github.com/TruckMovers/cordova-plugin-remote-injection) and we'll get in contact.
