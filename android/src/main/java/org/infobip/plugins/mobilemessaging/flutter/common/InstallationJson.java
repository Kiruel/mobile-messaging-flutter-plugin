package org.infobip.plugins.mobilemessaging.flutter.common;

import androidx.annotation.NonNull;

import com.google.gson.reflect.TypeToken;

import org.infobip.mobile.messaging.CustomAttributeValue;
import org.infobip.mobile.messaging.CustomAttributesMapper;
import org.infobip.mobile.messaging.Installation;
import org.infobip.mobile.messaging.InstallationMapper;
import org.infobip.mobile.messaging.api.support.http.serialization.JsonSerializer;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.lang.reflect.Type;
import java.util.List;
import java.util.Map;

public class InstallationJson extends Installation {

    private final static String IS_PUSH_REGISTRATION_ENABLED = "isPushRegistrationEnabled";
    private final static String IS_PRIMARY_DEVICE = "isPrimaryDevice";
    private final static String CUSTOM_ATTRIBUTES = "customAttributes";

    public static JSONArray toJSON(final List<Installation> installations) {
        if (installations == null) {
            return null;
        }
        JSONArray installationsJson = new JSONArray();
        for (Installation installation : installations) {
            installationsJson.put(toJSON(installation));
        }
        return installationsJson;
    }

    @NonNull
    public static Installation resolveInstallation(JSONObject args) throws JSONException {
        if (args == null) {
            throw new IllegalArgumentException("Cannot resolve installation from arguments");
        }

        return InstallationJson.fromJSON(args);
    }

    public static JSONObject toJSON(final Installation installation) {
        try {
            String json = InstallationMapper.toJson(installation);
            JSONObject jsonObject = new JSONObject(json);
            cleanupJsonMapForClient(installation.getCustomAttributes(), jsonObject);
            return jsonObject;
        } catch (JSONException e) {
            e.printStackTrace();
            return new JSONObject();
        }
    }

    /**
     * Creates array of json objects from list of installations
     *
     * @param installations list of installations
     * @return array of jsons representing installations
     */

    public static JSONArray installationsToJSONArray(@NonNull Installation[] installations) {
        JSONArray array = new JSONArray();
        for (Installation installation : installations) {
            JSONObject json = InstallationJson.toJSON(installation);
            if (json == null) {
                continue;
            }
            array.put(json);
        }
        return array;
    }

    private static Installation fromJSON(JSONObject json) {
        Installation installation = new Installation();

        try {
            if (json.has(IS_PUSH_REGISTRATION_ENABLED)) {
                installation.setPushRegistrationEnabled(json.optBoolean(IS_PUSH_REGISTRATION_ENABLED));
            }
            if (json.has(IS_PRIMARY_DEVICE)) {
                installation.setPrimaryDevice(json.optBoolean(IS_PRIMARY_DEVICE));
            }
            if (json.has(CUSTOM_ATTRIBUTES)) {
                Type type = new TypeToken<Map<String, Object>>() {
                }.getType();
                Map<String, Object> customAttributes = new JsonSerializer().deserialize(json.optString(CUSTOM_ATTRIBUTES), type);
                installation.setCustomAttributes(CustomAttributesMapper.customAttsFromBackend(customAttributes));
            }
        } catch (Exception e) {
            //error parsing
        }

        return installation;
    }

    private static void cleanupJsonMapForClient(Map<String, CustomAttributeValue> customAttributes, JSONObject jsonObject) throws JSONException {
        jsonObject.remove("map");
        if (jsonObject.has(CUSTOM_ATTRIBUTES) && customAttributes != null) {
            jsonObject.put(CUSTOM_ATTRIBUTES, new JSONObject(CustomAttributesMapper.customAttsToBackend(customAttributes)));
        }
    }
}
