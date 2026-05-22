package com.mawaqit.androidtv

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.DataOutputStream
import java.io.InputStreamReader
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Settings
import android.content.Intent
import android.net.Uri
import java.io.File
import android.content.Context
import android.content.ComponentName
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.app.admin.DevicePolicyManager
import java.io.IOException
import android.app.KeyguardManager
import android.os.AsyncTask
import android.util.Log
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiInfo
import android.net.wifi.SupplicantState
import java.util.concurrent.Executors
import android.os.Looper
import android.os.Handler
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.app.AlarmManager
import android.view.KeyEvent
import android.view.MotionEvent
class MainActivity : FlutterActivity() {
  private lateinit var mAdminComponentName: ComponentName
  private lateinit var mDevicePolicyManager: DevicePolicyManager

  private var jx11Handler: Jx11RingHandler? = null

  // --- JX-11 ring: forward raw input to handler, fall through for other devices ---
  override fun dispatchGenericMotionEvent(event: MotionEvent) =
    jx11Handler?.handleGenericMotionEvent(event) == true || super.dispatchGenericMotionEvent(event)

  override fun dispatchTouchEvent(event: MotionEvent) =
    jx11Handler?.handleTouchEvent(event) == true || super.dispatchTouchEvent(event)

  override fun onKeyDown(keyCode: Int, event: KeyEvent) =
    jx11Handler?.handleKeyDown(keyCode, event) == true || super.onKeyDown(keyCode, event)

  override fun onKeyUp(keyCode: Int, event: KeyEvent) =
    jx11Handler?.handleKeyUp(keyCode, event) == true || super.onKeyUp(keyCode, event)

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    val jx11Channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jx11Channel")
    jx11Handler = Jx11RingHandler(jx11Channel)

    // Allow Flutter to enable/disable JX-11 input handling per screen
    jx11Channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "setEnabled" -> {
          jx11Handler?.isEnabled = call.arguments as? Boolean ?: false
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nativeMethodsChannel")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "setDeviceTimezone" -> setDeviceTimezone(call, result)
          "connectToWifi" -> connectToWifi(call, result)
          "isPackageInstalled" -> {
            val packageName = call.argument<String>("packageName")
            if (packageName != null) {
              val isInstalled = isPackageInstalled(packageName)
              result.success(isInstalled)
            } else {
              result.error("INVALID_ARGUMENT", "Package name is null", null)
            }
          }

          "checkRoot" -> result.success(checkRoot())
          "addLocationPermission" -> addLocationPermission(call, result)
          "grantFineLocationPermission" -> grantFineLocationPermission(call, result)
          "grantOverlayPermission" -> grantOverlayPermission(call, result)
          "sendDownArrowEvent" -> sendDownArrowEvent(call, result)
          "sendTabKeyEvent" -> sendTabKeyEvent(call, result)
          "clearAppData" -> {
            val isSuccess = clearDataRestart()
            result.success(isSuccess)
          }
          "enableBatteryOptimization" -> enableBatteryOptimization(call, result)
          "DisableDozeMode" -> disableDozeMode(call, result)
          "grantOnvoOverlayPermission" -> {
            val isSuccess = grantOnvoOverlayPermission()
            result.success(isSuccess)
          }
          "openOnvoStore" -> {
            val isSuccess = openOnvoStore()
            result.success(isSuccess)
          }
          "requestExactAlarmPermission" -> {
            if (VERSION.SDK_INT >= VERSION_CODES.S) {
              val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.fromParts("package", "com.mawaqit.androidtv", null)
              }
              startActivity(intent)
              result.success(true)
            } else {
              result.success(true)
            }
          }
          "checkExactAlarmPermission" -> {
              val canSchedule = if (VERSION.SDK_INT >= VERSION_CODES.S) {
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarmManager.canScheduleExactAlarms()
              } else {
                true
              }
              result.success(canSchedule)
            }
          "installApkRoot" -> {
            val filePath = call.argument<String>("filePath")
            if (filePath != null) {
              try {
                val file = File(filePath)
                if (!file.exists()) {
                  result.error("FILE_NOT_FOUND", "APK file not found", null)
                  return@setMethodCallHandler
                }
                if (!checkRoot()) {
                  result.error("NOT_ROOTED", "Device is not rooted", null)
                  return@setMethodCallHandler
                }
                executeCommand(listOf("pm install -r $filePath"), result)
              } catch (e: Exception) {
                Log.e("APK_INSTALL", "Failed to install APK via root", e)
                result.error("INSTALL_FAILED", e.message, null)
              }
            } else {
              result.error("INVALID_PATH", "File path is null", null)
            }
          }

