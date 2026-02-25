package com.mawaqit.androidtv

import android.util.Log
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.plugin.common.MethodChannel
import kotlin.math.absoluteValue

/**
 * Handles all JX-11 Bluetooth ring input events.
 *
 * The JX-11 ring sends events through 3 different Android input channels:
 * - Touch events: single click left/right (horizontal swipes), roller (vertical swipes)
 * - Key events: long press left/right (VOLUME_UP/DOWN), bottom button (MEDIA_PLAY_PAUSE),
 *   middle button (single quick VOLUME press without repeat)
 * - Generic motion events: scroll wheel events
 *
 * All events are converted to named string events and sent to Flutter via MethodChannel.
 */
class Jx11RingHandler(private val channel: MethodChannel?) {

  private var touchStartX = 0f
  private var touchStartY = 0f
  private var volumeIsLongPress = false

  @Volatile
  var isEnabled: Boolean = false

  companion object {
    private const val TAG = "JX11-KEY"
    private const val DEVICE_NAME = "JX-11"
    private const val SWIPE_THRESHOLD = 50
  }

  private fun isJx11(deviceName: String?): Boolean {
    return deviceName?.contains(DEVICE_NAME, ignoreCase = true) == true
  }

  private fun sendEvent(event: String) {
    val ch = channel
    if (ch == null) {
      Log.e(TAG, "MethodChannel is null, cannot send event '$event'")
      return
    }
    try {
      ch.invokeMethod("jx11Event", event)
    } catch (e: Exception) {
      Log.e(TAG, "Failed to send event '$event'", e)
    }
  }

  /** Returns true if the event was consumed. */
  fun handleGenericMotionEvent(event: MotionEvent): Boolean {
    if (!isEnabled || !isJx11(event.device?.name)) return false

    val scrollX = event.getAxisValue(MotionEvent.AXIS_HSCROLL)
    val scrollY = event.getAxisValue(MotionEvent.AXIS_VSCROLL)
    if (scrollX != 0f || scrollY != 0f) {
      val direction = if (scrollX != 0f) {
        if (scrollX > 0) "swipeRight" else "swipeLeft"
      } else {
        if (scrollY > 0) "rollerUp" else "rollerDown"
      }
      sendEvent(direction)
      return true
    }
    if (event.action == MotionEvent.ACTION_BUTTON_PRESS ||
        event.action == MotionEvent.ACTION_DOWN) {
      sendEvent("middleButton")
      return true
    }
    return false
  }

  /** Returns true if the event was consumed. */
  fun handleTouchEvent(event: MotionEvent): Boolean {
    if (!isEnabled || !isJx11(event.device?.name)) return false

    when (event.action) {
      MotionEvent.ACTION_DOWN -> {
        touchStartX = event.x
        touchStartY = event.y
      }
      MotionEvent.ACTION_UP -> {
        val dx = event.x - touchStartX
        val dy = event.y - touchStartY
        val absDx = dx.absoluteValue
        val absDy = dy.absoluteValue

        if (absDx > absDy && absDx > SWIPE_THRESHOLD) {
          sendEvent(if (dx > 0) "swipeRight" else "swipeLeft")
        } else if (absDy > absDx && absDy > SWIPE_THRESHOLD) {
          sendEvent(if (dy > 0) "rollerDown" else "rollerUp")
        } else {
          sendEvent("tap")
        }
      }
    }
    return true // Consume ALL JX-11 touch events
  }

  /** Returns true if the key event was from JX-11 and consumed. */
  fun handleKeyDown(keyCode: Int, event: KeyEvent): Boolean {
    if (!isEnabled || !isJx11(event.device?.name)) return false

    when (keyCode) {
      KeyEvent.KEYCODE_VOLUME_UP,
      KeyEvent.KEYCODE_VOLUME_DOWN -> {
        if (event.repeatCount > 0) {
          // Long press (repeated) → page navigation
          volumeIsLongPress = true
          sendEvent(if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) "volumeUp" else "volumeDown")
        } else {
          // First press — could be middle button or start of long press
          volumeIsLongPress = false
        }
        return true
      }
      KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
        sendEvent("playPause")
        return true
      }
    }
    return false
  }

  /** Returns true if the key event was from JX-11 and consumed. */
  fun handleKeyUp(keyCode: Int, event: KeyEvent): Boolean {
    if (!isEnabled || !isJx11(event.device?.name)) return false

    when (keyCode) {
      KeyEvent.KEYCODE_VOLUME_UP,
      KeyEvent.KEYCODE_VOLUME_DOWN -> {
        if (!volumeIsLongPress) {
          // Quick press and release with no repeats → middle button
          sendEvent("middleButton")
        }
        volumeIsLongPress = false
        return true
      }
      KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> return true
    }
    return false
  }
}
