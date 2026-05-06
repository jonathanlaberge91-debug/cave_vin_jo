package com.example.cave_vin_jo

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class CellierWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.cellier_widget)

            // Time
            val time = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
            views.setTextViewText(R.id.widget_time, time)

            // CellR D
            updateCellier(context, views, widgetData, isCellD = true)

            // CellR G
            updateCellier(context, views, widgetData, isCellD = false)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun updateCellier(
        context: Context,
        views: RemoteViews,
        data: SharedPreferences,
        isCellD: Boolean
    ) {
        val prefix = if (isCellD) "celld" else "cellg"

        val name      = data.getString("${prefix}_name", if (isCellD) "CellR D" else "CellR G") ?: ""
        val topTemp   = data.getFloat("${prefix}_top_temp", Float.NaN)
        val topHum    = data.getFloat("${prefix}_top_hum", Float.NaN)
        val botTemp   = data.getFloat("${prefix}_bot_temp", Float.NaN)
        val botHum    = data.getFloat("${prefix}_bot_hum", Float.NaN)
        val doorOpen  = data.getBoolean("${prefix}_door_open", false)
        val sideLight = data.getInt("${prefix}_side_light", 0)
        val isBlue    = data.getBoolean("${prefix}_side_blue", false)
        val topLed    = data.getString("${prefix}_top_led", "OFF") ?: "OFF"

        fun fmt(v: Float) = if (v.isNaN()) "--" else "%.1f".format(v)
        fun fmtHum(v: Float) = if (v.isNaN()) "💧 --%"  else "💧 ${"%.0f".format(v)}%"

        val nameId    = if (isCellD) R.id.celld_name      else R.id.cellg_name
        val topTempId = if (isCellD) R.id.celld_top_temp  else R.id.cellg_top_temp
        val topHumId  = if (isCellD) R.id.celld_top_hum   else R.id.cellg_top_hum
        val botTempId = if (isCellD) R.id.celld_bot_temp  else R.id.cellg_bot_temp
        val botHumId  = if (isCellD) R.id.celld_bot_hum   else R.id.cellg_bot_hum
        val doorId    = if (isCellD) R.id.celld_door       else R.id.cellg_door
        val ledId     = if (isCellD) R.id.celld_top_led    else R.id.cellg_top_led
        val leftId    = if (isCellD) R.id.celld_side_left  else R.id.cellg_side_left
        val rightId   = if (isCellD) R.id.celld_side_right else R.id.cellg_side_right

        views.setTextViewText(nameId, name)
        views.setTextViewText(topTempId, "${fmt(topTemp)}°")
        views.setTextViewText(topHumId, fmtHum(topHum))
        views.setTextViewText(botTempId, "${fmt(botTemp)}°")
        views.setTextViewText(botHumId, fmtHum(botHum))

        // Door badge
        if (doorOpen) {
            views.setTextViewText(doorId, "🚪 Porte ouverte")
            views.setTextColor(doorId, 0xFFE8A04C.toInt())
            views.setInt(doorId, "setBackgroundResource", R.drawable.door_open_bg)
        } else {
            views.setTextViewText(doorId, "🚪 Porte fermée")
            views.setTextColor(doorId, 0xFF7CD492.toInt())
            views.setInt(doorId, "setBackgroundResource", R.drawable.door_closed_bg)
        }

        // Side bars
        val sideDrawable = sideDrawable(sideLight, isBlue)
        views.setInt(leftId,  "setBackgroundResource", sideDrawable)
        views.setInt(rightId, "setBackgroundResource", sideDrawable)

        // Top LED
        val ledDrawable = when (topLed) {
            "blue" -> R.drawable.top_led_blue
            "red"  -> R.drawable.top_led_red
            else   -> R.drawable.top_led_off
        }
        views.setInt(ledId, "setBackgroundResource", ledDrawable)
    }

    private fun sideDrawable(intensity: Int, isBlue: Boolean): Int {
        if (intensity == 0) return R.drawable.side_off
        return if (isBlue) {
            when {
                intensity <= 25  -> R.drawable.side_blue25
                intensity <= 50  -> R.drawable.side_blue50
                intensity <= 75  -> R.drawable.side_blue75
                else             -> R.drawable.side_blue100
            }
        } else {
            when {
                intensity <= 25  -> R.drawable.side_warm25
                intensity <= 50  -> R.drawable.side_warm50
                intensity <= 75  -> R.drawable.side_warm75
                else             -> R.drawable.side_warm100
            }
        }
    }
}
