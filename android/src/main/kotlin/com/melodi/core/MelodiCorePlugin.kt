package com.melodi.core

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONObject

class MelodiCorePlugin: FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "melodi/core")
        channel?.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onDetachedFromEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val storageRoot = context?.getExternalFilesDir(null)?.absolutePath ?: context?.filesDir?.absolutePath ?: ""
                val initResult = MelodiCoreJNI.init(storageRoot)
                if (initResult == 0) {
                    result.success(mapOf(
                        "version" to MelodiCoreJNI.version(),
                        "apiVersion" to MelodiCoreJNI.apiVersion()
                    ))
                } else {
                    result.error("INIT_FAILED", "Failed to initialize MelodiCore", null)
                }
            }
            "ping" -> {
                result.success(MelodiCoreJNI.ping())
            }
            "search" -> {
                val json = JSONObject(call.arguments as? Map<String, Any> ?: emptyMap()).toString()
                val response = MelodiCoreJNI.search(json)
                result.success(response)
            }
            "match" -> {
                val json = JSONObject(call.arguments as? Map<String, Any> ?: emptyMap()).toString()
                val response = MelodiCoreJNI.match(json)
                result.success(response)
            }
            "resolve" -> {
                val json = JSONObject(call.arguments as? Map<String, Any> ?: emptyMap()).toString()
                val response = MelodiCoreJNI.resolve(json)
                result.success(response)
            }
            "download" -> {
                val json = JSONObject(call.arguments as? Map<String, Any> ?: emptyMap()).toString()
                val response = MelodiCoreJNI.download(json)
                result.success(response)
            }
            "cancelDownload" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val jobId = args["jobId"] as? String ?: ""
                MelodiCoreJNI.cancelDownload(jobId)
                result.success(null)
            }
            "getDownloadStatus" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val jobId = args["jobId"] as? String ?: ""
                val response = MelodiCoreJNI.getDownloadStatus(jobId)
                result.success(response)
            }
            "listDownloads" -> {
                val response = MelodiCoreJNI.listDownloads()
                result.success(response)
            }
            "installExtension" -> {
                val json = JSONObject(call.arguments as? Map<String, Any> ?: emptyMap()).toString()
                val response = MelodiCoreJNI.installExtension(json)
                result.success(response)
            }
            "uninstallExtension" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val id = args["id"] as? String ?: ""
                MelodiCoreJNI.uninstallExtension(id)
                result.success(null)
            }
            "enableExtension" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val id = args["id"] as? String ?: ""
                val enabled = args["enabled"] as? Boolean ?: false
                MelodiCoreJNI.enableExtension(id, enabled)
                result.success(null)
            }
            "listExtensions" -> {
                val response = MelodiCoreJNI.listExtensions()
                result.success(response)
            }
            "getExtension" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val id = args["id"] as? String ?: ""
                val response = MelodiCoreJNI.getExtension(id)
                result.success(response)
            }
            "checkExtensionHealth" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val id = args["id"] as? String ?: ""
                val response = MelodiCoreJNI.checkExtensionHealth(id)
                result.success(response)
            }
            "updateExtension" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val id = args["id"] as? String ?: ""
                val response = MelodiCoreJNI.updateExtension(id)
                result.success(response)
            }
            "updateAllExtensions" -> {
                val response = MelodiCoreJNI.updateAllExtensions()
                result.success(response)
            }
            "addRepository" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val url = args["url"] as? String ?: ""
                MelodiCoreJNI.addRepository(url)
                result.success(null)
            }
            "removeRepository" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val url = args["url"] as? String ?: ""
                MelodiCoreJNI.removeRepository(url)
                result.success(null)
            }
            "listRepositories" -> {
                val response = MelodiCoreJNI.listRepositories()
                result.success(response)
            }
            "readMetadata" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val filePath = args["filePath"] as? String ?: ""
                val response = MelodiCoreJNI.readMetadata(filePath)
                result.success(response)
            }
            "writeMetadata" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val filePath = args["filePath"] as? String ?: ""
                val tags = args["tags"] as? Map<String, Any> ?: emptyMap()
                val tagsJson = JSONObject(tags).toString()
                MelodiCoreJNI.writeMetadata(filePath, tagsJson)
                result.success(null)
            }
            "embedCoverArt" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val filePath = args["filePath"] as? String ?: ""
                val imageData = args["imageData"] as? List<Int> ?: emptyList()
                val mimeType = args["mimeType"] as? String ?: ""
                val byteArray = imageData.map { it.toByte() }.toByteArray()
                MelodiCoreJNI.embedCoverArt(filePath, byteArray, mimeType)
                result.success(null)
            }
            "embedLyrics" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val filePath = args["filePath"] as? String ?: ""
                val lyrics = args["lyrics"] as? String ?: ""
                MelodiCoreJNI.embedLyrics(filePath, lyrics)
                result.success(null)
            }
            "extractLyrics" -> {
                val args = call.arguments as? Map<String, Any> ?: emptyMap()
                val filePath = args["filePath"] as? String ?: ""
                val response = MelodiCoreJNI.extractLyrics(filePath)
                result.success(response)
            }
            "getStats" -> {
                val response = MelodiCoreJNI.getStats()
                result.success(response)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}

object MelodiCoreJNI {
    @JvmStatic
    external fun init(storageRoot: String): Int

    @JvmStatic
    external fun version(): String

    @JvmStatic
    external fun apiVersion(): String

    @JvmStatic
    external fun ping(): String

    @JvmStatic
    external fun search(requestJson: String): String

    @JvmStatic
    external fun match(requestJson: String): String

    @JvmStatic
    external fun resolve(requestJson: String): String

    @JvmStatic
    external fun download(requestJson: String): String

    @JvmStatic
    external fun cancelDownload(jobId: String)

    @JvmStatic
    external fun getDownloadStatus(jobId: String): String

    @JvmStatic
    external fun listDownloads(): String

    @JvmStatic
    external fun installExtension(requestJson: String): String

    @JvmStatic
    external fun uninstallExtension(id: String)

    @JvmStatic
    external fun enableExtension(id: String, enabled: Boolean)

    @JvmStatic
    external fun listExtensions(): String

    @JvmStatic
    external fun getExtension(id: String): String

    @JvmStatic
    external fun checkExtensionHealth(id: String): String

    @JvmStatic
    external fun updateExtension(id: String): String

    @JvmStatic
    external fun updateAllExtensions(): String

    @JvmStatic
    external fun addRepository(url: String)

    @JvmStatic
    external fun removeRepository(url: String)

    @JvmStatic
    external fun listRepositories(): String

    @JvmStatic
    external fun readMetadata(filePath: String): String

    @JvmStatic
    external fun writeMetadata(filePath: String, tagsJson: String)

    @JvmStatic
    external fun embedCoverArt(filePath: String, imageData: ByteArray, mimeType: String)

    @JvmStatic
    external fun embedLyrics(filePath: String, lyrics: String)

    @JvmStatic
    external fun extractLyrics(filePath: String): String

    @JvmStatic
    external fun getStats(): String

    companion object {
        init {
            System.loadLibrary("melodi_core")
        }
    }
}