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
import android.net.wifi.WifiManager
import android.net.wifi.WifiInfo
import android.net.wifi.SupplicantState
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
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
   * SupplicantState.COMPLETED is the right signal for "did the password
   * work": a wrong PSK fails the 4-way handshake and never reaches COMPLETED,
   * while a correct PSK reaches COMPLETED even on networks that have no
   * internet or a slow captive-portal check (which would otherwise leave
   * NET_CAPABILITY_VALIDATED unset and produce a false failure on devices
   * like MAWAQITBOX V2).
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

    // Validated internet is the strongest signal, but it's not required —
    // many setups never get NET_CAPABILITY_VALIDATED yet are fully usable.
    if (VERSION.SDK_INT >= VERSION_CODES.M && hasValidatedWifi()) {
      return matchesTarget(info, targetSsid, targetNetworkId)
    }

    // Fall back to supplicant state: COMPLETED means the 4-way handshake
    // succeeded, which a wrong password cannot achieve.
    if (info.supplicantState != SupplicantState.COMPLETED) return false
    return matchesTarget(info, targetSsid, targetNetworkId)
  }

  private fun hasValidatedWifi(): Boolean {
    val cm =
      applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    return cm.allNetworks.any { network ->
      val caps = cm.getNetworkCapabilities(network)
      caps != null &&
        caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
        caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
  }

  /**
   * True when [info] is the network we tried to connect to. When both the SSID
   * and networkId are hidden (location services off) we cannot tell, so we
   * trust the validated connection rather than reporting a false failure.
   */
  private fun matchesTarget(info: WifiInfo?, targetSsid: String?, targetNetworkId: Int?): Boolean {
    if (info == null) return true
    if (targetNetworkId != null && targetNetworkId != -1 && info.networkId != -1) {
      return info.networkId == targetNetworkId
    }
    val ssid = normalizeSsid(info.ssid)
    if (ssid.isEmpty() || ssid == WifiManager.UNKNOWN_SSID) return true
    return targetSsid == null || ssid == targetSsid
  }

  private fun connectToWifi(call: MethodCall, result: MethodChannel.Result) {
    AsyncTask.execute {
      try {
        val ssid = call.argument<String>("ssid") ?: ""
        val password = call.argument<String>("password")
        val capabilities = call.argument<String>("security")
        val security = getSecurityType(capabilities, password)

        val command = if (password.isNullOrEmpty()) {
          "cmd wifi connect-network ${shellEscape(ssid)} open"
        } else {
          "cmd wifi connect-network ${shellEscape(ssid)} $security ${shellEscape(password)}"
        }

        Log.i("SU_COMMAND", "Wifi Command: $command")

        val suProcess = Runtime.getRuntime().exec("su")
        val os = DataOutputStream(suProcess.outputStream)
        os.writeBytes("$command\n")
        os.flush()
        os.close()

        val output = BufferedReader(InputStreamReader(suProcess.inputStream)).readText()
        val error = BufferedReader(InputStreamReader(suProcess.errorStream)).readText()
        val exitCode = suProcess.waitFor()

        Log.i("SU_COMMAND", "Command output: $output")
        Log.e("SU_COMMAND", "Command error: $error")
        Log.d("SU_COMMAND", "Exit code: $exitCode")

        if (exitCode != 0 || output.contains("Connection failed") || output.contains("Invalid args")) {
          Log.e("SU_COMMAND", "Command failed with exit code $exitCode.")
          result.success(false)
          return@execute
        }

        // Verify the device actually reached the requested network with
        // working internet. Checking only that *some* network is connected
        // reports false results in both directions (see awaitWifiConnected).
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
