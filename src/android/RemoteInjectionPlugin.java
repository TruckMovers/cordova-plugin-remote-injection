package com.truckmovers.cordova;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.res.AssetManager;
import android.util.Base64;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebViewEngine;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.MalformedURLException;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

public class RemoteInjectionPlugin extends CordovaPlugin {
    private static Pattern REMOTE_URL_REGEX = Pattern.compile("^http(s)?://.*");

    // List of files to inject before injecting Cordova.
    private final ArrayList<String> preInjectionFileNames = new ArrayList<String>();

    protected void pluginInitialize() {
        String pref = webView.getPreferences().getString("CRIInjectFirstFiles", "");
        for (String path: pref.split(",")) {
            preInjectionFileNames.add(path.trim());
        }
    }

    @Override
    public Object onMessage(String id, Object data) {
        if (id.equals("onReceivedError")) {
            if (isRemote(data)) {
                showRetryDialog();
            }
        } else if (id.equals("onPageFinished")) {
            if (isRemote(data)) {
                injectCordova();
            }
        }

        return null;
    }

    /**
     * @param url
     * @return true if the URL over HTTP or HTTPS
     */
    private boolean isRemote(Object url) {
        if (url instanceof String) {
            return REMOTE_URL_REGEX.matcher((String) url).matches();
        }
        return false;
    }

    private void showRetryDialog() {
        final Activity activity = super.cordova.getActivity();
        final CordovaWebViewEngine engine = super.webView.getEngine();

        cordova.getActivity().runOnUiThread(new Runnable() {
            public void run() {
                AlertDialog.Builder builder = new AlertDialog.Builder(activity);
                builder.setMessage("There was an issue contacting the server.")
                        .setPositiveButton("Try again?", new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int id) {
                                // Obviously only works for GETs but good enough.
                                engine.loadUrl(engine.getUrl(), false);
                            }
                        })
                        .setNegativeButton("Exit", new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int id) {
                                // Exit the app.
                                activity.finish();
                            }
                        });
                // Show the alert.
                builder.create().show();
            }
        });
    }

    private void injectCordova() {
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
        String jsUrl = "javascript:var script = document.createElement('script');";
        jsUrl += "script.src=\"data:text/javascript;base64,";

        jsUrl += Base64.encodeToString(jsToInject.toString().getBytes(), Base64.DEFAULT);
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
