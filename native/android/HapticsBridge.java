package com.jellycube3d.bridge;

import android.app.Activity;
import android.content.Context;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;

public class HapticsBridge {
    private static Vibrator sVibrator;

    public static void init(Activity activity) {
        sVibrator = (Vibrator) activity.getSystemService(Context.VIBRATOR_SERVICE);
    }

    public static void impact(String style) {
        if (sVibrator == null || !sVibrator.hasVibrator()) return;
        long ms = "success".equals(style) ? 24 : "medium".equals(style) ? 14 : 7;
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                sVibrator.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE));
            } else {
                sVibrator.vibrate(ms);
            }
        } catch (RuntimeException ignored) {
        }
    }
}
