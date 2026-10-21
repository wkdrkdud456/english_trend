package kr.jangvis.callrelay;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import org.json.JSONArray;
import org.json.JSONException;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** 설정·상태 저장. 토큰은 Android Keystore AES/GCM 키로 암호화해서만 저장한다. */
public final class State {
    private State() {}

    private static final String PREFS = "callrelay";
    private static final String DIAG_PREFS = "callrelay_diag";
    private static final String KEY_ALIAS = "callrelay_token_key";
    private static final String K_TOKEN = "token_enc";
    private static final String K_DOC = "doc_id";
    private static final String K_DOC_TITLE = "doc_title";
    private static final String K_AUTO = "auto_enabled";
    private static final String K_DIAG = "diag_enabled";
    private static final String K_STATUS = "last_status";
    private static final String K_AUTO_STATUS = "automation_status";
    private static final String K_RATE_UNTIL = "rate_block_until";
    private static final String K_SEEN = "seen_signatures";
    private static final int DIAG_MAX = 80;

    static SharedPreferences prefs(Context c) {
        return c.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    // ---------------------------------------------------------------- 토큰

    public static boolean hasToken(Context c) {
        if (tokenForTest != null) return true;
        return prefs(c).getString(K_TOKEN, null) != null;
    }

    public static void saveToken(Context c, String token) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, key());
        byte[] iv = cipher.getIV();
        byte[] ct = cipher.doFinal(token.getBytes(StandardCharsets.UTF_8));
        byte[] all = new byte[1 + iv.length + ct.length];
        all[0] = (byte) iv.length;
        System.arraycopy(iv, 0, all, 1, iv.length);
        System.arraycopy(ct, 0, all, 1 + iv.length, ct.length);
        prefs(c).edit().putString(K_TOKEN, Base64.encodeToString(all, Base64.NO_WRAP)).apply();
    }

    /** 단위 검사 전용(Robolectric에는 AndroidKeyStore가 없음). 앱 코드는 설정하지 않는다. */
    static volatile String tokenForTest;

    /** 복호화된 토큰. 없거나 키가 사라졌으면(초기화 등) null. */
    public static String token(Context c) {
        if (tokenForTest != null) return tokenForTest;
        String enc = prefs(c).getString(K_TOKEN, null);
        if (enc == null) return null;
        try {
            byte[] all = Base64.decode(enc, Base64.NO_WRAP);
            int ivLen = all[0] & 0xFF;
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, all, 1, ivLen));
            byte[] pt = cipher.doFinal(all, 1 + ivLen, all.length - 1 - ivLen);
            return new String(pt, StandardCharsets.UTF_8);
        } catch (Exception e) {
            return null;
        }
    }

    public static void clearToken(Context c) {
        prefs(c).edit().remove(K_TOKEN).apply();
    }

    private static SecretKey key() throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
        ks.load(null);
        KeyStore.Entry e = ks.getEntry(KEY_ALIAS, null);
        if (e instanceof KeyStore.SecretKeyEntry) return ((KeyStore.SecretKeyEntry) e).getSecretKey();
        KeyGenerator kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        kg.init(new KeyGenParameterSpec.Builder(KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .build());
        return kg.generateKey();
    }

    // ---------------------------------------------------------------- 설정

    public static String docId(Context c) {
        return prefs(c).getString(K_DOC, null);
    }

    public static String docTitle(Context c) {
        return prefs(c).getString(K_DOC_TITLE, null);
    }

    public static void setDoc(Context c, String id, String title) {
        prefs(c).edit().putString(K_DOC, id).putString(K_DOC_TITLE, title).apply();
    }

    public static boolean autoEnabled(Context c) {
        return prefs(c).getBoolean(K_AUTO, false);
    }

    public static void setAutoEnabled(Context c, boolean on) {
        prefs(c).edit().putBoolean(K_AUTO, on).apply();
    }

    /** 사람이 공유한 통화를 바로 보내지 않고 '통화 목록'에 보관할지(기본: 보관). */
    public static boolean holdShares(Context c) {
        return prefs(c).getBoolean("hold_shares", true);
    }

    public static void setHoldShares(Context c, boolean on) {
        prefs(c).edit().putBoolean("hold_shares", on).apply();
    }

    /** '통화 목록'에서 연결한 녹취 폴더(SAF 트리 URI), 없으면 null. */
    public static String folderUri(Context c) {
        return prefs(c).getString("folder_uri", null);
    }

    public static void setFolderUri(Context c, String uri) {
        prefs(c).edit().putString("folder_uri", uri).apply();
    }

    public static boolean diagEnabled(Context c) {
        return prefs(c).getBoolean(K_DIAG, false);
    }

    public static void setDiagEnabled(Context c, boolean on) {
        prefs(c).edit().putBoolean(K_DIAG, on).apply();
    }

    // ---------------------------------------------------------------- 상태 문구

    public static void setStatus(Context c, String s) {
        prefs(c).edit().putString(K_STATUS, stamp() + " " + s).apply();
    }

    public static String status(Context c) {
        return prefs(c).getString(K_STATUS, "");
    }

    public static void setAutomationStatus(Context c, String s) {
        prefs(c).edit().putString(K_AUTO_STATUS, stamp() + " " + s).apply();
    }

    public static String automationStatus(Context c) {
        return prefs(c).getString(K_AUTO_STATUS, "");
    }

    public static long rateBlockedUntil(Context c) {
        return prefs(c).getLong(K_RATE_UNTIL, 0);
    }

    public static void setRateBlockedUntil(Context c, long t) {
        prefs(c).edit().putLong(K_RATE_UNTIL, t).apply();
    }

    // ---------------------------------------------------------------- 알림 중복 방지

    /** 처음 보는 알림 서명이면 기록하고 true. 3일 지난 서명은 정리한다. */
    public static synchronized boolean markSignatureNew(Context c, String sig, long now) {
        SharedPreferences p = prefs(c);
        List<String> keep = new ArrayList<>();
        boolean seen = false;
        try {
            JSONArray arr = new JSONArray(p.getString(K_SEEN, "[]"));
            for (int i = 0; i < arr.length(); i++) {
                String e = arr.getString(i);
                int bar = e.indexOf('|');
                long t = Long.parseLong(e.substring(0, bar));
                if (now - t > 3 * 24 * 3600_000L) continue;
                if (e.substring(bar + 1).equals(sig)) seen = true;
                keep.add(e);
            }
        } catch (JSONException | RuntimeException ignored) {
            keep.clear();
        }
        if (seen) return false;
        keep.add(now + "|" + sig);
        while (keep.size() > 300) keep.remove(0);
        p.edit().putString(K_SEEN, new JSONArray(keep).toString()).apply();
        return true;
    }

    // ---------------------------------------------------------------- 진단 로그

    /** 진단 로그. 녹취 본문·토큰은 절대 넣지 않는다(호출자가 골격 문구만 전달). */
    public static synchronized void diag(Context c, String line) {
        SharedPreferences p = c.getApplicationContext().getSharedPreferences(DIAG_PREFS, Context.MODE_PRIVATE);
        List<String> lines = new ArrayList<>();
        try {
            JSONArray arr = new JSONArray(p.getString("lines", "[]"));
            for (int i = 0; i < arr.length(); i++) lines.add(arr.getString(i));
        } catch (JSONException ignored) {
            // 손상되면 새로 시작
        }
        lines.add(stamp() + " " + line);
        while (lines.size() > DIAG_MAX) lines.remove(0);
        p.edit().putString("lines", new JSONArray(lines).toString()).apply();
    }

    public static synchronized String diagText(Context c) {
        SharedPreferences p = c.getApplicationContext().getSharedPreferences(DIAG_PREFS, Context.MODE_PRIVATE);
        StringBuilder sb = new StringBuilder();
        try {
            JSONArray arr = new JSONArray(p.getString("lines", "[]"));
            for (int i = arr.length() - 1; i >= 0; i--) sb.append(arr.getString(i)).append('\n');
        } catch (JSONException ignored) {
            // 빈 로그
        }
        return sb.toString();
    }

    public static synchronized void clearDiag(Context c) {
        c.getApplicationContext().getSharedPreferences(DIAG_PREFS, Context.MODE_PRIVATE).edit().clear().apply();
    }

    static String stamp() {
        return new SimpleDateFormat("MM-dd HH:mm:ss", Locale.KOREA).format(new Date());
    }
}
