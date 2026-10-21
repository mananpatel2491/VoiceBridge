package com.mananpatel.voicebridge

import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Sends a recorded WAV file to the Google Cloud Speech-to-Text v1 REST API
 * and returns the Gujarati transcript.
 *
 * Audio contract: WAV produced by AudioRecorder (PCM 16-bit, 16 kHz, mono).
 * The 44-byte WAV header is stripped before sending; GCP STT receives raw
 * LINEAR16 PCM bytes encoded as base64.
 *
 * Errors (network, auth, bad audio, no speech detected) surface as
 * Result.failure with a human-readable message — the caller decides how to
 * display them.
 */
object SttService {

    private const val STT_ENDPOINT = "https://speech.googleapis.com/v1/speech:recognize"
    private const val WAV_HEADER_BYTES = 44

    /**
     * Phrase hints (speechContexts) for words the gu-IN model mishears as common
     * words, e.g. કીટલી → કેટલી, લપ → લગ્ન, માણેક ચોક → માણસ: Amdavadi slang,
     * Ahmedabad places, Gujarati foods and festivals. Keep it general; don't add
     * a test script's sentences, or the test stops measuring anything.
     */
    private val PHRASE_HINTS = listOf(
        // Slang
        "અલ્યા", "લ્યા", "બકા", "હેંડ", "હેંડ ને", "હેંડો", "કીટલી", "કટિંગ ચા",
        "એક નંબર", "ડખો", "લપ", "ઢીલું ના મૂક", "જલસો", "જલસો પડી જશે", "મોજ",
        "મોજે મોજ", "ભાઈબંધ", "ટાઈમપાસ", "વટ", "શું ચાલે", "મજામાં", "હોં",
        // Places
        "માણેક ચોક", "કાંકરિયા", "રિવરફ્રન્ટ", "લો ગાર્ડન", "સી જી રોડ",
        "એસ જી હાઈવે", "ભદ્ર", "પોળ", "ખાડિયા", "મણિનગર", "નવરંગપુરા",
        "સાબરમતી", "લાલ દરવાજા",
        // Food
        "ફાફડા", "જલેબી", "ખમણ", "ઢોકળા", "ગોટા", "દાબેલી", "ખાખરા",
        "થેપલા", "ઊંધિયું", "ચીક્કી",
        // Festivals and everyday words
        "ઉત્તરાયણ", "પતંગ", "દોરી", "ફિરકી", "ધાબા", "કાઈપો છે", "લપેટ",
        "નવરાત્રી", "ગરબા", "એક્ટિવા",
    )
    private const val PHRASE_BOOST = 10.0

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    suspend fun transcribe(audioFile: File, apiKey: String): Result<String> =
        withContext(Dispatchers.IO) {
            runCatching {
                val allBytes = audioFile.readBytes()
                if (allBytes.size <= WAV_HEADER_BYTES) {
                    error("Recording is empty or too short to transcribe.")
                }

                // Strip WAV header — send only raw PCM as LINEAR16
                val pcmBytes = allBytes.copyOfRange(WAV_HEADER_BYTES, allBytes.size)
                val audioContent = Base64.encodeToString(pcmBytes, Base64.NO_WRAP)

                val requestJson = JSONObject().apply {
                    put("config", JSONObject().apply {
                        put("encoding", "LINEAR16")
                        put("sampleRateHertz", AudioRecorder.SAMPLE_RATE)
                        put("languageCode", "gu-IN")
                        put("speechContexts", JSONArray().put(JSONObject().apply {
                            put("phrases", JSONArray(PHRASE_HINTS))
                            put("boost", PHRASE_BOOST)
                        }))
                    })
                    put("audio", JSONObject().apply {
                        put("content", audioContent)
                    })
                }.toString()

                val request = Request.Builder()
                    .url("$STT_ENDPOINT?key=$apiKey")
                    .post(requestJson.toRequestBody("application/json".toMediaType()))
                    .build()

                val response = httpClient.newCall(request).execute()
                val responseBody = response.body?.string()
                    ?: error("Empty response body from GCP STT.")

                if (!response.isSuccessful) {
                    // Extract the GCP error message when available
                    val gcpMessage = runCatching {
                        JSONObject(responseBody)
                            .optJSONObject("error")
                            ?.optString("message")
                    }.getOrNull()
                    error("GCP STT error ${response.code}: ${gcpMessage ?: responseBody}")
                }

                val results = JSONObject(responseBody).optJSONArray("results")
                if (results == null || results.length() == 0) {
                    return@runCatching ""  // Valid response but no speech detected
                }

                buildString {
                    for (i in 0 until results.length()) {
                        val alternatives = results.getJSONObject(i).optJSONArray("alternatives")
                        if (alternatives != null && alternatives.length() > 0) {
                            if (isNotEmpty()) append(" ")
                            append(alternatives.getJSONObject(0).optString("transcript"))
                        }
                    }
                }
            }
        }
}
