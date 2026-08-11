import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_textfield_tv_platform_interface.dart';

/// NativeTextfieldTv plugin
class NativeTextfieldTv {
  Future<String?> getPlatformVersion() {
    return NativeTextfieldTvPlatform.instance.getPlatformVersion();
  }
}

/// Controller for NativeTextField
class NativeTextFieldController extends TextEditingController {
  ValueChanged<bool>? onFocusChanged;
  bool _isUpdatingFromNative = false;

  NativeTextFieldController({String? text}) {
    if (text != null) {
      super.text = text;
    }
  }

  void _setTextFromNative(String text) {
    _isUpdatingFromNative = true;
    if (this.text != text) this.text = text;
    _isUpdatingFromNative = false;
  }

  bool get isUpdatingFromNative => _isUpdatingFromNative;

  Future<void> setText(String text) async {
    this.text = text;
  }
}

/// NativeTextField Widget
class NativeTextField extends StatefulWidget {
  final NativeTextFieldController? controller;
  final String? hint;
  final String? initialText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onFocusChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final double? width;
  final double? height;
  final bool obscureText;
  final int? maxLines;
  final Color backgroundColor;
  final Color textColor;
  final double? textSize;

  /// When false, losing Flutter [focusNode] focus does **not** clear the native
  /// EditText / hide IME. Needed so we can release Flutter key ownership while
  /// Gboard keeps Android focus for DPAD key navigation.
  final bool clearNativeOnUnfocus;

  const NativeTextField({
    super.key,
    this.controller,
    this.hint,
    this.initialText,
    this.focusNode,
    this.onChanged,
    this.onFocusChanged,
    this.onSubmitted,
    this.enabled = true,
    this.width,
    this.height,
    this.obscureText = false,
    this.maxLines = 1,
    this.backgroundColor = Colors.black,
    this.textColor = Colors.white,
    this.textSize,
    this.clearNativeOnUnfocus = true,
  });

  @override
  State<NativeTextField> createState() => _NativeTextFieldState();
}

class _NativeTextFieldState extends State<NativeTextField> {
  late NativeTextFieldController _controller;
  bool _isControllerCreated = false;
  late int _instanceId;
  static int _nextInstanceId = 0;
  static const MethodChannel _channel = MethodChannel('native_textfield_tv');
  static final Map<int, _NativeTextFieldState> _instances = {};

  @override
  void initState() {
    super.initState();
    _instanceId = _nextInstanceId++;
    _instances[_instanceId] = this;

    _controller = widget.controller ?? NativeTextFieldController();
    _isControllerCreated = widget.controller == null;

    // Listen to controller changes
    _controller.addListener(_onControllerTextChanged);
    if (widget.onChanged != null) {
      _controller.addListener(() {
        if (!_controller.isUpdatingFromNative)
          widget.onChanged!(_controller.text);
      });
    }
    _controller.onFocusChanged = widget.onFocusChanged;

    // Bridge Flutter FocusNode → native focus so that calling
    // focusNode.requestFocus() from outside (e.g. appbar search) actually
    // opens the keyboard on the native Android EditText.
    widget.focusNode?.addListener(_onFocusNodeChange);

    _initializeChannel();
  }

  void _onFocusNodeChange() {
    if (widget.focusNode!.hasFocus) {
      requestFocus();
    } else if (widget.clearNativeOnUnfocus) {
      clearFocus();
    }
  }

  void _onControllerTextChanged() {
    if (!_controller.isUpdatingFromNative) _syncToNative();
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    final instanceId = call.arguments['instanceId'] as int?;
    final instance = _instances[instanceId];
    if (instance == null) return;

    switch (call.method) {
      case 'onTextChanged':
        final text = call.arguments['text'] as String? ?? '';
        instance._controller._setTextFromNative(text);
        // Fire onChanged for native-side text (typing on keyboard).
        // The controller listener skips native updates to avoid sync loops,
        // so we call it directly here.
        instance.widget.onChanged?.call(text);
        break;
      case 'onFocusChanged':
        final hasFocus = call.arguments['hasFocus'] as bool? ?? false;
        instance._controller.onFocusChanged?.call(hasFocus);
        break;
      case 'onSubmitted':
        final text = call.arguments['text'] as String? ?? '';
        instance.widget.onSubmitted?.call(text);
        break;
    }
  }

  static void _initializeChannel() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  void _syncToNative() {
    _channel.invokeMethod(
        'setText', {'instanceId': _instanceId, 'text': _controller.text});
  }

  Future<void> requestFocus() async {
    await _channel.invokeMethod('requestFocus', {'instanceId': _instanceId});
  }

  Future<void> clearFocus() async {
    await _channel.invokeMethod('clearFocus', {'instanceId': _instanceId});
  }

  Future<void> moveCursorLeft() async {
    await _channel.invokeMethod(
        'moveCursor', {'instanceId': _instanceId, 'direction': 'left'});
  }

  Future<void> moveCursorRight() async {
    await _channel.invokeMethod(
        'moveCursor', {'instanceId': _instanceId, 'direction': 'right'});
  }

  Future<void> setObscureText(bool obscure) async {
    // Update internal state
    setState(() {
      // We don't actually store obscureText here, just forward to native
    });

    // Call native method
    await _channel.invokeMethod('setObscureText', {
      'instanceId': _instanceId,
      'obscureText': obscure,
    });
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusNodeChange);
    // Best-effort hide IME when the PlatformView goes away (e.g. dialog close).
    try {
      _channel.invokeMethod('clearFocus', {'instanceId': _instanceId});
    } catch (_) {}
    _instances.remove(_instanceId);
    if (_instances.isEmpty) _channel.setMethodCallHandler(null);
    _controller.removeListener(_onControllerTextChanged);
    if (_isControllerCreated) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = {
      'instanceId': _instanceId,
      'hint': widget.hint,
      'initialText': widget.initialText,
      'obscureText': widget.obscureText,
      'maxLines': widget.maxLines,
      'backgroundColor': widget.backgroundColor.value,
      'textColor': widget.textColor.value,
      if (widget.textSize != null) 'textSize': widget.textSize,
    };

