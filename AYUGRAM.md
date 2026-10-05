# AyuGram for iOS

AyuGram for iOS is an unofficial Telegram client. It is a fork of the official
[Telegram for iOS](https://github.com/TelegramMessenger/Telegram-iOS), with the features of
[AyuGram4A](https://github.com/AyuGram/AyuGram4A) (AyuGram for Android) ported into it.
This is the same approach AyuGram takes on Android, where it is built on top of Telegram for Android.

Because it is a fork, every regular Telegram feature works as it does in the official app: calls and
video calls, stickers, emoji, stories, folders, secret chats, channels, bots, mini apps and the
iOS 26 Liquid Glass design.

## AyuGram features

You can find these under **Settings → AyuGram Preferences**.

| Feature | AyuGram4A key | Where it hooks in |
|---|---|---|
| Ghost mode: master switch | `setGhostMode` | `AyuSettings.setGhostMode` |
| Don't read messages | `sendReadPackets` | `SynchronizePeerReadState`, `ApplyMaxReadIndexInteractively` (discussions) |
| Don't send online | `sendOnlinePackets` | `ManagedAccountPresence` |
| Don't send typing / upload progress | `sendUploadProgress` | `ManagedLocalInputActivities` |
| Don't mark stories as seen | `sendStoryViews` | `ManagedSynchronizeViewStoriesOperations`, `Stories.incrementStoryViews` |
| Immediate offline after online | `sendOfflinePacketAfterOnline` | `ManagedAccountPresence` |
| Read after reply (in ghost mode) | `markReadAfterSend` | `EnqueueMessage` |
| Send as scheduled (+12 s) | `useScheduledMessages` | `EnqueueMessage` |
| "Read until here" in the message menu | `AyuGhostUtils.markReadOnServer` | `ChatInterfaceStateContextMenus`, `TelegramEngineMessages.ayuReadOnServer` |
| Save deleted messages (with 🧹 mark) | `saveDeletedMessages` | `AccountStateManagementUtils.replayFinalState`, `HistoryViewStateValidation` |
| Save edits history plus the "Edits history" screen | `saveMessagesHistory` | `replayFinalState (.EditMessage)`, `AyuEditHistoryStore`, `AyuEditHistoryController` |
| Save in bot chats | `saveForBots` | `AyuSettings.shouldSave…` |
| Keep reactions on deleted messages | `saveReactions` | `ayu_preserveDeletedMessages` |
| Disable sponsored messages | `disableAds` | `AdMessages` |
| Regex message filters (channels / all chats, case-insensitive) | `regexFilters*` | `ChatHistoryEntriesForView`, `AyuFilter` |
| Custom deleted / edited marks | `deletedMarkText`, `editedMarkText` | `ChatMessageDateAndStatusNode` |
| Clear edits history, close the app | Debug | `AyuGramSettingsController` |

Code layout:

- `submodules/AyuGram/AyuCore`: settings (UserDefaults suite `ayuconfig`, same keys as Android), ghost state, regex filters, the edit history store and strings (en/ru). It has no dependencies.
- `submodules/AyuGram/AyuGramUI`: settings, filters and edits-history screens, built with ItemListUI.
- `submodules/TelegramCore/Sources/Ayu`: the Postbox attribute `AyuDeletedMessageAttribute` and the message hooks.
- Every change to upstream files is a small hook marked with `AyuGram` or `ayu`, so rebasing on a new Telegram release stays easy.

## Not ported (yet)

- **Local Premium.** The client-side Premium flag would touch dozens of `isPremium` checks; the setting key exists, but there is no switch for it.
- **Ghost toggle and kill button in the drawer.** iOS Telegram has no drawer. Ghost mode is in Settings, and the 👻 label on the Settings row shows its state.
- **AyuSync, the "Shadow ban" list and the custom fonts / app icons pack.**

## Building (GitHub Actions, free unsigned IPA)

1. Get your own `api_id` and `api_hash` at https://my.telegram.org/apps.
2. Add them as repository secrets `TG_API_ID` and `TG_API_HASH`. Never commit them.
3. Run the **AyuGram iOS (unsigned IPA)** workflow, which also runs on every push to `ayugram`.
4. Download the `AyuGram-iOS-*` artifact. The IPA uses fake code signing (bundle id
   `ph.telegra.Telegraph`), so install it with ESign / KSign / Scarlet / Sideloadly / AltStore /
   LiveContainer and **change the bundle id** in the signer, e.g. `com.yourname.ayugram`.

Push notifications, iCloud, Siri and Apple Pay need a real provisioning profile with the matching entitlements, so they won't work with sideloading.

Local build on a Mac: see `README.md`. The short version is
`python3 build-system/Make/Make.py build --configurationPath=... --codesigningInformationPath=build-system/fake-codesigning --configuration=release_arm64 --buildNumber=1`.

## License

GPL-2.0, like Telegram for iOS and AyuGram4A. AyuGram4A is © Radolyn Labs; the ported logic carries
attribution in the file headers. This app is unofficial and not affiliated with Telegram FZ-LLC.
