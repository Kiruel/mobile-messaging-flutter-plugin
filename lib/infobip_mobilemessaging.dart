import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:infobip_mobilemessaging/models/inbox/filter_options.dart';
import 'package:infobip_mobilemessaging/models/inbox/inbox.dart';

import 'models/configuration.dart';
import 'models/installation.dart';
import 'models/ios_chat_settings.dart';
import 'models/library_event.dart';
import 'models/message.dart';
import 'models/message_storage.dart';
import 'models/personalize_context.dart';
import 'models/user_data.dart';

class InfobipMobilemessaging {
  static const MethodChannel _channel = MethodChannel('infobip_mobilemessaging');
  static const EventChannel _libraryEvent = EventChannel('infobip_mobilemessaging/broadcast');
  static final StreamSubscription _libraryEventSubscription =
      _libraryEvent.receiveBroadcastStream().listen((dynamic event) {
    log('Received event: $event');
    LibraryEvent libraryEvent = LibraryEvent.fromJson(jsonDecode(event));
    if (callbacks.containsKey(libraryEvent.eventName)) {
      callbacks[libraryEvent.eventName]?.forEach((callback) {
        log('Calling ${libraryEvent.eventName} with payload ${libraryEvent.payload == null ? 'NULL' : libraryEvent.payload.toString()}');
        if (libraryEvent.eventName == LibraryEvent.messageReceived ||
            libraryEvent.eventName == LibraryEvent.notificationTapped) {
          callback(Message.fromJson(libraryEvent.payload));
        } else if (libraryEvent.eventName == LibraryEvent.installationUpdated) {
          callback(Installation.fromJson(libraryEvent.payload).toString());
        } else if (libraryEvent.eventName == LibraryEvent.userUpdated) {
          callback(UserData.fromJson(libraryEvent.payload));
        } else if (libraryEvent.payload != null) {
          callback(libraryEvent.payload);
        } else {
          callback(libraryEvent.eventName);
        }
      });
    }
  }, onError: (dynamic error) {
    log('Received error: ${error.message}');
  }, cancelOnError: true);

  static Map<String, List<Function>?> callbacks = HashMap();

  static Configuration? _configuration;

  static MessageStorage? _defaultMessageStorage;

  static Future<void> on(String eventName, Function callback) async {
    if (callbacks.containsKey(eventName)) {
      var existed = callbacks[eventName];
      existed?.add(callback);
      callbacks.update(eventName, (val) => existed);
    } else {
      callbacks.putIfAbsent(eventName, () => List.of([callback]));
    }
    _libraryEventSubscription.resume();
  }

  static Future<void> unregister(String eventName, Function? callback) async {
    if (callbacks.containsKey(eventName)) {
      var existed = callbacks[eventName];
      existed?.remove(callback);
      callbacks.remove(eventName);
      callbacks.putIfAbsent(eventName, () => existed);
    }
    _libraryEventSubscription.resume();
  }

  static Future<void> unregisterAllHandlers(String eventName) async {
    if (callbacks.containsKey(eventName)) {
      callbacks.removeWhere((key, value) => key == eventName);
    }
    _libraryEventSubscription.resume();
  }

  static Future<void> init(Configuration configuration) async {
    InfobipMobilemessaging._configuration = configuration;
    String str = await getVersion();
    configuration.pluginVersion = str;

    await _channel.invokeMethod('init', jsonEncode(configuration.toJson()));
  }

  static Future<String> getVersion() async {
    final fileContent = await rootBundle.loadString(
      'packages/infobip_mobilemessaging/pubspec.yaml',
    );

    if (fileContent.isNotEmpty) {
      String versionStr = fileContent.substring(fileContent.indexOf('version:'), fileContent.indexOf('\nhomepage:'));
      versionStr = versionStr.substring(9, versionStr.length);
      return versionStr;
    }
    return '';
  }

  static Future<void> saveUser(UserData userData) async {
    await _channel.invokeMethod('saveUser', jsonEncode(userData.toJson()));
  }

  static Future<UserData> fetchUser() async => UserData.fromJson(jsonDecode(await _channel.invokeMethod('fetchUser')));

  static Future<UserData> getUser() async => UserData.fromJson(jsonDecode(await _channel.invokeMethod('getUser')));

  static Future<void> saveInstallation(Installation installation) async {
    await _channel.invokeMethod('saveInstallation', jsonEncode(installation.toJson()));
  }

  static Future<Installation> fetchInstallation() async =>
      Installation.fromJson(jsonDecode(await _channel.invokeMethod('fetchInstallation')));

  static Future<Installation> getInstallation() async =>
      Installation.fromJson(jsonDecode(await _channel.invokeMethod('getInstallation')));

  static Future<void> personalize(PersonalizeContext context) async {
    await _channel.invokeMethod('personalize', jsonEncode(context.toJson()));
  }

  static void depersonalize() async {
    await _channel.invokeMethod('depersonalize');
  }

  /// Asynchronously cleans up all persisted data.
  /// This method deletes SDK data related to current application code (also, deletes data for other modules: interactive, chat).
  /// There might be a situation where you'll want to switch between different Application Codes during development/testing,
  /// in this case you should manually invoke cleanup().
  /// After cleanup, you should call init() with a new Application Code in order to use library again.
  static Future<void> cleanup() async {
    await _channel.invokeMethod('cleanup');
  }

  static void depersonalizeInstallation(String pushRegistrationId) async {
    await _channel.invokeMethod('depersonalizeInstallation', pushRegistrationId);
  }

  static void setInstallationAsPrimary(InstallationPrimary installationPrimary) async {
    await _channel.invokeMethod('setInstallationAsPrimary', installationPrimary.toJson());
  }

