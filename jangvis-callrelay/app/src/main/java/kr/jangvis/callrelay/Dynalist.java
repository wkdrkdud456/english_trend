package kr.jangvis.callrelay;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;


/**
 * Dynalist HTTPS API (https://apidocs.dynalist.io/).
 * HTTP 상태만 믿지 않고 응답 JSON의 _code를 본다. 토큰은 요청 본문에만 넣고 로그에 남기지 않는다.
 */
public final class Dynalist {
    private Dynalist() {}

    static final String BASE = "https://dynalist.io/api/v1/";
    /** 단위 검사에서만 가짜 서버로 바꾼다. */
    static volatile String baseUrl = BASE;
    private static final int CONNECT_TIMEOUT_MS = 15_000;
    private static final int READ_TIMEOUT_MS = 30_000;
    private static final int MAX_RESPONSE_BYTES = 64 * 1024 * 1024;

    /** 응답 분류. */
    public enum Kind {
        OK,
        /** 요청 제한(_code TooManyRequests 또는 HTTP 429) – 백오프 후 재시도 */
        RATE_LIMITED,
        /** 토큰 오류 – 사용자 조치 필요 */
        AUTH,
        /** 문서·노드 없음 또는 권한 없음 – 사용자 조치 필요 */
        NOT_FOUND,
        /** 잘못된 요청 – 같은 요청은 계속 실패 */
        INVALID,
        /** 일시적 서버 문제(LockFail 등) – 재시도. 요청은 반영되지 않음 */
        TEMPORARY,
        /** 요청이 닿기 전 네트워크 실패 – 재시도해도 중복 위험 없음 */
        NOT_SENT,
        /** 요청을 보낸 뒤 응답 손실·5xx – 서버 반영 여부 불명 */
        UNKNOWN
    }

    public static final class Response {
        public final Kind kind;
        public final String code;
        public final String message;
        public final JSONObject json;

        Response(Kind kind, String code, String message, JSONObject json) {
            this.kind = kind;
            this.code = code;
            this.message = message;
            this.json = json;
        }

        public String describe() {
            String c = code == null ? kind.name() : code;
            return message == null || message.isEmpty() ? c : c + ": " + message;
        }
    }

    /** _code 값을 분류한다. 공식 문서의 코드 + 알려지지 않은 코드는 INVALID로. */
    public static Kind classifyCode(String code) {
        if (code == null) return Kind.INVALID;
        // 공식 응답은 "Ok". 표기 차이("OK")로 성공을 실패로 오인하지 않도록 대소문자만 무시한다.
        if (code.equalsIgnoreCase("ok")) return Kind.OK;
        switch (code) {
            case "Ok":
                return Kind.OK;
            case "TooManyRequests":
                return Kind.RATE_LIMITED;
            case "InvalidToken":
            case "Unauthorized":
                return Kind.AUTH;
            case "NotFound":
            case "NodeNotFound":
                return Kind.NOT_FOUND;
            case "LockFail":
                return Kind.TEMPORARY;
            default:
                return Kind.INVALID; // Invalid, NoInbox 등
        }
    }

    /** HTTP 응답 해석(순수 함수, 단위 검사용). */
    public static Response interpret(int http, String body) {
        JSONObject json = null;
        if (body != null && !body.isEmpty()) {
            try {
                json = new JSONObject(body);
            } catch (JSONException ignored) {
                json = null;
            }
        }
        if (json != null && json.has("_code")) {
            String code = json.optString("_code", null);
            String msg = json.optString("_msg", "");
            return new Response(classifyCode(code), code, msg, json);
        }
        if (http == 429) return new Response(Kind.RATE_LIMITED, null, "HTTP 429", null);
        if (http == 401 || http == 403) return new Response(Kind.AUTH, null, "HTTP " + http, null);
        if (http >= 500) return new Response(Kind.UNKNOWN, null, "HTTP " + http + " (서버 반영 여부 불명)", null);
        return new Response(Kind.INVALID, null, "HTTP " + http + " 응답 형식 오류", null);
    }

