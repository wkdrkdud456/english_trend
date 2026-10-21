package kr.jangvis.callrelay;

import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.Charset;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Collections;
import java.util.Date;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 입력·출처·식별자 규칙. Android API에 의존하지 않으므로 JVM 단위 검사로 확인한다.
 */
public final class Policy {
    private Policy() {}

    public static final int MAX_BYTES = 2 * 1024 * 1024;
    public static final int MAX_CHARS = 200_000;
    /** 항목 ID 길이(16진수). SHA-256 앞 96비트. */
    public static final int ID_HEX = 24;

    public static final String MARKER_PREFIX = "[장비스 통화 #";
    private static final Pattern MARKER = Pattern.compile("\\[장비스 통화 #([0-9a-f]{" + ID_HEX + "})\\]");

    // ---------------------------------------------------------------- 출처

    /** 완료 알림을 처리하는 삼성 앱(실기기 진단 전 후보). */
    public static final Set<String> SAMSUNG_PACKAGES = Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
            "com.samsung.android.dialer",
            "com.samsung.android.app.telephonyui",
            "com.sec.android.app.voicenote")));

    /**
     * 시스템 공유 화면 후보. One UI 8.5에서 실제 어느 패키지가 공유 화면을 띄우는지는 미검증이다.
     * 자동화는 이 목록과 삼성 앱 안에서만 노드를 누른다.
     */
    public static final Set<String> SHARE_SHEET_PACKAGES = Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
            "android",
            "com.android.intentresolver",
            "com.samsung.android.intentresolver")));

    public static boolean isSamsungSource(String pkg) {
        return pkg != null && SAMSUNG_PACKAGES.contains(pkg);
    }

    public static boolean isShareSheet(String pkg) {
        return pkg != null && SHARE_SHEET_PACKAGES.contains(pkg);
    }

    // ---------------------------------------------------------------- 형식

    /** 공유 MIME 검사. text/* 만 받는다. 녹음·이미지·영상·기타 바이너리는 거부. */
    public static boolean isTextMime(String mime) {
        if (mime == null) return false;
        String m = mime.trim().toLowerCase(Locale.ROOT);
        int semi = m.indexOf(';');
        if (semi >= 0) m = m.substring(0, semi).trim();
        return m.startsWith("text/") && m.length() > 5;
    }

    private static final Set<String> NON_TEXT_EXT = new HashSet<>(Arrays.asList(
            "m4a", "amr", "3gp", "mp3", "aac", "wav", "ogg", "opus", "flac", "mp4", "mkv", "webm",
            "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "pdf", "zip", "apk"));

    /** 파일명이 녹음·이미지 등 텍스트가 아닌 형식으로 보이면 true. */
    public static boolean looksNonText(String displayName) {
        if (displayName == null) return false;
        int dot = displayName.lastIndexOf('.');
        if (dot < 0 || dot == displayName.length() - 1) return false;
        return NON_TEXT_EXT.contains(displayName.substring(dot + 1).toLowerCase(Locale.ROOT));
    }

    /** 디코딩 결과. text 또는 error 중 하나만 채워진다. */
    public static final class Decoded {
        public final String text;
        public final String error;

        private Decoded(String text, String error) {
            this.text = text;
            this.error = error;
        }

        static Decoded ok(String t) { return new Decoded(t, null); }
        static Decoded fail(String e) { return new Decoded(null, e); }
        public static Decoded failure(String e) { return fail(e); }
        public boolean ok() { return text != null; }
    }

    /**
     * 파일 바이트를 문자열로 바꾼다. UTF-8(BOM 유무), UTF-16LE/BE(BOM 필수)를 지원한다.
     * 잘못된 바이트 순서는 대체 문자로 바꾸지 않고 오류로 돌려준다.
     */
    public static Decoded decode(byte[] data, int length) {
        if (length > MAX_BYTES) return Decoded.fail("파일이 2 MiB를 넘습니다.");
        if (length == 0) return Decoded.fail("빈 파일입니다.");
        int off = 0;
        Charset cs = StandardCharsets.UTF_8;
        if (length >= 4 && ((data[0] == (byte) 0xFF && data[1] == (byte) 0xFE && data[2] == 0 && data[3] == 0)
                || (data[0] == 0 && data[1] == 0 && data[2] == (byte) 0xFE && data[3] == (byte) 0xFF))) {
            return Decoded.fail("UTF-32 인코딩은 지원하지 않습니다.");
        }
        if (length >= 3 && data[0] == (byte) 0xEF && data[1] == (byte) 0xBB && data[2] == (byte) 0xBF) {
            off = 3;
        } else if (length >= 2 && data[0] == (byte) 0xFF && data[1] == (byte) 0xFE) {
            off = 2;
            cs = StandardCharsets.UTF_16LE;
        } else if (length >= 2 && data[0] == (byte) 0xFE && data[1] == (byte) 0xFF) {
            off = 2;
            cs = StandardCharsets.UTF_16BE;
        }
        CharsetDecoder dec = cs.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT);
        String s;
        try {
            s = dec.decode(ByteBuffer.wrap(data, off, length - off)).toString();
        } catch (CharacterCodingException e) {
            return Decoded.fail("텍스트 인코딩을 읽을 수 없습니다. UTF-8 또는 BOM이 있는 UTF-16만 지원합니다.");
        }
        return checkText(s);
    }

    /** EXTRA_TEXT 또는 디코딩된 본문 검사·정규화. */
    public static Decoded checkText(CharSequence raw) {
        if (raw == null) return Decoded.fail("공유된 텍스트가 없습니다.");
        String s = raw.toString();
        if (s.indexOf('\u0000') >= 0) return Decoded.fail("텍스트 파일이 아닙니다(바이너리 데이터 포함).");
        s = s.replace("\r\n", "\n").replace('\r', '\n');
        if (!s.isEmpty() && s.charAt(0) == '\uFEFF') s = s.substring(1);
        s = stripTrailing(s);
        // 앞쪽 빈 줄만 제거(들여쓰기는 보존)
        int start = 0;
        while (start < s.length() && s.charAt(start) == '\n') start++;
        s = s.substring(start);
        if (s.trim().isEmpty()) return Decoded.fail("빈 텍스트입니다.");
        if (s.codePointCount(0, s.length()) > MAX_CHARS) {
            return Decoded.fail("본문이 200,000자를 넘습니다.");
        }
        if (s.getBytes(StandardCharsets.UTF_8).length > MAX_BYTES) {
            return Decoded.fail("본문이 2 MiB를 넘습니다.");
        }
        return Decoded.ok(s);
    }

    private static String stripTrailing(String s) {
        int end = s.length();
        while (end > 0 && Character.isWhitespace(s.charAt(end - 1))) end--;
        return s.substring(0, end);
    }

    // ---------------------------------------------------------------- 식별자

    /**
     * 통화 식별 키 정규화. 파일명(확장자·복사본 번호 제외)이 가장 안정적이다.
     * 빈 문자열이면 본문만으로 식별한다(이 경우 서로 다른 통화의 같은 본문은 같은 항목이 된다).
     */
    public static String normalizeCallKey(String raw) {
        if (raw == null) return "";
        String k = raw.trim();
        int slash = Math.max(k.lastIndexOf('/'), k.lastIndexOf('\\'));
        if (slash >= 0) k = k.substring(slash + 1);
        if (k.toLowerCase(Locale.ROOT).endsWith(".txt")) k = k.substring(0, k.length() - 4);
        k = k.replaceAll("\\s*[(\\[]\\d{1,3}[)\\]]$", "");
        k = k.replaceAll("\\s+", " ").trim();
        return k.toLowerCase(Locale.ROOT);
    }

    /** 통화 키와 본문으로 만든 항목 ID(SHA-256 앞 24자리, 소문자 16진수). */
    public static String itemId(String callKey, String text) {
        String key = normalizeCallKey(callKey);
        String input = "jangvis-call-v1\n" + key.length() + ":" + key + "\n" + text;
        return sha256Hex(input).substring(0, ID_HEX);
    }

    public static String sha256Hex(String s) {
        try {
            byte[] d = MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(d.length * 2);
            for (byte b : d) sb.append(String.format(Locale.ROOT, "%02x", b & 0xFF));
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    public static String marker(String id) {
        return MARKER_PREFIX + id + "]";
    }

    /** Dynalist 노트: 원본 녹취 + 빈 줄 + 고유 식별자(맨 끝). */
    public static String note(String text, String id) {
        return text + "\n\n" + marker(id);
    }

    /** 본문에서 찾은 첫 번째 식별자 ID, 없으면 null. */
    public static String findMarkerId(String s) {
        if (s == null || s.indexOf(MARKER_PREFIX) < 0) return null;
        Matcher m = MARKER.matcher(s);
        return m.find() ? m.group(1) : null;
    }

    public static boolean isItemId(String s) {
        return s != null && s.matches("[0-9a-f]{" + ID_HEX + "}");
    }

    /** Dynalist 항목 제목: '통화 · 파일명' 또는 '통화 · 통화 시각'. */
    public static String title(String displayName, long createdMillis) {
        String n = displayName == null ? "" : displayName.trim();
        int slash = n.lastIndexOf('/');
        if (slash >= 0) n = n.substring(slash + 1);
        if (n.toLowerCase(Locale.ROOT).endsWith(".txt")) n = n.substring(0, n.length() - 4);
        n = n.replaceAll("[\\r\\n\\t]+", " ").trim();
        if (n.length() > 120) n = n.substring(0, 120);
        if (n.isEmpty()) {
            SimpleDateFormat f = new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.KOREA);
            n = f.format(new Date(createdMillis));
        }
        return "통화 · " + n;
    }

    // ---------------------------------------------------------------- Dynalist 문서 ID

    private static final Pattern DOC_ID = Pattern.compile("[A-Za-z0-9_-]{8,64}");
    private static final Pattern DOC_URL = Pattern.compile(
            "^https://(?:www\\.)?dynalist\\.io/d/([A-Za-z0-9_-]{8,64})(?:[/?#].*)?$");

    /**
     * 문서 URL 또는 ID에서 문서(file) ID만 꺼낸다. URL의 #z=… 는 노드 ID이므로 버린다.
     * 형식이 맞지 않으면 null.
     */
    public static String parseDocId(String input) {
        if (input == null) return null;
        String s = input.trim();
        if (s.isEmpty()) return null;
        Matcher m = DOC_URL.matcher(s);
        if (m.matches()) return m.group(1);
        if (s.contains("/") || s.contains(":") || s.contains("#")) return null;
        return DOC_ID.matcher(s).matches() ? s : null;
    }

    // ---------------------------------------------------------------- 재시도

    /** 지수 백오프: 30초부터 두 배, 최대 30분. */
    public static long backoffMillis(int attempt) {
        int a = Math.max(0, Math.min(attempt, 10));
        long ms = 30_000L << a;
        return Math.min(ms, 30 * 60_000L);
    }

    /** 응답 손실 후 같은 항목을 다시 확인하기 전 최소 대기. */
    public static final long UNCERTAIN_VERIFY_DELAY_MS = 2 * 60_000L;
    /** 불확실 상태가 이 횟수를 넘으면 자동 처리를 멈추고 사용자 확인을 요구. */
    public static final int MAX_UNCERTAIN = 5;

    // ---------------------------------------------------------------- 알림 분류

    public enum NotificationKind { TRANSCRIPT_DONE, RECORDING_DONE, IN_PROGRESS, FAILED, OTHER }

    private static final Pattern FAILED = Pattern.compile(
            "실패|오류|에러|할 수 없|하지 못|못했|중단|취소|되지\\s*않|않았|fail|error|unable|couldn.?t|can.?t"
                    + "|not\\s+(complete|completed|ready|available)|incomplete",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern IN_PROGRESS = Pattern.compile(
            "(변환|처리|진행|분석|저장|녹음|기록)\\s*(하는\\s*)?중|대기\\s*중|converting|transcribing|processing|in progress|\\.\\.\\.|…",
            Pattern.CASE_INSENSITIVE);
    /** '~할 수 있습니다/하시겠어요' 같은 제안 문구는 완료가 아니다. */
    private static final Pattern OFFER = Pattern.compile(
            "할\\s*수\\s*있|하시겠|하려면|눌러\\s*(서)?\\s*변환|탭하여|tap to|would you",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern TRANSCRIPT_DONE = Pattern.compile(
            "(텍스트|글자|전사|스크립트|녹취)\\s*(로\\s*)?(변환|기록|작성)?\\s*(이|가|을|를)?\\s*(완료|완성|준비\\s*(됨|되었|됐|완료))"
                    + "|(텍스트|글자|전사|스크립트|녹취)\\s*(로\\s*)?(변환|기록|작성)\\s*(됨|되었|됐|했)"
                    + "|transcri(pt|ption)\\s*(is\\s*)?(ready|complete|completed|done|available)",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern RECORDING_DONE = Pattern.compile(
            "녹음\\s*(이|을|를)?\\s*(완료|저장\\s*(됨|되었|됐|완료)|종료)|recording\\s*(saved|complete|completed)",
            Pattern.CASE_INSENSITIVE);

    /**
     * 알림 제목·본문으로 종류를 판정한다. 알림은 완료 신호로만 쓴다(본문 녹취를 기대하지 않음).
     * 실패·진행 중·제안 문구가 섞이면 시작하지 않는다.
     */
    public static NotificationKind classify(String title, String text, boolean ongoing, boolean hasProgress) {
        String s = ((title == null ? "" : title) + " \n " + (text == null ? "" : text));
        if (s.trim().isEmpty()) return NotificationKind.OTHER;
        if (FAILED.matcher(s).find()) return NotificationKind.FAILED;
        if (ongoing || hasProgress || IN_PROGRESS.matcher(s).find()) return NotificationKind.IN_PROGRESS;
        if (OFFER.matcher(s).find()) return NotificationKind.OTHER;
        if (TRANSCRIPT_DONE.matcher(s).find()) return NotificationKind.TRANSCRIPT_DONE;
        if (RECORDING_DONE.matcher(s).find()) return NotificationKind.RECORDING_DONE;
        return NotificationKind.OTHER;
    }

    /** 진단용 골격 문구에 남기는 상태 단어. 그 외 단어(이름·번호·녹취 내용)는 길이만 남긴다. */
    private static final Set<String> STATUS_WORDS = new HashSet<>(Arrays.asList(
            "통화", "녹음", "녹음이", "녹음을", "통화녹음", "텍스트", "텍스트로", "텍스트가", "글자", "글자로", "전사",
            "변환", "변환이", "변환을", "변환됨", "변환되었습니다", "변환했습니다", "변환하는", "변환중", "중", "완료",
            "완료됨", "완료되었습니다", "완료했습니다", "저장", "저장됨", "저장되었습니다", "실패", "실패했습니다", "오류",
            "기록", "요약", "스크립트", "녹취", "음성", "준비됨", "보기", "열기", "진행", "처리",
            "call", "recording", "recorded", "transcript", "transcription", "text", "converting", "converted",
            "complete", "completed", "done", "saved", "ready", "failed", "error", "summary", "view", "open"));

    /**
     * 진단 로그용 골격. 상태 단어만 남기고 나머지는 '▢n'(글자 수)으로 가린다.
     * 통화 상대·전화번호·녹취 문장은 로그에 남지 않는다.
     */
    public static String skeleton(String s) {
        if (s == null) return "";
        String[] parts = s.trim().split("\\s+");
        StringBuilder sb = new StringBuilder();
        int n = 0;
        for (String p : parts) {
            if (p.isEmpty()) continue;
            if (n++ >= 16) {
                sb.append(" …");
                break;
            }
            String core = p.replaceAll("[\\p{Punct}·…]+$", "").replaceAll("^[\\p{Punct}·…]+", "");
            if (sb.length() > 0) sb.append(' ');
            if (STATUS_WORDS.contains(core.toLowerCase(Locale.ROOT))) {
                sb.append(core);
            } else {
                sb.append('▢').append(core.codePointCount(0, core.length()));
            }
        }
        return sb.toString();
    }

    // ---------------------------------------------------------------- 화면 라벨

    /** One UI 8.5에서 미검증. 실제 라벨은 '화면 진단' 기록으로 확인한다. */
    public static final String[] MORE_LABELS = {"더보기", "옵션 더보기", "추가 옵션", "More options", "More"};
    public static final String[] SHARE_LABELS = {"공유", "공유하기", "Share"};
    public static final String[] TEXT_FILE_LABELS = {"텍스트 파일", "텍스트 파일로 공유", "텍스트 파일 공유", "Text file"};
    public static final String[] TARGET_LABELS = {"장비스 통화 연결"};
    /**
     * 공유가 선택창(ResolverActivity)으로 열려 '한 번만/항상'을 묻는 경우의 '한 번만'.
     * '항상'은 기본 앱 설정을 바꾸므로 절대 누르지 않는다.
     */
    public static final String[] JUST_ONCE_LABELS = {"한 번만", "이번만", "Just once"};

    /** 공백·대소문자만 무시하고 정확히 같은 라벨인지 비교한다(부분 일치 없음). */
    public static boolean labelMatches(CharSequence label, String[] candidates) {
        if (label == null) return false;
        String l = normLabel(label.toString());
        if (l.isEmpty()) return false;
        for (String c : candidates) {
            if (normLabel(c).equals(l)) return true;
        }
        return false;
    }

    static String normLabel(String s) {
        return s.replaceAll("[\\s\\u00A0]+", " ").trim().toLowerCase(Locale.ROOT);
    }

    /** 자동화 상한. */
    public static final long AUTOMATION_TIMEOUT_MS = 45_000L;
    public static final int AUTOMATION_MAX_ACTIONS = 10;
    public static final long STEP_TIMEOUT_MS = 8_000L;
}
