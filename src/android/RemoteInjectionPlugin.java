package com.truckmovers.cordova;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.res.AssetManager;
import android.util.Base64;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebViewEngine;
import org.apache.cordova.LOG;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.ref.WeakReference;
import java.net.MalformedURLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Timer;
import java.util.TimerTask;
import java.util.regex.Pattern;

public class RemoteInjectionPlugin extends CordovaPlugin {
    private static String TAG = "RemoteInjectionPlugin";
    private static Pattern REMOTE_URL_REGEX = Pattern.compile("^http(s)?://.*");


    // List of files to inject before injecting Cordova.
    private final ArrayList<String> preInjectionFileNames = new ArrayList<String>();

    private RequestLifecycle lifecycle;

    protected void pluginInitialize() {
        String pref = webView.getPreferences().getString("CRIInjectFirstFiles", "");
        for (String path : pref.split(",")) {
            preInjectionFileNames.add(path.trim());
        }
        // Delay before prompting user to retry in seconds
        int promptInterval = webView.getPreferences().getInteger("CRIPageLoadPromptInterval", 10);

        final Activity activity = super.cordova.getActivity();
        final CordovaWebViewEngine engine = super.webView.getEngine();
        lifecycle = new RequestLifecycle(activity, engine, promptInterval);
    }

    private void onMessageTypeFailure(String messageId, Object data) {
        LOG.e(TAG, messageId + " received a data instance that is not an expected type:" + data.getClass().getName());
    }

    @Override
    public void onReset() {
        super.onReset();

        lifecycle.requestStopped();
    }

    @Override
    public Object onMessage(String id, Object data) {
        if (id.equals("onReceivedError")) {
            // Data is a JSONObject instance with the following keys:
            // * errorCode
            // * description
            // * url

            if (data instanceof JSONObject) {
                JSONObject json = (JSONObject) data;

                try {
                    if (isRemote(json.getString("url"))) {
                        lifecycle.requestStopped();
                    }
                } catch (JSONException e) {
                    LOG.e(TAG, "Unexpected JSON in onReceiveError", e);
                }
            } else {
                onMessageTypeFailure(id, data);
            }
        } else if (id.equals("onPageFinished")) {
            if (data instanceof String) {
                String url = (String) data;
                if (isRemote(url)) {
                    injectCordova();
                    lifecycle.requestStopped();
                }
            } else {
                onMessageTypeFailure(id, data);
            }
        } else if (id.equals("onPageStarted")) {
            if (data instanceof String) {
                String url = (String) data;

                if (isRemote(url)) {
                    lifecycle.requestStarted(url);
                }
            } else {
                onMessageTypeFailure(id, data);
            }
        }

        return null;
    }

    /**
     * @param url
     * @return true if the URL over HTTP or HTTPS
     */
    private boolean isRemote(String url) {
        return REMOTE_URL_REGEX.matcher((String) url).matches();
    }

    private void injectCordova() {
        List<String> jsPaths = new ArrayList<String>();
        for (String path : preInjectionFileNames) {
            jsPaths.add(path);
        }

        jsPaths.add("www/cordova.js");

        // We load the plugin code manually rather than allow cordova to load them (via
        // cordova_plugins.js).  The reason for this is the WebView will attempt to load the
        // file in the origin of the page (e.g. https://truckmover.com/plugins/plugin/plugin.js).
        // By loading them first cordova will skip its loading process altogether.
        jsPaths.addAll(jsPathsToInject(cordova.getActivity().getResources().getAssets(), "www/plugins"));

        // Initialize the cordova plugin registry.
        jsPaths.add("www/cordova_plugins.js");

        // The way that I figured out to inject for android is to inject it as a script
        // tag with the full JS encoded as a data URI
        // (https://developer.mozilla.org/en-US/docs/Web/HTTP/data_URIs).  The script tag
        // is appended to the DOM and executed via a javascript URL (e.g. javascript:doJsStuff()).
        StringBuilder jsToInject = new StringBuilder();
        for (String path : jsPaths) {
            jsToInject.append(readFile(cordova.getActivity().getResources().getAssets(), path));
        }
        String jsUrl = "javascript:var script = document.createElement('script');";
        jsUrl += "script.src=\"data:text/javascript;charset=utf-8;base64,";

        jsUrl += Base64.encodeToString(jsToInject.toString().getBytes(), Base64.NO_WRAP);
        jsUrl += "\";";

        jsUrl += "document.getElementsByTagName('head')[0].appendChild(script);";

        webView.getEngine().loadUrl(jsUrl, false);
    }

