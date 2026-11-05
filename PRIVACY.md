# Privacy

MacMenuRadio stores the selected station and volume locally through macOS UserDefaults. An optional station configuration is read from your Application Support folder.

When you press Play, Apple's AVPlayer connects to the configured stream provider and any endpoints to which it redirects. Those providers receive your IP address and the connection information needed to deliver audio. Their own terms and privacy policies apply. A station may include advertising in its audio.

The app has no analytics SDK, account system, advertising SDK, microphone access, or recording feature. It does not send preferences to the project maintainer. Apple's networking and media frameworks may keep their own caches and diagnostics.

Avoid including credentials or private stream URLs in configuration files you share publicly.

To remove the optional configuration, delete the MacMenuRadio folder in your user Library's Application Support directory. To remove saved station and volume preferences, quit the app and run the following command.

```sh
defaults delete engineering.grossman.MacMenuRadio
```
