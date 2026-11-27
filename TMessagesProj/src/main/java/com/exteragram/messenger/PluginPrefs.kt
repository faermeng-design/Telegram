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

var pluginsEngine: Boolean
    get() = preferences.getBoolean("pluginsEngine", true)
    set(value) {
        preferences.edit().putBoolean("pluginsEngine", value).apply()
    }

var pluginsSafeMode: Boolean
    get() = preferences.getBoolean("pluginsSafeMode", false)
    set(value) {
        preferences.edit().putBoolean("pluginsSafeMode", value).apply()
    }

var pluginsDevMode: Boolean
    get() = preferences.getBoolean("pluginsDevMode", false)
    set(value) {
        preferences.edit().putBoolean("pluginsDevMode", value).apply()
    }

var pluginsDisableArtOpts: Boolean
    get() = preferences.getBoolean("pluginsDisableArtOpts", false)
    set(value) {
        preferences.edit().putBoolean("pluginsDisableArtOpts", value).apply()
    }

var pluginsPySdkAutoUpdate: Boolean
    get() = preferences.getBoolean("pluginsPySdkAutoUpdate", false)
    set(value) {
        preferences.edit().putBoolean("pluginsPySdkAutoUpdate", value).apply()
    }

var pluginsPySdkBetaVersions: Boolean
    get() = preferences.getBoolean("pluginsPySdkBetaVersions", false)
    set(value) {
        preferences.edit().putBoolean("pluginsPySdkBetaVersions", value).apply()
    }
