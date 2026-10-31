package cz.martinpohl.overload;

import android.os.Handler;
import android.os.Looper;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

import androidx.core.util.Consumer;
import androidx.window.java.layout.WindowInfoTrackerCallbackAdapter;
import androidx.window.layout.DisplayFeature;
import androidx.window.layout.FoldingFeature;
import androidx.window.layout.WindowInfoTracker;
import androidx.window.layout.WindowLayoutInfo;

import com.getcapacitor.BridgeActivity;

import org.json.JSONObject;

import java.util.concurrent.Executor;

/**
 * Pushes Jetpack WindowManager fold state into the page as window.__overloadFold.
 * Flex Mode (Flip, half-folded, horizontal hinge) and book posture (Fold, vertical
 * hinge) are the only postures that reserve a hinge gap. A fully open Fold stays
 * "flat" and uses the window size class instead.
 */
public final class FoldBridge {
    private final BridgeActivity activity;
    private final Handler main = new Handler(Looper.getMainLooper());
    private WindowInfoTrackerCallbackAdapter adapter;
    private Consumer<WindowLayoutInfo> consumer;
    private String latest = "{\"posture\":\"flat\",\"multiWindow\":false}";
    private boolean interfaceAdded;

    public FoldBridge(BridgeActivity activity) {
        this.activity = activity;
    }

    public void start() {
        if (adapter == null) {
            adapter = new WindowInfoTrackerCallbackAdapter(WindowInfoTracker.getOrCreate(activity));
            consumer = this::onLayout;
        }
        Executor executor = main::post;
        adapter.addWindowLayoutInfoListener(activity, executor, consumer);
        attachInterface();
        publish(null);
    }

    public void stop() {
        if (adapter != null && consumer != null) {
            adapter.removeWindowLayoutInfoListener(consumer);
        }
    }

    public void publish() {
        publish(null);
    }

    private void onLayout(WindowLayoutInfo info) {
        publish(info);
    }

    private void attachInterface() {
        WebView webView = webView();
        if (webView == null || interfaceAdded) return;
        webView.addJavascriptInterface(new Js(), "OverloadFold");
        interfaceAdded = true;
    }

    private void publish(WindowLayoutInfo info) {
        latest = toJson(info);
        WebView webView = webView();
        if (webView == null) return;
        String script = "window.__overloadFold&&window.__overloadFold(" + latest + ")";
        webView.post(() -> webView.evaluateJavascript(script, null));
    }

    private WebView webView() {
        if (activity.getBridge() == null) return null;
        return activity.getBridge().getWebView();
    }

    private String toJson(WindowLayoutInfo info) {
        try {
            String posture = "flat";
            JSONObject hinge = null;
            FoldingFeature feature = featureIn(info);
            if (feature != null && feature.getState() == FoldingFeature.State.HALF_OPENED) {
                float density = activity.getResources().getDisplayMetrics().density;
                if (density <= 0f) density = 1f;
                hinge = new JSONObject();
                if (feature.getOrientation() == FoldingFeature.Orientation.HORIZONTAL) {
                    posture = "flex";
                    hinge.put("orientation", "horizontal");
                    hinge.put("top", feature.getBounds().top / density);
                    hinge.put("left", 0);
                    hinge.put("size", feature.getBounds().height() / density);
                } else {
                    posture = "book";
                    hinge.put("orientation", "vertical");
                    hinge.put("top", 0);
                    hinge.put("left", feature.getBounds().left / density);
                    hinge.put("size", feature.getBounds().width() / density);
                }
            }
            JSONObject payload = new JSONObject();
            payload.put("posture", posture);
            payload.put("multiWindow", activity.isInMultiWindowMode());
            if (hinge != null) payload.put("hinge", hinge);
            return payload.toString();
        } catch (Exception ignored) {
            return "{\"posture\":\"flat\",\"multiWindow\":false}";
        }
    }

    private static FoldingFeature featureIn(WindowLayoutInfo info) {
        if (info == null) return null;
        for (DisplayFeature feature : info.getDisplayFeatures()) {
            if (feature instanceof FoldingFeature) return (FoldingFeature) feature;
        }
        return null;
    }

    private final class Js {
        @JavascriptInterface
        public String layout() {
            return latest;
        }
    }
}
