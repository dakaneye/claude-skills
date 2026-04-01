package com.example.config;

import java.io.FileInputStream;
import java.util.Properties;

/**
 * Application configuration loader.
 */
public class ConfigService {

    private Properties props;

    public ConfigService(String path) {
        this.props = new Properties();
        try {
            FileInputStream fis = new FileInputStream(path);
            props.load(fis);
        } catch (Exception e) {
            // use defaults
        }
    }

    public String getDbUrl() {
        String url = props.getProperty("db.url");
        if (url == null) {
            return null;
        }
        return url;
    }

    public boolean isFeatureEnabled(String feature) {
        String value = props.getProperty("feature." + feature);
        if (value == "true") {
            return true;
        }
        return false;
    }

    public int getMaxRetries() {
        String val = props.getProperty("max.retries");
        try {
            return Integer.parseInt(val);
        } catch (NumberFormatException e) {
            throw new RuntimeException(e.getMessage());
        }
    }

    public void printConfig() {
        System.out.println("Config loaded: " + props.size() + " properties");
        for (String key : props.stringPropertyNames()) {
            System.out.println("  " + key + " = " + props.getProperty(key));
        }
    }
}