  static Future<void> showChat({bool shouldBePresentedModallyIOS = true}) async {
    await _channel.invokeMethod('showChat', shouldBePresentedModallyIOS);
  }

  static Future<void> setupiOSChatSettings(IOSChatSettings settings) async {
    if (Platform.isIOS) {
      await _channel.invokeMethod('setupiOSChatSettings', jsonEncode(settings.toJson()));
    }
  }

  static void submitEvent(Object customEvent) {
    _channel.invokeMethod('submitEvent', jsonEncode(customEvent));
  }

  static void submitEventImmediately(Object customEvent) {
    _channel.invokeMethod('submitEventImmediately', jsonEncode(customEvent));
  }

  static Future<int> getMessageCounter() async => await _channel.invokeMethod('getMessageCounter');

  static void resetMessageCounter() async {
    await _channel.invokeMethod('resetMessageCounter');
  }

  static void setLanguage(String language) async {
    await _channel.invokeMethod('setLanguage', language);
  }

  static void sendContextualData(String data, bool allMultiThreadStrategy) async {
    await _channel.invokeMethod('sendContextualData', {'data': data, 'allMultiThreadStrategy': allMultiThreadStrategy});
  }

  static void setJwt(String jwt) async {
    await _channel.invokeMethod('setJwt', jwt);
  }

  static MessageStorage? defaultMessageStorage() {
    if (_configuration == null) {
      return null;
    }
    if (_configuration?.defaultMessageStorage == null) {
      return null;
    }
    if (_configuration?.defaultMessageStorage == false) {
      return null;
    }

    _defaultMessageStorage ??= _DefaultMessageStorage(_channel);

    return _defaultMessageStorage;
  }

  static Future<void> registerForAndroidRemoteNotifications() async {
    if (Platform.isIOS) {
      log("It's not supported on the iOS platform");
      return;
    }

    await _channel.invokeMethod('registerForAndroidRemoteNotifications');
  }

  static Future<void> registerForRemoteNotifications() async {
    if (!Platform.isIOS) {
      log("It's supported only on the iOS platform");
      return;
    }

    await _channel.invokeMethod('registerForRemoteNotifications');
  }

  static Future<void> enableCalls(String identity) async {
    await _channel.invokeMethod('enableCalls', identity);
  }

  static Future<void> enableChatCalls() async {
    await _channel.invokeMethod('enableChatCalls');
  }

  static Future<void> disableCalls() async {
    await _channel.invokeMethod('disableCalls');
  }

  static Future<void> restartConnection() async {
    if (!Platform.isIOS) {
      log("It's supported only on the iOS platform");
      return;
    }
    await _channel.invokeMethod('restartConnection');
  }

  static Future<void> stopConnection() async {
    if (!Platform.isIOS) {
      log("It's supported only on the iOS platform");
      return;
    }
    await _channel.invokeMethod('stopConnection');
  }

  /// Fetches messages from Inbox.
  /// Requires token, externalUserId, and filterOptions.
  /// Example:
  /// ```dart
  /// var inbox = await fetchInboxMessages('jwtToken', 'yourId', FilterOptions());
  static Future<Inbox> fetchInboxMessages(
      String token, String externalUserId, FilterOptions filterOptions) async {
    return Inbox.fromJson(jsonDecode(await _channel.invokeMethod(
      'fetchInboxMessages',
      {
        'token': token,
        'externalUserId': externalUserId,
        'filterOptions': jsonEncode(filterOptions.toJson()),
      },
    )));
  }

  /// Fetches messages from Inbox without token - recommended only for sandbox
  /// applications. For production apps use fetchInboxMessages with token.
  /// Requires externalUserId, and filterOptions.
  ///
  /// Example:
  /// ```dart
  /// var inbox = await fetchInboxMessagesWithoutToken('yourId', FilterOptions());
  static Future<Inbox> fetchInboxMessagesWithoutToken(
      String externalUserId, FilterOptions filterOptions) async {
    return Inbox.fromJson(jsonDecode(await _channel.invokeMethod(
      'fetchInboxMessagesWithoutToken',
      {
        'externalUserId': externalUserId,
        'filterOptions': jsonEncode(filterOptions.toJson()),
      },
    )));
  }

  /// Sets Inbox messages as seen.
  /// Requires externalUserId and List of IDs of messages to be marked as seen.
  static Future<void> setInboxMessagesSeen(
      String externalUserId, List<String> messageIds) async {
    await _channel.invokeMethod(
      'setInboxMessagesSeen',
      {
        'externalUserId': externalUserId,
        'messageIds': messageIds,
      },
    );
  }

  static Future<void> markMessagesSeen(List<String> messageIds) async {
    await _channel.invokeMethod('markMessagesSeen', messageIds);
  }
}

class _DefaultMessageStorage extends MessageStorage {
  final MethodChannel _channel;

  _DefaultMessageStorage(this._channel);

  @override
  delete(String messageId) async {
    await _channel.invokeMethod('defaultMessageStorage_delete', messageId);
  }

  @override
  deleteAll() async {
    await _channel.invokeMethod('defaultMessageStorage_deleteAll');
  }

  @override
  Future<Message?> find(String messageId) async =>
      Message.fromJson(jsonDecode(await _channel.invokeMethod('defaultMessageStorage_find', messageId)));

  @override
  Future<List<Message>?> findAll() async {
    String result = await _channel.invokeMethod('defaultMessageStorage_findAll');
    Iterable l = json.decode(result);
    return List<Message>.from(l.map((model) => Message.fromJson(model)));
  }
}