package org.infobip.plugins.mobilemessaging.flutter.common;

import io.flutter.Log;

import android.app.Activity;
import android.content.Context;
import android.content.res.Resources;
import android.graphics.Color;

import androidx.annotation.NonNull;

import org.infobip.mobile.messaging.MobileMessaging;
import org.infobip.mobile.messaging.MobileMessagingCore;
import org.infobip.mobile.messaging.NotificationSettings;
import org.infobip.mobile.messaging.app.ActivityLifecycleMonitor;
import org.infobip.mobile.messaging.interactive.NotificationAction;
import org.infobip.mobile.messaging.interactive.NotificationCategory;
import org.infobip.mobile.messaging.chat.InAppChat;
import org.infobip.mobile.messaging.storage.SQLiteMessageStore;

import java.util.List;

public class InitHelper {

    private final Configuration configuration;
    private final Activity activity;

    private static final String TAG = "MobileMessagingFlutter";

    public InitHelper(Configuration configuration, Activity activity) {
        this.configuration = configuration;
        this.activity = activity;
    }

    public MobileMessaging.Builder configurationBuilder() {
        Log.d(TAG, "configuration.getApplicationCode(): " + configuration.getApplicationCode());
        System.out.println("configuration.getApplicationCode()2: " + configuration.getApplicationCode());
        MobileMessaging.Builder builder = new MobileMessaging
                .Builder(activity.getApplication())
                .withApplicationCode(configuration.getApplicationCode())
                .withSenderId(configuration.getAndroidSettings().getFirebaseSenderId());

        // Privacy
        if (configuration.getPrivacySettings() != null) {
            if (configuration.getPrivacySettings().isUserDataPersistingDisabled()) {
                builder.withoutStoringUserData();
            }
            if (configuration.getPrivacySettings().isCarrierInfoSendingDisabled()) {
                builder.withoutCarrierInfo();
            }
            if (configuration.getPrivacySettings().isSystemInfoSendingDisabled()) {
                builder.withoutSystemInfo();
            }
        }

        if (configuration.defaultMessageStorage) {
            builder.withMessageStore(SQLiteMessageStore.class);
        }

        // Notification
        Context context = activity.getApplicationContext();
        NotificationSettings.Builder notificationBuilder = new NotificationSettings.Builder(activity.getApplicationContext());
        Configuration.AndroidSettings androidSettings = configuration.getAndroidSettings();

        if (androidSettings.getNotificationIcon() != null) {
            int resId = getResId(context.getResources(), androidSettings.getNotificationIcon(), context.getPackageName());
            if (resId != 0) {
                notificationBuilder.withDefaultIcon(resId);
            }
        }

        if (androidSettings.isMultipleNotifications()) {
            notificationBuilder.withMultipleNotifications();
        }
        if (androidSettings.getNotificationAccentColor() != null) {
            int color = Color.parseColor(androidSettings.getNotificationAccentColor());
            notificationBuilder.withColor(color);
        }

        if (configuration.inAppChatEnabled) {
            InAppChat.getInstance(context).activate();
        }

        builder.withDisplayNotification(notificationBuilder.build());
        return builder;
    }

    /**
     * Gets resource ID
     *
     * @param res         the resources where to look for
     * @param resPath     the name of the resource
     * @param packageName name of the package where the resource should be searched for
     * @return resource identifier or 0 if not found
     */
    private int getResId(Resources res, String resPath, String packageName) { // TODO: Move to common
        int resId = res.getIdentifier(resPath, "mipmap", packageName);
        if (resId == 0) {
            resId = res.getIdentifier(resPath, "drawable", packageName);
        }
        if (resId == 0) {
            resId = res.getIdentifier(resPath, "raw", packageName);
        }

        return resId;
    }

    /**
     * Converts notification actions in configuration into library format
     *
     * @param actions notification actions from cordova
     * @return library-understandable actions
     */
    @NonNull
    private NotificationAction[] notificationActionsFromConfiguration(@NonNull List<Configuration.NotificationAction> actions) { // TODO: Move to common
        NotificationAction notificationActions[] = new NotificationAction[actions.size()];
        for (int i = 0; i < notificationActions.length; i++) {
            Configuration.NotificationAction action = actions.get(i);
            notificationActions[i] = new NotificationAction.Builder()
                    .withId(action.getIdentifier())
                    .withIcon(activity.getApplication(), action.getIcon())
                    .withTitleText(action.getTitle())
                    .withBringingAppToForeground(action.isForeground())
                    .withInput(action.getTextInputPlaceholder())
                    .withMoMessage(action.isMoRequired())
                    .build();
        }
        return notificationActions;
    }

    /**
     * Converts notification categories in configuration into library format
     *
     * @param categories notification categories from cordova
     * @return library-understandable categories
     */
    @NonNull
    public NotificationCategory[] notificationCategoriesFromConfiguration(@NonNull List<Configuration.NotificationCategory> categories) { // TODO: Move to common
        NotificationCategory notificationCategories[] = new NotificationCategory[categories.size()];
        for (int i = 0; i < notificationCategories.length; i++) {
            Configuration.NotificationCategory category = categories.get(i);
            notificationCategories[i] = new NotificationCategory(
                    category.getIdentifier(),
                    notificationActionsFromConfiguration(category.getActions())
            );
        }
        return notificationCategories;
    }

    public void setForeground() {
        ActivityLifecycleMonitor monitor = MobileMessagingCore
                .getInstance(activity.getApplicationContext())
                .getActivityLifecycleMonitor();
        if (monitor != null) {
            monitor.onActivityResumed(activity);
        }
    }

}
