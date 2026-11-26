package com.exteragram.messenger.preferences.utils;

import org.telegram.ui.ActionBar.BaseFragment;

/** Minimal replacement for the exteraGram class of the same name. */
public class SettingsRegistry {
    public static final String SHRUG_MAN = "\u00af\\_(\u30c4)_/\u00af";
    public static final String deeplinkPrefix = "telegyou_settings";
    public static final String deeplinkPluginIdQueryKey = "plugin";
    public static final String deeplinkSettingQueryKey = "setting";

    private static SettingsRegistry instance;

    public static synchronized SettingsRegistry getInstance() {
        if (instance == null) {
            instance = new SettingsRegistry();
        }
        return instance;
    }

    public void onSettingNotFound(BaseFragment fragment) {
    }
}
