-dontwarn com.samsung.**
-keep class com.samsung.** { *; }
# Optional graph-profiling/template protos are absent from the MediaPipe AAR.
# These APIs are unused by the LLM inference plugin.
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
