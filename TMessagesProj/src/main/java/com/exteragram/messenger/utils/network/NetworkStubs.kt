package com.exteragram.messenger.utils.network

import okhttp3.OkHttpClient
import org.telegram.tgnet.TLRPC

object ExteraHttpClient {
    val client: OkHttpClient = OkHttpClient.Builder().build()
}

object RemoteUtils {
    // Stub: the update search is disabled for now.
    @JvmStatic
    fun searchMessages(
        account: Int,
        limit: Int,
        query: String,
        filter: Any?,
        callback: (TLRPC.messages_Messages?, TLRPC.TL_error?) -> Unit,
        timeoutMs: Long,
    ) {
        callback(null, null)
    }
}
