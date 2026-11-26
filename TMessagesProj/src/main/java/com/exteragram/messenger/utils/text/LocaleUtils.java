package com.exteragram.messenger.utils.text;

import org.telegram.messenger.LocaleController;
import org.telegram.messenger.R;
import org.telegram.ui.ActionBar.BaseFragment;

/** Minimal replacement for the exteraGram helper of the same name. */
public class LocaleUtils {
    public static String createCopySpan(BaseFragment fragment) {
        return LocaleController.getString(R.string.Copy);
    }
}