    /**
     * POST 요청. 요청 본문을 쓰기 전에 실패하면 NOT_SENT, 본문을 쓴 뒤 실패하면 UNKNOWN.
     */
    static Response post(String endpoint, JSONObject body) {
        byte[] payload = body.toString().getBytes(StandardCharsets.UTF_8);
        HttpURLConnection conn = null;
        boolean bodyStarted = false;
        try {
            conn = (HttpURLConnection) new URL(baseUrl + endpoint).openConnection();
            conn.setRequestMethod("POST");
            conn.setConnectTimeout(CONNECT_TIMEOUT_MS);
            conn.setReadTimeout(READ_TIMEOUT_MS);
            conn.setDoOutput(true);
            conn.setUseCaches(false);
            conn.setInstanceFollowRedirects(false);
            // 고정 길이 스트리밍: 본문을 재전송할 수 없으므로 HTTP 계층의 자동 POST 재시도가 일어나지 않는다.
            conn.setFixedLengthStreamingMode(payload.length);
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            conn.setRequestProperty("Accept", "application/json");
            conn.connect();
            bodyStarted = true;
            try (OutputStream os = conn.getOutputStream()) {
                os.write(payload);
            }
            int http = conn.getResponseCode();
            InputStream in = http >= 400 ? conn.getErrorStream() : conn.getInputStream();
            String text = in == null ? "" : readAll(in);
            return interpret(http, text);
        } catch (IOException e) {
            String what = e.getClass().getSimpleName();
            if (!bodyStarted) return new Response(Kind.NOT_SENT, null, "네트워크 연결 실패 (" + what + ")", null);
            return new Response(Kind.UNKNOWN, null, "응답 손실 (" + what + ") – 서버 반영 여부 불명", null);
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    private static String readAll(InputStream in) throws IOException {
        try (InputStream is = in) {
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            byte[] buf = new byte[16 * 1024];
            int n;
            while ((n = is.read(buf)) > 0) {
                bos.write(buf, 0, n);
                if (bos.size() > MAX_RESPONSE_BYTES) throw new IOException("응답이 너무 큼");
            }
            return new String(bos.toByteArray(), StandardCharsets.UTF_8);
        }
    }

    // ---------------------------------------------------------------- 문서 조회

    /** doc/read 결과 요약. */
    public static final class Doc {
        public String title;
        public String rootId;
        public int nodeCount;
        /** 문서 안에서 찾은 [장비스 통화 #id] → 노드 ID */
        public final Map<String, String> markers = new HashMap<>();
    }

    public static Response readDoc(String token, String fileId) {
        JSONObject b = new JSONObject();
        try {
            b.put("token", token);
            b.put("file_id", fileId);
        } catch (JSONException e) {
            throw new IllegalStateException(e);
        }
        return post("doc/read", b);
    }

    /**
     * doc/read JSON을 해석한다. 루트 노드는 다른 노드의 children에 나오지 않는 노드이며,
     * 여러 개면 id가 "root"인 노드를 고른다. 문서 ID와 노드 ID는 별개다.
     */
    public static Doc parseDoc(JSONObject json) throws JSONException {
        Doc d = new Doc();
        d.title = json.optString("title", "");
        JSONArray nodes = json.getJSONArray("nodes");
        d.nodeCount = nodes.length();
        Set<String> children = new HashSet<>();
        for (int i = 0; i < nodes.length(); i++) {
            JSONObject n = nodes.getJSONObject(i);
            JSONArray ch = n.optJSONArray("children");
            if (ch != null) for (int j = 0; j < ch.length(); j++) children.add(ch.getString(j));
        }
        String root = null;
        int roots = 0;
        for (int i = 0; i < nodes.length(); i++) {
            JSONObject n = nodes.getJSONObject(i);
            String id = n.getString("id");
            if (!children.contains(id)) {
                roots++;
                if (root == null || "root".equals(id)) root = id;
            }
            for (String field : new String[]{"note", "content"}) {
                String marker = Policy.findMarkerId(n.optString(field, ""));
                if (marker != null && !d.markers.containsKey(marker)) d.markers.put(marker, id);
            }
        }
        if (root == null || (roots > 1 && !"root".equals(root))) {
            throw new JSONException("루트 노드를 확정할 수 없음");
        }
        d.rootId = root;
        return d;
    }

    // ---------------------------------------------------------------- 항목 추가

    public static JSONObject insertBody(String token, String fileId, String parentId, String content, String note) {
        try {
            JSONObject change = new JSONObject();
            change.put("action", "insert");
            change.put("parent_id", parentId);
            change.put("index", 0);
            change.put("content", content);
            change.put("note", note);
            JSONObject b = new JSONObject();
            b.put("token", token);
            b.put("file_id", fileId);
            b.put("changes", new JSONArray().put(change));
            return b;
        } catch (JSONException e) {
            throw new IllegalStateException(e);
        }
    }

    public static Response insert(String token, String fileId, String parentId, String content, String note) {
        return post("doc/edit", insertBody(token, fileId, parentId, content, note));
    }

    /**
     * doc/edit 응답의 생성 노드 ID(new_node_ids[0]). 없거나, results 배열이 있는데 성공(true)이 아니면 null
     * → 호출자는 '서버 대조 필요'로 두고 식별자로 확인한다.
     */
    public static String newNodeId(JSONObject json) {
        if (json == null) return null;
        JSONArray results = json.optJSONArray("results");
        if (results != null && (results.length() != 1 || !results.optBoolean(0, false))) return null;
        JSONArray ids = json.optJSONArray("new_node_ids");
        if (ids == null || ids.length() != 1) return null;
        String id = ids.optString(0, null);
        return id == null || id.isEmpty() ? null : id;
    }
}