          else -> result.notImplemented()
        }
      }
  }

  private fun checkRoot(): Boolean {
    return try {
      val p = Runtime.getRuntime().exec("su")
      val os = DataOutputStream(p.outputStream)
      os.writeBytes("echo \"Do I have root?\" >/data/LandeRootCheck.txt\n")
      os.writeBytes("exit\n")
      os.flush()
      p.waitFor()
      p.exitValue() == 0
    } catch (e: Exception) {
      false
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val REQUEST_OVERLAY_PERMISSIONS = 100
    if (checkRoot() && !Settings.canDrawOverlays(applicationContext)) {
      try {
        val command = "appops set com.mawaqit.androidtv SYSTEM_ALERT_WINDOW allow"
        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", command))
        val outputStream = DataOutputStream(process.outputStream)
        outputStream.writeBytes(command + "\n")
        outputStream.flush()
        outputStream.close()
        process.waitFor()
      } catch (e: Exception) {
        e.printStackTrace()
      }
    }
  }

  private fun grantOnvoOverlayPermission(): Boolean {
    return try {
      val processBuilder = ProcessBuilder()
      val command = "sh -c appops set com.mawaqit.androidtv SYSTEM_ALERT_WINDOW allow"

      processBuilder.command(
        "sh", "-c", """
            appops set com.mawaqit.androidtv SYSTEM_ALERT_WINDOW allow
        """.trimIndent()
      )

      val process = processBuilder.start()
      val exitCode = process.waitFor()

      exitCode == 0
    } catch (e: Exception) {
      e.printStackTrace()
      false
    }
  }
  
  private fun openOnvoStore(): Boolean {
    return try {
      val processBuilder = ProcessBuilder()

      processBuilder.command(
        "sh", "-c", """
            am start com.stark.store
        """.trimIndent()
      )

      val process = processBuilder.start()
      val exitCode = process.waitFor()

      exitCode == 0
    } catch (e: Exception) {
      e.printStackTrace()
      false
    }
  }

  private fun setDeviceTimezone(call: MethodCall, result: MethodChannel.Result) {
    AsyncTask.execute {
      try {
        val timezone = call.argument<String>("timezone")
        executeCommand(listOf("service call alarm 3 s16 $timezone"), result)
      } catch (e: Exception) {
        handleCommandException(e, result)
      }
    }
  }

  private fun addLocationPermission(call: MethodCall, result: MethodChannel.Result) {
    AsyncTask.execute {
      try {
        executeCommand(listOf("settings put secure location_mode 3"), result)
      } catch (e: Exception) {
        handleCommandException(e, result)
      }
    }
  }

  private fun isPackageInstalled(packageName: String?): Boolean {
    val packageManager = applicationContext.packageManager
    return try {
      packageManager.getPackageInfo(packageName!!, PackageManager.GET_ACTIVITIES)
      true
    } catch (e: PackageManager.NameNotFoundException) {
      false
    }
  }


  /** Wraps a string in single quotes and escapes any single quotes inside it.
   *  Safe against shell special characters: $, `, \, ", spaces, etc. */
  private fun shellEscape(value: String): String = "'" + value.replace("'", "'\\''") + "'"

  /** Derives cmd-wifi security type from the raw capabilities string reported by the scan. */
  private fun getSecurityType(capabilities: String?, password: String?): String {
    if (password.isNullOrEmpty()) return "open"
    if (capabilities == null) return "wpa2"
    return when {
      capabilities.contains("WPA3") || capabilities.contains("SAE") -> "wpa3"
      capabilities.contains("WPA2") || capabilities.contains("WPA") -> "wpa2"
      capabilities.contains("WEP") -> "wep"
      else -> "open"
    }
  }

  /** Strips the surrounding quotes Android wraps around SSIDs in WifiInfo. */
  private fun normalizeSsid(ssid: String?): String = ssid?.removeSurrounding("\"") ?: ""

  /**
   * Polls until the supplicant reports a completed handshake on the target
   * network (i.e. the password was accepted), or [timeoutMs] elapses.
   *
   * SupplicantState.COMPLETED is the only safe success signal: a wrong PSK
   * fails the 4-way handshake and never reaches COMPLETED, while a correct
   * PSK reaches it even when the network has no internet / slow captive-portal
   * check. We deliberately ignore NET_CAPABILITY_VALIDATED here because a
   * previously-connected validated network lingers in ConnectivityManager
   * during our attempt and would mask a wrong-password failure.
   */
  private fun awaitWifiConnected(
    targetSsid: String?,
    targetNetworkId: Int?,
    timeoutMs: Long = 15000,
  ): Boolean {
    val deadline = System.currentTimeMillis() + timeoutMs
    while (System.currentTimeMillis() < deadline) {
      if (isConnectedToTargetWifi(targetSsid, targetNetworkId)) return true
      Thread.sleep(500)
    }
    return false
  }

  private fun isConnectedToTargetWifi(targetSsid: String?, targetNetworkId: Int?): Boolean {
    val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    val info = wifiManager.connectionInfo ?: return false
    if (info.supplicantState != SupplicantState.COMPLETED) return false
    return matchesTarget(info, targetSsid, targetNetworkId)
  }

  /**
   * Strict identity check. Returns true only when [info] is positively the
   * network we asked for — either by networkId or by SSID. If neither is
   * available (transient DISCONNECTED state, redacted SSID) we report no-match
   * so a wrong-password attempt can't squeak through on the back of a previous
   * connection's lingering state.
   */
  private fun matchesTarget(info: WifiInfo, targetSsid: String?, targetNetworkId: Int?): Boolean {
    if (targetNetworkId != null && targetNetworkId != -1 && info.networkId != -1) {
      return info.networkId == targetNetworkId
    }
    val ssid = normalizeSsid(info.ssid)
    if (ssid.isEmpty() || ssid == WifiManager.UNKNOWN_SSID) return false
    return targetSsid == null || ssid == targetSsid
  }

  private fun connectToWifi(call: MethodCall, result: MethodChannel.Result) {
    AsyncTask.execute {
      try {
        val ssid = call.argument<String>("ssid") ?: ""
        val password = call.argument<String>("password")
        val capabilities = call.argument<String>("security")
        val security = getSecurityType(capabilities, password)

        // Prefer `cmd wifi connect-network` (added in API 30 / Android 11).
        // Older boxes like MAWAQITBOX V2 (API 29) reject it with
        // "Unknown command", in which case we fall back to the legacy
        // WifiManager.addNetwork() path.
        val command = if (password.isNullOrEmpty()) {
          "cmd wifi connect-network ${shellEscape(ssid)} open"
        } else {
          "cmd wifi connect-network ${shellEscape(ssid)} $security ${shellEscape(password)}"
        }

        Log.i("SU_COMMAND", "Wifi Command: $command")

        val cmd = runSuCommand(command)
        Log.i("SU_COMMAND", "Command output: ${cmd.output}")
        Log.e("SU_COMMAND", "Command error: ${cmd.error}")
        Log.d("SU_COMMAND", "Exit code: ${cmd.exitCode}")

        val cmdUnsupported = cmd.error.contains("Unknown command", ignoreCase = true) ||
          cmd.output.contains("Unknown command", ignoreCase = true)
        if (cmdUnsupported) {
          Log.i("SU_COMMAND", "cmd wifi connect-network unsupported, falling back to WifiManager.")
          connectViaWifiManager(ssid, password, result)
          return@execute
        }

        if (cmd.exitCode != 0 ||
          cmd.output.contains("Connection failed") ||
          cmd.output.contains("Invalid args")
        ) {
          Log.e("SU_COMMAND", "Command failed with exit code ${cmd.exitCode}.")
          result.success(false)
          return@execute
        }

        val connected = awaitWifiConnected(targetSsid = ssid, targetNetworkId = null)
        if (connected) {
          Log.i("SU_COMMAND", "Connected to $ssid successfully.")
        } else {
          Log.e("SU_COMMAND", "Failed to connect to $ssid (wrong password or timeout).")
        }
        result.success(connected)

      } catch (e: Exception) {
        handleCommandException(e, result)
      }
    }
  }

  private data class SuResult(val output: String, val error: String, val exitCode: Int)

  private fun runSuCommand(command: String): SuResult {
    val process = Runtime.getRuntime().exec("su")
    val os = DataOutputStream(process.outputStream)
    os.writeBytes("$command\n")
    os.flush()
    os.close()
    val output = BufferedReader(InputStreamReader(process.inputStream)).readText()
    val error = BufferedReader(InputStreamReader(process.errorStream)).readText()
    return SuResult(output, error, process.waitFor())
  }

  /**
   * Legacy connect path for boxes whose Android build doesn't ship
   * `cmd wifi connect-network` (MAWAQITBOX V2 on API 29). Uses the deprecated
   * WifiManager.addNetwork() API which still works on these devices.
   */
  private fun connectViaWifiManager(
    ssid: String,
    password: String?,
    result: MethodChannel.Result,
  ) {
    try {
      val conf = WifiConfiguration().apply {
        SSID = "\"$ssid\""
        status = WifiConfiguration.Status.ENABLED
        allowedGroupCiphers.set(WifiConfiguration.GroupCipher.TKIP)
        allowedGroupCiphers.set(WifiConfiguration.GroupCipher.CCMP)
        allowedPairwiseCiphers.set(WifiConfiguration.PairwiseCipher.TKIP)
        allowedPairwiseCiphers.set(WifiConfiguration.PairwiseCipher.CCMP)
        if (password.isNullOrEmpty()) {
          allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
        } else {
          preSharedKey = "\"$password\""
          allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
        }
      }

      val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
      val networkId = wifiManager.addNetwork(conf)
      if (networkId == -1) {
        Log.e("WIFI_LEGACY", "addNetwork returned -1 for SSID $ssid")
        result.success(false)
        return
      }
      wifiManager.disconnect()
      wifiManager.enableNetwork(networkId, true)
      wifiManager.reconnect()

      val connected = awaitWifiConnected(targetSsid = ssid, targetNetworkId = networkId)
      if (connected) {
        Log.i("WIFI_LEGACY", "Connected to $ssid via WifiManager.")
      } else {
        Log.e("WIFI_LEGACY", "Failed to connect to $ssid (wrong password or timeout).")
        // Drop the bad config so Android doesn't keep retrying it.
        wifiManager.removeNetwork(networkId)
      }
      result.success(connected)
    } catch (ex: Exception) {
      Log.e("WIFI_LEGACY", "Error connecting to network", ex)
      result.error("exception", ex.message, ex)
    }
  }

  private fun clearDataRestart(): Boolean {
    return try {
      val processBuilder = ProcessBuilder()
      processBuilder.command(
        "sh", "-c", """
                pm clear com.mawaqit.androidtv
            """.trimIndent()
      )
      val process = processBuilder.start()
      val exitCode = process.waitFor()
      exitCode == 0
    } catch (e: Exception) {
      e.printStackTrace()
      false
    }
  }

  private fun enableBatteryOptimization(call: MethodCall, result: MethodChannel.Result) {
    AsyncTask.execute {
      try {
        val commands = listOf(
          "dumpsys deviceidle whitelist +com.mawaqit.androidtv",

          )
        executeCommand(commands, result) // Lock the device
      } catch (e: Exception) {
        handleCommandException(e, result)
      }
    }
  }
  private fun disableDozeMode(call: MethodCall, result: MethodChannel.Result) {
    AsyncTask.execute {
      try {
        val commands = listOf(
          "dumpsys deviceidle disable",
          )
        executeCommand(commands, result) // Lock the device
      } catch (e: Exception) {
        handleCommandException(e, result)
      }
    }
  }
  private fun grantFineLocationPermission(call: MethodCall, result: MethodChannel.Result) {
    AsyncTask.execute {
      try {
        val commands = listOf(
          "pm grant com.mawaqit.androidtv android.permission.ACCESS_FINE_LOCATION",

          )
        executeCommand(commands, result) // Lock the device
      } catch (e: Exception) {
        handleCommandException(e, result)
      }
    }
  }

  private fun grantOverlayPermission(call: MethodCall, result: MethodChannel.Result) {
    AsyncTask.execute {
      try {
        val commands = listOf(
          "appops set com.mawaqit.androidtv SYSTEM_ALERT_WINDOW allow",

          )
        executeCommand(commands, result) // Lock the device
      } catch (e: Exception) {
        handleCommandException(e, result)
      }
    }
  }


  private fun sendDownArrowEvent(call: MethodCall, result: MethodChannel.Result) {
    AsyncTask.execute {
      try {
        val commands = listOf(
          "input keyevent 20"
        )
        executeCommand(commands, result)
      } catch (e: Exception) {
        handleCommandException(e, result)
      }
    }
  }

  private fun sendTabKeyEvent(call: MethodCall, result: MethodChannel.Result) {
    AsyncTask.execute {
      try {
        val commands = listOf(
          "input keyevent 61"
        )
        executeCommand(commands, result)
      } catch (e: Exception) {
        handleCommandException(e, result)
      }
    }
  }


  private fun executeCommand(commands: List<String>, result: MethodChannel.Result) {
    try {
      Log.d("SU_COMMAND", "Executing commands: ${commands.joinToString(separator = " && ")}")

      val suProcess = Runtime.getRuntime().exec("su")
      val os = DataOutputStream(suProcess.outputStream)

      val command = commands.joinToString(separator = " && ") + "\n"
      Log.d("SU_COMMAND", "Writing command to DataOutputStream: $command")
      os.writeBytes(command)
      os.flush()
      os.close()

      val output = BufferedReader(InputStreamReader(suProcess.inputStream)).readText()
      val error = BufferedReader(InputStreamReader(suProcess.errorStream)).readText()

      Log.i("SU_COMMAND", "Command output: $output")
      Log.e("SU_COMMAND", "Command error: $error")

      val exitCode = suProcess.waitFor()
      Log.d("SU_COMMAND", "Exit code: $exitCode")

      if (exitCode != 0 || output.contains("Connection failed")) {
        Log.e("SU_COMMAND", "Command failed with exit code $exitCode.")
        result.success(false)
      } else {
        Log.i("SU_COMMAND", "Command executed successfully.")
        result.success(true)
      }
    } catch (e: Exception) {
      Log.e("SU_COMMAND", "Exception occurred: ${e.message}")
      handleCommandException(e, result)
    }
  }


  private fun handleCommandException(e: Exception, result: MethodChannel.Result) {
    result.error("Exception", "An exception occurred: $e", null)
  }
}
