package com.osalhaddad.samaa;

import android.content.res.Configuration;
import android.os.Bundle;
import android.view.View;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import androidx.activity.OnBackPressedCallback;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // both hands are on the oud, so the screen stays on
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        // keep the app clear of the status bar, the camera cut-out and the navigation bar
        View root = findViewById(android.R.id.content);
        paintBars(isNight());
        ViewCompat.setOnApplyWindowInsetsListener(root, (v, insets) -> {
            Insets safe = insets.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout() | WindowInsetsCompat.Type.ime());
            v.setPadding(safe.left, safe.top, safe.right, safe.bottom);
            return WindowInsetsCompat.CONSUMED;
        });

        // text keeps its designed size whatever the phone's font setting, so layouts hold
        WebView web = getBridge().getWebView();
        web.getSettings().setTextZoom(100);
        web.addJavascriptInterface(new Object() {
            @JavascriptInterface public boolean isNight() { return MainActivity.this.isNight(); }
            @JavascriptInterface public void setDark(boolean dark) { runOnUiThread(() -> paintBars(dark)); }
        }, "SamaaNative");

        // the back button closes dialogs and lessons first; the page says whether it handled it
        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                getBridge().getWebView().evaluateJavascript("window.samaaBack ? String(window.samaaBack()) : 'false'", result -> {
                    if (!"\"true\"".equals(result)) finish();
                });
            }
        });
    }

    private boolean isNight() {
        return (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
    }

    /* the strips behind the status and navigation bars match the page */
    private void paintBars(boolean dark) {
        findViewById(android.R.id.content).setBackgroundColor(dark ? 0xFF0F2321 : 0xFFFBF6EE);
        WindowInsetsControllerCompat bars = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        bars.setAppearanceLightStatusBars(!dark);
        bars.setAppearanceLightNavigationBars(!dark);
    }
}
