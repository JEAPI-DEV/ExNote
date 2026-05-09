package com.example.excerciser

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {

	private val channelName = "com.example.excerciser/stylus"
	private val actionOppoPencilDoubleClick = "com.oplus.ipemanager.action.PENCIL_DOUBLE_CLICK"
	private val oemBroadcastPermission = "com.oplus.ipemanager.permission.receiver.DOUBLE_CLICK"

	private var methodChannel: MethodChannel? = null
	private var isReceiverRegistered = false
	private var lastStylusPrimaryPressTime = 0L
	private var stylusPrimaryPressed = false

	private val pencilReceiver = object : BroadcastReceiver() {
		override fun onReceive(context: Context?, intent: Intent?) {
			val receivedAction = intent?.action ?: return
			if (receivedAction == actionOppoPencilDoubleClick) {
				Log.i(TAG, "Received OPPO PENCIL_DOUBLE_CLICK broadcast")
				Handler(Looper.getMainLooper()).post {
					methodChannel?.invokeMethod("stylusDoubleClick", null)
				}
			}
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
	}

	override fun onResume() {
		super.onResume()
		val shouldRegister = shouldRegisterReceiver()
		Log.d(
			TAG,
			"onResume: manufacturer='${Build.MANUFACTURER}' brand='${Build.BRAND}' shouldRegister=$shouldRegister"
		)
		if (shouldRegister && !isReceiverRegistered) {
			val filter = IntentFilter(actionOppoPencilDoubleClick)
			try {
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
					applicationContext.registerReceiver(
						pencilReceiver,
						filter,
						oemBroadcastPermission,
						null,
						Context.RECEIVER_EXPORTED
					)
				} else {
					applicationContext.registerReceiver(
						pencilReceiver,
						filter,
						oemBroadcastPermission,
						null
					)
				}
				isReceiverRegistered = true
				Log.d(TAG, "Registered pencilReceiver (appCtx)")
			} catch (ex: SecurityException) {
				Log.w(TAG, "SecurityException registering pencilReceiver: ${ex.message}")
			} catch (ex: Exception) {
				Log.w(TAG, "Unexpected exception registering pencilReceiver: ${ex.message}")
			}
		}
	}

	override fun onPause() {
		super.onPause()
		if (isReceiverRegistered) {
			try {
				applicationContext.unregisterReceiver(pencilReceiver)
				Log.d(TAG, "Unregistered pencilReceiver (appCtx)")
			} catch (ex: IllegalArgumentException) {
				Log.d(TAG, "pencilReceiver already unregistered: ${ex.message}")
			} finally {
				isReceiverRegistered = false
			}
		}
	}

	override fun onDestroy() {
		methodChannel = null
		super.onDestroy()
	}

	override fun dispatchTouchEvent(event: MotionEvent): Boolean {
		handleStylusPrimaryButton(event)
		return super.dispatchTouchEvent(event)
	}

	override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
		handleStylusPrimaryButton(event)
		return super.dispatchGenericMotionEvent(event)
	}

	private fun shouldRegisterReceiver(): Boolean {
		if (!isOppoFamilyDevice()) {
			return false
		}

		val manufacturer = Build.MANUFACTURER?.lowercase(Locale.US) ?: ""
		val brand = Build.BRAND?.lowercase(Locale.US) ?: ""
		return manufacturer.contains("oppo") ||
			manufacturer.contains("oneplus") ||
			brand.contains("oppo") ||
			brand.contains("oneplus")
	}

	private fun isOppoFamilyDevice(): Boolean {
		val manufacturer = Build.MANUFACTURER?.lowercase(Locale.US) ?: ""
		val brand = Build.BRAND?.lowercase(Locale.US) ?: ""
		return manufacturer.contains("oppo") ||
			manufacturer.contains("oneplus") ||
			brand.contains("oppo") ||
			brand.contains("oneplus")
	}

	private fun handleStylusPrimaryButton(event: MotionEvent) {
		if (isOppoFamilyDevice()) {
			return
		}

		if (!eventContainsStylus(event)) {
			stylusPrimaryPressed = false
			return
		}

		val isPressed = (event.buttonState and MotionEvent.BUTTON_STYLUS_PRIMARY) != 0
		if (isPressed && !stylusPrimaryPressed) {
			val currentEventTime = event.eventTime
			if (currentEventTime - lastStylusPrimaryPressTime <= STYLUS_DOUBLE_TAP_WINDOW_MS) {
				Log.i(TAG, "Detected stylus double press from motion events")
				methodChannel?.invokeMethod("stylusDoubleClick", null)
				lastStylusPrimaryPressTime = 0L
			} else {
				lastStylusPrimaryPressTime = currentEventTime
			}
		}

		stylusPrimaryPressed = isPressed
	}

	private fun eventContainsStylus(event: MotionEvent): Boolean {
		for (i in 0 until event.pointerCount) {
			val toolType = event.getToolType(i)
			if (toolType == MotionEvent.TOOL_TYPE_STYLUS ||
				toolType == MotionEvent.TOOL_TYPE_ERASER
			) {
				return true
			}
		}
		return false
	}

	companion object {
		private const val TAG = "PencilDemo"
		private const val STYLUS_DOUBLE_TAP_WINDOW_MS = 250L
	}
}
