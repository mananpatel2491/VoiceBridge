package com.mananpatel.voicebridge

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

object TranslationService {

    private const val ENDPOINT = "https://translation.googleapis.com/language/translate/v2"

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    suspend fun translate(text: String, apiKey: String): Result<String> =
        withContext(Dispatchers.IO) {
            runCatching {
                if (apiKey.isBlank()) {
                    error(
                        "GCP_STT_API_KEY is not set in local.properties. " +
                        "The same key covers Cloud Translation -- enable 'Cloud Translation API' " +
                        "in the same GCP project you used for STT."
                    )
                }

                val requestJson = JSONObject().apply {
                    put("q", text)
                    put("source", "gu")
                    put("target", "en")
                    put("format", "text")
                }.toString()

                val request = Request.Builder()
                    .url("$ENDPOINT?key=$apiKey")
                    .post(requestJson.toRequestBody("application/json; charset=utf-8".toMediaType()))
                    .build()

                val response = httpClient.newCall(request).execute()
                val responseBody = response.body?.string()
                    ?: error("Empty response body from Cloud Translation API.")

                if (!response.isSuccessful) {
                    val gcpMessage = runCatching {
                        JSONObject(responseBody)
                            .optJSONObject("error")
                            ?.optString("message")
                    }.getOrNull()
                    error("Translation API error ${response.code}: ${gcpMessage ?: responseBody}")
                }

                JSONObject(responseBody)
                    .getJSONObject("data")
                    .getJSONArray("translations")
                    .getJSONObject(0)
                    .getString("translatedText")
            }
        }
}
