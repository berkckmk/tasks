package expo.modules.steadyreminders

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ImportantAlarmActivity : Activity() {
  private var reminderId: String = ""
  private var timeView: TextView? = null
  private val handler = Handler(Looper.getMainLooper())
  private var timeTickerRunnable: Runnable? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setupWindowFlags()

    reminderId = intent.getStringExtra(EXTRA_ID).orEmpty()
    val title = intent.getStringExtra(EXTRA_TITLE) ?: "Önemli Hatırlatıcı"
    val message = intent.getStringExtra(EXTRA_MESSAGE).orEmpty()

    setContentView(createView(title, message))
    setupSystemBarsAppearance()
    startTimeTicker()
  }

  override fun onNewIntent(intent: Intent?) {
    super.onNewIntent(intent)
    setIntent(intent)
    reminderId = intent?.getStringExtra(EXTRA_ID).orEmpty()
    val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Önemli Hatırlatıcı"
    val message = intent?.getStringExtra(EXTRA_MESSAGE).orEmpty()
    setContentView(createView(title, message))
    setupSystemBarsAppearance()
  }

  override fun onDestroy() {
    super.onDestroy()
    stopTimeTicker()
  }

  private fun setupWindowFlags() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
      setShowWhenLocked(true)
      setTurnScreenOn(true)
      val keyguardManager = getSystemService(KeyguardManager::class.java)
      keyguardManager?.requestDismissKeyguard(this, null)
    } else {
      @Suppress("DEPRECATION")
      window.addFlags(
        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
      )
    }
  }

  private fun setupSystemBarsAppearance() {
    try {
      // Set status bar & navigation bar to match the warm stone background
      window.statusBarColor = Color.parseColor("#FAF8F5")
      window.navigationBarColor = Color.parseColor("#EAE5DC")

      // Configure light system bars (dark icons on light background)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        window.insetsController?.setSystemBarsAppearance(
          WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
          WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
          WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
          WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
        )
      } else {
        @Suppress("DEPRECATION")
        var flags = window.decorView.systemUiVisibility
        flags = flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          flags = flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        }
        window.decorView.systemUiVisibility = flags
      }
    } catch (_: Throwable) {
      // Gracefully continue
    }
  }

  private fun createView(title: String, message: String): View {
    // Full screen root layout - warm stone subtle gradient
    val root = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      layoutParams = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.MATCH_PARENT
      )
      val bgGradient = GradientDrawable(
        GradientDrawable.Orientation.TOP_BOTTOM,
        intArrayOf(
          Color.parseColor("#FAF8F5"),
          Color.parseColor("#F3EFE9"),
          Color.parseColor("#EAE5DC")
        )
      )
      background = bgGradient
      val padH = dpToPx(24)
      val padTop = dpToPx(56)
      val padBottom = dpToPx(36)
      setPadding(padH, padTop, padH, padBottom)
    }

    // 1. TOP SECTION (Importance Badge & Subtitle)
    val topSection = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      gravity = Gravity.CENTER_HORIZONTAL
      layoutParams = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
      )
    }

    // Refined warm amber importance badge (centered pill)
    val badge = TextView(this).apply {
      text = "★  ÖNEMLİ HATIRLATICI"
      setTextColor(Color.parseColor("#8A5816")) // Warm bronze amber
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
      letterSpacing = 0.06f
      typeface = Typeface.DEFAULT_BOLD
      gravity = Gravity.CENTER
      val badgeBg = GradientDrawable().apply {
        setColor(Color.parseColor("#FDF6E2")) // Soft amber-tinted stone surface
        cornerRadius = dpToPx(14).toFloat() // radius.lg
        setStroke(dpToPx(1), Color.parseColor("#E5D0A1")) // Delicate warm border
      }
      background = badgeBg
      val hPad = dpToPx(16)
      val vPad = dpToPx(8)
      setPadding(hPad, vPad, hPad, vPad)
      layoutParams = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.WRAP_CONTENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
      )
    }
    topSection.addView(badge)

    // Context Kicker
    val kicker = TextView(this).apply {
      text = "STEADY PROGRESS"
      setTextColor(Color.parseColor("#969087")) // colors.caption
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f)
      letterSpacing = 0.12f
      typeface = Typeface.DEFAULT_BOLD
      gravity = Gravity.CENTER
      val lp = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.WRAP_CONTENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
      ).apply {
        topMargin = dpToPx(8)
      }
      layoutParams = lp
    }
    topSection.addView(kicker)
    root.addView(topSection)

    // 2. CENTER HERO SECTION (Expands naturally across the whole screen)
    val centerSection = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      gravity = Gravity.CENTER
      layoutParams = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        0,
        1f
      )
    }

    // Large Modern Clock
    val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
    val clockView = TextView(this).apply {
      text = timeFormat.format(Date())
      setTextColor(Color.parseColor("#292724")) // colors.text (deep warm charcoal)
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 74f)
      letterSpacing = -0.03f
      typeface = Typeface.DEFAULT_BOLD
      gravity = Gravity.CENTER
    }
    centerSection.addView(clockView)
    timeView = clockView

    // Formatted Date (Turkish localization matching the app's language)
    val dateLocale = try {
      Locale.forLanguageTag("tr-TR")
    } catch (_: Throwable) {
      Locale.getDefault()
    }
    val dateFormat = SimpleDateFormat("d MMMM yyyy, EEEE", dateLocale)
    val dateView = TextView(this).apply {
      text = dateFormat.format(Date())
      setTextColor(Color.parseColor("#6F6A63")) // colors.note
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 14.5f)
      typeface = Typeface.DEFAULT
      gravity = Gravity.CENTER
      val lp = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.WRAP_CONTENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
      ).apply {
        topMargin = dpToPx(4)
        bottomMargin = dpToPx(28)
      }
      layoutParams = lp
    }
    centerSection.addView(dateView)

    // Subtle Warm Divider
    val divider = View(this).apply {
      val divBg = GradientDrawable().apply {
        setColor(Color.parseColor("#D6D0C6")) // colors.divider
        cornerRadius = dpToPx(1).toFloat()
      }
      background = divBg
      val lp = LinearLayout.LayoutParams(
        dpToPx(40),
        dpToPx(2)
      ).apply {
        bottomMargin = dpToPx(28)
      }
      layoutParams = lp
    }
    centerSection.addView(divider)

    // Reminder Title (Centered, readable, part of natural screen flow)
    val titleView = TextView(this).apply {
      text = title
      setTextColor(Color.parseColor("#292724")) // colors.text
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
      typeface = Typeface.DEFAULT_BOLD
      gravity = Gravity.CENTER
      maxLines = 3
      ellipsize = TextUtils.TruncateAt.END
      setLineSpacing(0f, 1.15f)
      val lp = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
      ).apply {
        leftMargin = dpToPx(8)
        rightMargin = dpToPx(8)
      }
      layoutParams = lp
    }
    centerSection.addView(titleView)

    // Reminder Message / Note (if exists)
    if (message.isNotBlank()) {
      val messageView = TextView(this).apply {
        text = message
        setTextColor(Color.parseColor("#6F6A63")) // colors.muted
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
        typeface = Typeface.DEFAULT
        gravity = Gravity.CENTER
        maxLines = 4
        ellipsize = TextUtils.TruncateAt.END
        setLineSpacing(0f, 1.2f)
        val lp = LinearLayout.LayoutParams(
          LinearLayout.LayoutParams.MATCH_PARENT,
          LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
          topMargin = dpToPx(12)
          leftMargin = dpToPx(16)
          rightMargin = dpToPx(16)
        }
        layoutParams = lp
      }
      centerSection.addView(messageView)
    }

    root.addView(centerSection)

    // 3. BOTTOM ACTION SECTION
    val bottomSection = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      gravity = Gravity.CENTER_HORIZONTAL
      layoutParams = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
      )
    }

    // Complete Button (Primary Action - Warm dark charcoal matching floating navbar)
    val completeBtn = TextView(this).apply {
      text = "Tamamlandı"
      setTextColor(Color.parseColor("#FAF7F1")) // colors.surfaceElevated
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
      typeface = Typeface.DEFAULT_BOLD
      gravity = Gravity.CENTER
      isClickable = true
      isFocusable = true
      background = createRippleDrawable(
        normalColor = Color.parseColor("#2D2A26"), // colors.navBackground
        pressedColor = Color.parseColor("#443F3A"),
        radiusDp = 16 // radius.button
      )
      val lp = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        dpToPx(56)
      ).apply {
        bottomMargin = dpToPx(12)
      }
      layoutParams = lp
      setOnClickListener {
        handleComplete()
      }
    }
    bottomSection.addView(completeBtn)

    // Snooze Button (Secondary Action - Elevated warm stone surface with subtle border)
    val snoozeBtn = TextView(this).apply {
      text = "10 dk Ertele"
      setTextColor(Color.parseColor("#292724")) // colors.text
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
      typeface = Typeface.DEFAULT_BOLD
      gravity = Gravity.CENTER
      isClickable = true
      isFocusable = true
      background = createRippleDrawable(
        normalColor = Color.parseColor("#FAF7F1"), // colors.surfaceElevated
        pressedColor = Color.parseColor("#EAE5DC"),
        radiusDp = 16, // radius.button
        strokeColor = Color.parseColor("#C9C2B7"), // colors.border
        strokeWidthDp = 1
      )
      val lp = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        dpToPx(52)
      )
      layoutParams = lp
      setOnClickListener {
        handleSnooze()
      }
    }
    bottomSection.addView(snoozeBtn)

    // Subtle Info Note
    val infoNote = TextView(this).apply {
      text = "Alarm bir aksiyon seçilene kadar çalmaya devam eder"
      setTextColor(Color.parseColor("#969087")) // colors.caption
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f)
      typeface = Typeface.DEFAULT
      gravity = Gravity.CENTER
      val lp = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
      ).apply {
        topMargin = dpToPx(14)
      }
      layoutParams = lp
    }
    bottomSection.addView(infoNote)

    root.addView(bottomSection)

    return root
  }

  private fun createRippleDrawable(
    normalColor: Int,
    pressedColor: Int,
    radiusDp: Int,
    strokeColor: Int = 0,
    strokeWidthDp: Int = 0
  ): Drawable {
    val content = GradientDrawable().apply {
      setColor(normalColor)
      cornerRadius = dpToPx(radiusDp).toFloat()
      if (strokeWidthDp > 0) {
        setStroke(dpToPx(strokeWidthDp), strokeColor)
      }
    }
    val mask = GradientDrawable().apply {
      setColor(Color.WHITE)
      cornerRadius = dpToPx(radiusDp).toFloat()
    }
    return RippleDrawable(ColorStateList.valueOf(pressedColor), content, mask)
  }

  private fun startTimeTicker() {
    val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
    timeTickerRunnable = object : Runnable {
      override fun run() {
        timeView?.text = timeFormat.format(Date())
        handler.postDelayed(this, 1000)
      }
    }
    handler.post(timeTickerRunnable!!)
  }

  private fun stopTimeTicker() {
    timeTickerRunnable?.let { handler.removeCallbacks(it) }
    timeTickerRunnable = null
  }

  private fun handleSnooze() {
    val serviceIntent = Intent(this, ImportantAlarmService::class.java).apply {
      action = ImportantAlarmService.ACTION_SNOOZE
      putExtra(ImportantAlarmService.EXTRA_ID, reminderId)
    }
    startService(serviceIntent)
    finish()
  }

  private fun handleComplete() {
    val serviceIntent = Intent(this, ImportantAlarmService::class.java).apply {
      action = ImportantAlarmService.ACTION_COMPLETE
      putExtra(ImportantAlarmService.EXTRA_ID, reminderId)
    }
    startService(serviceIntent)
    finish()
  }

  private fun dpToPx(dp: Int): Int {
    return TypedValue.applyDimension(
      TypedValue.COMPLEX_UNIT_DIP,
      dp.toFloat(),
      resources.displayMetrics
    ).toInt()
  }

  companion object {
    const val EXTRA_ID = "extra_id"
    const val EXTRA_TITLE = "extra_title"
    const val EXTRA_MESSAGE = "extra_message"
  }
}