    Widget child = AndroidView(
      viewType: 'native_textfield_tv',
      onPlatformViewCreated: _onPlatformViewCreated,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );

    if (widget.width != null || widget.height != null) {
      return SizedBox(width: widget.width, height: widget.height, child: child);
    }
    return child;
  }

  void _onPlatformViewCreated(int id) {
    if (_controller.text.isNotEmpty && _controller.text != widget.initialText)
      _syncToNative();
    // If the Flutter FocusNode already has focus when the native view becomes
    // ready, forward the focus request now. This fixes the case where
    // requestFocus() was called before the AndroidView finished initializing.
    if (widget.focusNode != null && widget.focusNode!.hasFocus) {
      requestFocus();
    }
  }
}

/// DPAD constants
const String keyUp = 'Arrow Up';
const String keyDown = 'Arrow Down';
const String keyLeft = 'Arrow Left';
const String keyRight = 'Arrow Right';
const String keyCenter = 'Select';
const String goBack = 'Go Back';

/// DPAD NativeTextField with eye toggle
class AndroidTVTextField extends StatefulWidget {
  final FocusNode focusNode;
  final NativeTextFieldController controller;
  final double height;
  final bool obscureText;
  final String? hint;
  final int? maxLines;
  final Color backgroundColor;
  final Color textColor;
  final Color focuesedBorderColor;
  final Color unFocuesedBorderColor;
  final double? textSize;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  final bool showPasswordToggle;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? postFixWidget;

  /// When true (login edit dialogs on Chromecast/Google TV):
  /// - Do not remap Left/Right to caret moves (that steals Gboard DPAD).
  /// - Losing Flutter [focusNode] does not dismiss the native IME, so we can
  ///   release Flutter key ownership after native EditText is focused.
  final bool deferDpadToIme;

  const AndroidTVTextField(
      {super.key,
      required this.focusNode,
      required this.controller,
      this.height = 60,
      this.obscureText = false,
      this.hint,
      this.maxLines = 1,
      this.showPasswordToggle = false,
      this.backgroundColor = Colors.black,
      this.textColor = Colors.white,
      this.onChanged,
      this.onSubmitted,
      this.focuesedBorderColor = Colors.transparent,
      this.unFocuesedBorderColor = Colors.transparent,
      this.textSize,
      this.borderRadius,
      this.padding,
      this.postFixWidget,
      this.deferDpadToIme = false});

  @override
  State<AndroidTVTextField> createState() => _DpadNativeTextFieldState();
}

class _DpadNativeTextFieldState extends State<AndroidTVTextField> {
  final GlobalKey<_NativeTextFieldState> _nativeTextFieldKey =
      GlobalKey<_NativeTextFieldState>();

  @override
  void initState() {
    super.initState();

    widget.focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        if (widget.focusNode.hasFocus) {
          _nativeTextFieldKey.currentState?.requestFocus();
        } else if (!widget.deferDpadToIme) {
          _nativeTextFieldKey.currentState?.clearFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  bool _isDpad(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  @override
  Widget build(BuildContext context) {
    final field = Stack(
      alignment: Alignment.centerRight,
      children: [
        Builder(builder: (context) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
                color: widget.backgroundColor,
                border: Border.all(
                  color: widget.focusNode.hasFocus || widget.deferDpadToIme
                      ? widget.focuesedBorderColor
                      : widget.unFocuesedBorderColor,
                  width: 1,
                ),
              ),
              padding: widget.padding ??
                  EdgeInsets.only(
                      left: 5,
                      right: widget.postFixWidget == null ? 5 : 50,
                      top: 5,
                      bottom: 5),
              child: NativeTextField(
                key: _nativeTextFieldKey,
                // Bridge FocusNode so late PlatformView creation still
                // forwards focus → native EditText (IME gets D-pad).
                focusNode: widget.focusNode,
                controller: widget.controller,
                width: double.infinity,
                height: widget.height,
                obscureText: widget.obscureText,
                hint: widget.hint,
                maxLines: widget.maxLines,
                backgroundColor: widget.backgroundColor,
                textColor: widget.textColor,
                textSize: widget.textSize,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                clearNativeOnUnfocus: !widget.deferDpadToIme,
              ),
            ),
          );
        }),
        Positioned(right: 10, child: widget.postFixWidget ?? SizedBox()),
      ],
    );

    // IME owns DPAD: never install KeyboardListener caret remaps, and never
    // mark directional keys as handled so FlutterView can fall through to the
    // native EditText / Gboard.
    if (widget.deferDpadToIme) {
      return Focus(
        focusNode: widget.focusNode,
        onKeyEvent: (node, event) {
          if (_isDpad(event.logicalKey)) {
            return KeyEventResult.ignored;
          }
          return KeyEventResult.ignored;
        },
        child: field,
      );
    }

    return KeyboardListener(
      focusNode: widget.focusNode,
      onKeyEvent: (event) {
        if (event is KeyUpEvent) {
          switch (event.logicalKey.keyLabel) {
            case keyLeft:
              _nativeTextFieldKey.currentState?.moveCursorLeft();
              break;
            case keyRight:
              _nativeTextFieldKey.currentState?.moveCursorRight();
              break;
          }
        }
      },
      child: field,
    );
  }
}
