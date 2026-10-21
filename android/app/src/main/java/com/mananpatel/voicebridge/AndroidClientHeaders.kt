package com.mananpatel.voicebridge

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import okhttp3.Request
import java.security.MessageDigest

/**
 * The two headers Google checks when an API key is restricted to Android apps:
 * the package name and the SHA-1 of the app's signing certificate. Google's
 * Android client libraries send them; plain REST calls like ours don't, and a
 * restricted key rejects every request without them.
 *
 * Call init() once from MainActivity before the first request. The release
 * build and the .debug build have different package names and certificates;
 * the key's restriction lists both.
 */
object AndroidClientHeaders {

    @Volatile private var headers: Map<String, String> = emptyMap()

    fun init(context: Context) {
        val pkg = context.packageName
        val cert = signingCert(context, pkg) ?: return
        val sha1 = MessageDigest.getInstance("SHA-1").digest(cert.toByteArray())
        headers = mapOf(
            "X-Android-Package" to pkg,
            "X-Android-Cert" to sha1.joinToString("") { "%02X".format(it) },
        )
    }

    fun Request.Builder.androidClient(): Request.Builder = apply {
        headers.forEach { (name, value) -> header(name, value) }
    }

    @Suppress("DEPRECATION") // the int-flags getPackageInfo and GET_SIGNATURES for API 24-27
    private fun signingCert(context: Context, pkg: String): Signature? {
        val pm = context.packageManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pm.getPackageInfo(pkg, PackageManager.GET_SIGNING_CERTIFICATES)
                .signingInfo?.apkContentsSigners?.firstOrNull()
        } else {
            pm.getPackageInfo(pkg, PackageManager.GET_SIGNATURES).signatures?.firstOrNull()
        }
    }
}
