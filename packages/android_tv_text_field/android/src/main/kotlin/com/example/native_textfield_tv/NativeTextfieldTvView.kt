package com.example.native_textfield_tv
import android.util.Log

import android.content.Context
import android.graphics.Color
import android.text.Editable
import android.text.TextWatcher
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * EditText that does **not** consume DPAD keys.
 *
 * Stock EditText handles DPAD for caret movement, which steals arrows from the
 * Android TV / Chromecast soft keyboard (Gboard) so only Back works.
 * Returning false lets the system IME navigate on-screen keys.
 */
private class TvImeEditText(context: Context) : EditText(context) {
    private fun isDpad(keyCode: Int): Boolean {
        return keyCode == KeyEvent.KEYCODE_DPAD_UP ||
            keyCode == KeyEvent.KEYCODE_DPAD_DOWN ||
            keyCode == KeyEvent.KEYCODE_DPAD_LEFT ||
            keyCode == KeyEvent.KEYCODE_DPAD_RIGHT ||
            keyCode == KeyEvent.KEYCODE_DPAD_CENTER
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (event != null && isDpad(keyCode)) return false
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (event != null && isDpad(keyCode)) return false
        return super.onKeyUp(keyCode, event)
    }
}

class NativeTextfieldTvView(
    private val context: Context,
    private val viewId: Int,
    private val creationParams: Map<String?, Any?>?,
    private val messenger: BinaryMessenger
) : PlatformView {

    private val editText: EditText
    private val methodChannel: MethodChannel

    init {
        editText = TvImeEditText(context).apply {
            // Initial text & hint
            val initialText = creationParams?.get("initialText") as? String
            if (initialText != null) setText(initialText)

            hint = creationParams?.get("hint") as? String ?: ""

            // Text size (sp)
            val textSizeValue = creationParams?.get("textSize")
            val textSizeSp = when (textSizeValue) {
                is Int -> textSizeValue.toFloat()
                is Double -> textSizeValue.toFloat()
                is Float -> textSizeValue
                else -> null
            }
            if (textSizeSp != null) textSize = textSizeSp

            // Initial colors
            val textColorValue = creationParams?.get("textColor")
            val textColor = when (textColorValue) {
                is Int -> textColorValue
                is Long -> textColorValue.toInt()
                else -> Color.WHITE
            }
            setTextColor(textColor)
            setHintTextColor(textColor)

            val bgColorValue = creationParams?.get("backgroundColor")
            val bgColor = when (bgColorValue) {
                is Int -> bgColorValue
                is Long -> bgColorValue.toInt()
                else -> Color.BLACK
            }
            setBackgroundColor(bgColor)

            // Input type
            inputType = android.text.InputType.TYPE_CLASS_TEXT
            val obscureText = creationParams?.get("obscureText") as? Boolean ?: false
            if (obscureText) {
                inputType = android.text.InputType.TYPE_CLASS_TEXT or
                        android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD
            }

            // Max lines
            val maxLines = creationParams?.get("maxLines") as? Int ?: 1
            setLines(maxLines)

            // TV remotes: keep EditText focusable so system IME (Gboard)
            // receives D-pad for on-screen key navigation.
            isFocusable = true
            isFocusableInTouchMode = true
            isCursorVisible = true

            imeOptions = EditorInfo.IME_ACTION_DONE
            // Prefer the fullscreen/extract-friendly TV IME when available.
            setRawInputType(inputType)

            // onSubmitted callback
            setOnEditorActionListener { _: TextView, actionId: Int, _: KeyEvent? ->
                if (actionId == EditorInfo.IME_ACTION_DONE ||
                    actionId == EditorInfo.IME_ACTION_GO ||
                    actionId == EditorInfo.IME_ACTION_NEXT
                ) {
                    val instanceId = creationParams?.get("instanceId") as? Int
                    methodChannel.invokeMethod("onSubmitted", mapOf(
                        "instanceId" to instanceId,
                        "text" to this.text.toString()
                    ))
                    true
                } else {
                    false
                }
            }
        }

        methodChannel = MethodChannel(messenger, "native_textfield_tv")

        // TextWatcher
        editText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                val instanceId = creationParams?.get("instanceId") as? Int
                methodChannel.invokeMethod("onTextChanged", mapOf(
                    "instanceId" to instanceId,
                    "text" to s.toString()
                ))
            }
        })

        // Focus listener
        editText.setOnFocusChangeListener { _, hasFocus ->
            val instanceId = creationParams?.get("instanceId") as? Int
            methodChannel.invokeMethod("onFocusChanged", mapOf(
                "instanceId" to instanceId,
                "hasFocus" to hasFocus
            ))
        }
    }

    override fun getView(): View = editText

    override fun dispose() {}

    // Flutter calls
    fun setText(text: String) { editText.setText(text) }
    fun getText(): String = editText.text.toString()

    /**
     * Give Android focus to the native EditText and show the system IME.
     * Required on Chromecast/Google TV so D-pad navigates Gboard keys
     * (Flutter TextField InputConnectionAdaptor swallows arrows).
     */
    fun requestFocus() {
        editText.post {
            editText.isFocusable = true
            editText.isFocusableInTouchMode = true
            editText.requestFocus()
            val imm =
                context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            // SHOW_FORCED helps Chromecast/Google TV keep Gboard up for DPAD nav.
            imm?.showSoftInput(editText, InputMethodManager.SHOW_FORCED)
        }
    }

    fun clearFocus() {
        editText.post {
            val imm =
                context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.hideSoftInputFromWindow(editText.windowToken, 0)
            editText.clearFocus()
        }
    }

    fun setEnabled(enabled: Boolean) { editText.isEnabled = enabled }
    fun setHint(hint: String?) { editText.hint = hint }

    fun setTextColorFlutter(color: Int) { editText.setTextColor(color) }
    fun setBackgroundColorFlutter(color: Int) { editText.setBackgroundColor(color) }

 fun setObscureText(obscure: Boolean) {
    Log.d("NativeTextfieldTvView", "Updating obscureText=$obscure")
    editText.post {
        val cursorPos = editText.selectionStart

        editText.transformationMethod = if (obscure) 
            android.text.method.PasswordTransformationMethod.getInstance()
        else 
            null

        val inputTypeClass = android.text.InputType.TYPE_CLASS_TEXT
        val variation = if (obscure) android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD else 0
        editText.inputType = inputTypeClass or variation

        editText.setSelection(cursorPos)
        Log.d("NativeTextfieldTvView", "ObscureText update applied, cursorPos=$cursorPos")
    }
}



    fun moveCursor(direction: String) {
        val pos = editText.selectionStart
        when (direction) {
            "left" -> if (pos > 0) editText.setSelection(pos - 1)
            "right" -> if (pos < editText.text.length) editText.setSelection(pos + 1)
        }
    }
}