    private String readFile(AssetManager assets, String filePath) {
        StringBuilder out = new StringBuilder();
        BufferedReader in = null;
        try {
            InputStream stream = assets.open(filePath);
            in = new BufferedReader(new InputStreamReader(stream));
            String str = "";

            while ((str = in.readLine()) != null) {
                out.append(str);
                out.append("\n");
            }
        } catch (MalformedURLException e) {
        } catch (IOException e) {
        } finally {
            if (in != null) {
                try {
                    in.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
        return out.toString();
    }

    /**
     * Searches the provided path for javascript files recursively.
     *
     * @param assets
     * @param path   start path
     * @return found JS files
     */
    private List<String> jsPathsToInject(AssetManager assets, String path) {
        List jsPaths = new ArrayList<String>();

        try {
            for (String filePath : assets.list(path)) {
                String fullPath = path + File.separator + filePath;

                if (fullPath.endsWith(".js")) {
                    jsPaths.add(fullPath);
                } else {
                    List<String> childPaths = jsPathsToInject(assets, fullPath);
                    if (!childPaths.isEmpty()) {
                        jsPaths.addAll(childPaths);
                    }
                }
            }
        } catch (IOException e) {
            e.printStackTrace();
        }

        return jsPaths;
    }

    private static class RequestLifecycle {
        private final WeakReference<Activity> activityRef;
        private final CordovaWebViewEngine engine;
        private UserPromptTask task;
        private final int promptInterval;

        RequestLifecycle(Activity activity, CordovaWebViewEngine engine, int promptInterval) {
            this.activityRef = new WeakReference<>(activity);
            this.engine = engine;
            this.promptInterval = promptInterval;
        }

        boolean isLoading() {
            return task != null;
        }

        void requestStopped() {
            stopTask();
        }

        void requestStarted(final String url) {
            startTask(url);
        }

        private synchronized void stopTask() {
            if (task != null) {
                task.cancel();
                task = null;
            }
        }

        private synchronized void startTask(final String url) {
            if (task != null) {
                task.cancel();
            }

            if (promptInterval > 0 && activityRef.get() != null && !activityRef.get().isFinishing()) {
                task = new UserPromptTask(this, activityRef.get(), engine, url);
                new Timer().schedule(task, promptInterval * 1000);
            }
        }
    }

    /**
     * Prompt the user asking if they want to wait on the current request or retry.
     */
    static class UserPromptTask extends TimerTask {
        private final RequestLifecycle lifecycle;
        private final WeakReference<Activity> activityRef;
        private final CordovaWebViewEngine engine;
        final String url;

        AlertDialog alertDialog;

        UserPromptTask(RequestLifecycle lifecycle, Activity activity, CordovaWebViewEngine engine, String url) {
            this.lifecycle = lifecycle;
            this.activityRef = new WeakReference<>(activity);
            this.engine = engine;
            this.url = url;
        }

        @Override
        public boolean cancel() {
            boolean result = super.cancel();
            cleanup();

            return result;
        }

        private void cleanup() {
            if (alertDialog != null) {
                alertDialog.dismiss();
                alertDialog = null;
            }
        }

        @Override
        public void run() {
            if (lifecycle.isLoading() && activityRef.get() != null && !activityRef.get().isFinishing()) {
                // Prompts the user giving them the choice to wait on the current request or retry.
                activityRef.get().runOnUiThread(() -> {
                    AlertDialog.Builder builder = new AlertDialog.Builder(activityRef.get());
                    builder.setMessage("The server is taking longer than expected to respond.")
                            .setPositiveButton("Retry", (dialog, id) -> {
                                // Obviously only works for GETs but good enough.
                                engine.loadUrl(engine.getUrl(), false);
                            })
                            .setNegativeButton("Wait", (dialog, id) -> lifecycle.startTask(url));
                    alertDialog = builder.create();
                    alertDialog.show();
                });
            } else {
                lifecycle.stopTask();
            }
        }
    }
}
