package com.exteragram.messenger

import android.content.Context
import android.content.SharedPreferences
import org.telegram.messenger.ApplicationLoader

// Minimal replacement for the exteraGram settings used by the plugin core.

val preferences: SharedPreferences
    get() {
        val prefs = ApplicationLoader.applicationContext.getSharedPreferences("telegyou_plugins", Context.MODE_PRIVATE)
        if (!prefs.contains("pluginsEngine")) {
            prefs.edit().putBoolean("pluginsEngine", true).apply()
        }
        return prefs
    }

val editor: SharedPreferences.Editor
    get() = preferences.edit()

var pinnedPlugins: Set<String>
    get() = preferences.getStringSet("pinnedPlugins", emptySet()) ?: emptySet()
    set(value) {
        preferences.edit().putStringSet("pinnedPlugins", HashSet(value)).apply()
    }

var sdkUpdateScheduleTimestamp: Long
    get() = preferences.getLong("sdkUpdateScheduleTimestamp", 0L)
    set(value) {
        preferences.edit().putLong("sdkUpdateScheduleTimestamp", value).apply()
    }
