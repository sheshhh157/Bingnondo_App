package com.example.bingnondo_app

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var startupOverlay: FrameLayout? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = launchBackground
        window.navigationBarColor = launchBackground

        val content = findViewById<FrameLayout>(android.R.id.content)
        val mascotSize = dp(88)
        val progressWidth = (resources.displayMetrics.widthPixels * 0.7f)
            .toInt()
            .coerceAtMost(dp(240))

        val contentColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            addView(
                ImageView(this@MainActivity).apply {
                    setImageResource(R.drawable.launch_cat)
                    scaleType = ImageView.ScaleType.FIT_CENTER
                },
                LinearLayout.LayoutParams(mascotSize, mascotSize),
            )
            addView(
                IndeterminateStartupBar(this@MainActivity),
                LinearLayout.LayoutParams(progressWidth, dp(5)).apply {
                    topMargin = dp(24)
                },
            )
        }

        startupOverlay = FrameLayout(this).apply {
            setBackgroundColor(launchBackground)
            isClickable = true
            addView(
                contentColumn,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER,
                ),
            )
        }
        content.addView(
            startupOverlay,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STARTUP_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method == "hide") {
                hideStartupOverlay()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun hideStartupOverlay() {
        val overlay = startupOverlay ?: return
        startupOverlay = null
        overlay.animate()
            .alpha(0f)
            .setDuration(180)
            .withEndAction {
                (overlay.parent as? ViewGroup)?.removeView(overlay)
            }
            .start()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private class IndeterminateStartupBar(context: Context) : View(context) {
        private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(64, 255, 255, 255)
        }
        private val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
        }
        private var progressOffset = 0f
        private val animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1100
            repeatCount = ValueAnimator.INFINITE
            addUpdateListener {
                progressOffset = it.animatedValue as Float
                invalidate()
            }
        }

        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            animator.start()
        }

        override fun onDetachedFromWindow() {
            animator.cancel()
            super.onDetachedFromWindow()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val radius = height / 2f
            canvas.drawRoundRect(0f, 0f, width.toFloat(), height.toFloat(), radius, radius, trackPaint)
            val segmentWidth = width / 3f
            val left = (width + segmentWidth) * progressOffset - segmentWidth
            canvas.save()
            canvas.clipRect(0f, 0f, width.toFloat(), height.toFloat())
            canvas.drawRoundRect(
                left,
                0f,
                left + segmentWidth,
                height.toFloat(),
                radius,
                radius,
                progressPaint,
            )
            canvas.restore()
        }
    }

    private companion object {
        const val STARTUP_CHANNEL = "bingnondo/startup_splash"
        val launchBackground: Int = Color.rgb(92, 10, 20)
    }
}
