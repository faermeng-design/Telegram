package com.exteragram.messenger.plugins.catalog

import org.telegram.ui.ActionBar.BaseFragment

object PluginRepositoryLinks {
    @JvmStatic
    fun open(fragment: BaseFragment?, username: String?) {}

    @JvmStatic
    fun openGit(fragment: BaseFragment?, url: String?) {}
}
