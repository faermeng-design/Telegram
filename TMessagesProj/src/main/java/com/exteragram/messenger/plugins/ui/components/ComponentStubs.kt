package com.exteragram.messenger.plugins.ui.components

import android.app.Dialog
import org.telegram.ui.ActionBar.BaseFragment

// Temporary stubs.
class SafeModeBottomSheet(fragment: BaseFragment?) {
    fun show() {}
}

class InstallPluginBottomSheet(fragment: BaseFragment?, validationResult: Any?, params: Any?) {
    fun show() {}

    class PluginInstallParams {
        companion object {
            @JvmStatic
            fun of(messageObject: Any?, filePath: String?): PluginInstallParams = PluginInstallParams()

            @JvmStatic
            fun untrusted(filePath: String?): PluginInstallParams = PluginInstallParams()
        }
    }
}

class PythonSdkUpdateAlert(fragment: BaseFragment, update: Any?) : Dialog(fragment.parentActivity!!)

object PluginFileViewer {
    @JvmStatic
    fun open(fragment: BaseFragment?, file: Any?, name: String?) {}
}
