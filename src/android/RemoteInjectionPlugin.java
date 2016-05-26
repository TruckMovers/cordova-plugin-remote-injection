package com.truckmovers.cordova;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.res.AssetManager;
import android.util.Base64;
import android.webkit.ValueCallback;

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
import java.net.MalformedURLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Timer;
import java.util.TimerTask;
import java.util.regex.Pattern;

import org.xwalk.core.XWalkView;
import org.xwalk.core.JavascriptInterface;

public class RemoteInjectionPlugin extends CordovaPlugin {
    public static final String TAG = "RemoteInjectionPlugin";

    // Javascipt to inject before injecting Cordova.
    private String cachedCordovaData;

    protected void pluginInitialize() {
        ArrayList<String> preInjectionFileNames = new ArrayList<String>();
        String pref = webView.getPreferences().getString("CRIInjectFirstFiles", "");
        for (String path: pref.split(",")) {
            preInjectionFileNames.add(path.trim());
        }
        this.cachedCordovaData = injectCordova(preInjectionFileNames);
    }

    @Override
    public Object onMessage(String id, Object data) {
        if (id.equals("onPageStarted")) {
            // add some cordova apis to the webview
            ((XWalkView) webView.getView()).evaluateJavascript(cachedCordovaData, new ValueCallback<String>() {
                @Override
                public void onReceiveValue(String value) {
                    LOG.i(TAG, "Value from injecting cordova: " + value);
                }
            });
        }
        return null;
    }

    private String injectCordova(ArrayList<String> preInjectionFileNames) {
        List<String> jsPaths = new ArrayList<String>();
        for (String path: preInjectionFileNames) {
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
        for (String path: jsPaths) {
            jsToInject.append(readFile(cordova.getActivity().getResources().getAssets(), path));
        }
        return jsToInject.toString();
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
     * @param path start path
     * @return found JS files
     */
    private List<String> jsPathsToInject(AssetManager assets, String path){
        List jsPaths = new ArrayList<String>();

        try {
            for (String filePath: assets.list(path)) {
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
}
