# Keep LibVLC classes to prevent UnsatisfiedLinkError during JNI_OnLoad in release mode
-keep class org.videolan.libvlc.** { *; }
