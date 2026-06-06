---
name: flutter-spatial-nav
description: Code generation and structural guardrails for 60fps Flutter TV D-pad navigation.
---

# Skill: Flutter Spatial Navigation Architect

## 1. Focus Node Hard Constraints
* **Focus Wrapper:** Every directional, selectable item (Sidebar tabs, Channel list cards, Video Player controller buttons, categories) MUST be wrapped inside a `Focus`, `FocusScope`, or `FocusableActionDetector`.
* **Explicit Nodes:** Never generate an empty, orphaned `FocusNode()`. Nodes must be explicitly initialized within the widget state lifecycle (`initState`/`dispose`) or passed down from a parent controller to maintain clean focus tree cleanup and prevent memory leaks.
* **Auto-Focus Request:** Request initial focus programmatically after the layout finishes building using:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    FocusScope.of(context).requestFocus(_initialFocusNode);
  }
});
```

## 2. Virtualized EPG Grids & Cache Pre-fetching
* **ListView & GridView Builders:** Large grids or schedule guides containing thousands of channel entries must use lazy-loaded virtualized builders (`ListView.builder`, `GridView.builder`).
* **Memory Protection:** Streaming devices (Android TV boxes, Fire TV sticks) run under extremely tight memory constraints. You MUST explicitly declare `cacheExtent` on scrollable builders to guarantee smooth pre-loading off-screen assets without triggering out-of-memory overhead or crash closures:
```dart
GridView.builder(
  cacheExtent: 300.0,
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
  ),
  itemBuilder: (context, index) => _BentoItem(),
)
```

## 3. High-Fidelity Focus Animations
* **State Highlight:** Every selectable item must scale up and glow visually when focused.
* **Transform Performance:** Use highly optimized transformations (`Matrix4` scale) in combination with borders/shadows inside an `AnimatedContainer` or `ScaleTransition` to prevent layout re-calculation lag on TV processors:
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 150),
  transform: Matrix4.identity()..scale(isFocused ? 1.06 : 1.0),
  decoration: BoxDecoration(
    border: Border.all(
      color: isFocused ? Color(0xFFBE7DFB) : Colors.transparent, 
      width: 2.5,
    ),
    boxShadow: isFocused ? [
      BoxShadow(
        color: Color(0xFFBE7DFB).withOpacity(0.4),
        blurRadius: 16,
      )
    ] : [],
  ),
  child: child,
)
```

## 4. Television Overscan Safeguards
* **Edge Margin:** Ensure all root layout containers have a protective padding margin of at least `24.0` logical pixels to guarantee the UI is never cut off on older HDMI TVs that apply visual overscan.
```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
  child: bodyContent,
)
```
