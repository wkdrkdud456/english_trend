package kr.jangvis.callrelay;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import okhttp3.mockwebserver.Dispatcher;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import okhttp3.mockwebserver.SocketPolicy;

/** 가짜 Dynalist 서버로 전송 작업 전체 흐름을 검사한다(실서버·실토큰 미사용). */
@RunWith(RobolectricTestRunner.class)
public class UploadJobTest {
    private static final String TOKEN = "test-token-not-real";

    /** 문서별 노드 목록을 가진 가짜 Dynalist. */
    static final class FakeDynalist extends Dispatcher {
        final Map<String, List<JSONObject>> docs = new HashMap<>();
        final List<JSONObject> requests = new ArrayList<>();
        int reads, edits;
        boolean rateLimitNextRead, rateLimitNextEdit, invalidToken, omitNodeIds;
        int dropResponseOnEdits; // 저장은 하고 응답만 끊는 횟수
        int nextNode = 1;

        void addDoc(String id) {
            List<JSONObject> nodes = new ArrayList<>();
            try {
                nodes.add(new JSONObject().put("id", "root").put("content", "수집").put("note", "")
                        .put("children", new JSONArray()));
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            docs.put(id, nodes);
        }

        @Override
        public synchronized MockResponse dispatch(RecordedRequest r) {
            try {
                JSONObject body = new JSONObject(r.getBody().readUtf8());
                requests.add(body);
                if (!"application/json; charset=utf-8".equals(r.getHeader("Content-Type"))) {
                    return json("{\"_code\":\"Invalid\",\"_msg\":\"content-type\"}");
                }
                if (!"POST".equals(r.getMethod())) return new MockResponse().setResponseCode(405);
                if (invalidToken || !TOKEN.equals(body.optString("token"))) {
                    return json("{\"_code\":\"InvalidToken\",\"_msg\":\"bad\"}");
                }
                List<JSONObject> nodes = docs.get(body.optString("file_id"));
                if (r.getPath().endsWith("/doc/read")) {
                    reads++;
                    if (rateLimitNextRead) {
                        rateLimitNextRead = false;
                        return json("{\"_code\":\"TooManyRequests\",\"_msg\":\"slow down\"}");
                    }
                    if (nodes == null) return json("{\"_code\":\"NotFound\",\"_msg\":\"\"}");
                    JSONObject res = new JSONObject().put("_code", "Ok").put("file_id", body.getString("file_id"))
                            .put("title", "통화 수집").put("version", 1).put("nodes", new JSONArray(nodes));
                    return json(res.toString());
                }
                if (r.getPath().endsWith("/doc/edit")) {
                    edits++;
                    if (rateLimitNextEdit) {
                        rateLimitNextEdit = false;
                        return new MockResponse().setResponseCode(429);
                    }
                    if (nodes == null) return json("{\"_code\":\"NotFound\",\"_msg\":\"\"}");
                    JSONArray changes = body.getJSONArray("changes");
                    JSONArray ids = new JSONArray();
                    for (int i = 0; i < changes.length(); i++) {
                        JSONObject ch = changes.getJSONObject(i);
                        JSONObject parent = null;
                        for (JSONObject n : nodes) if (n.getString("id").equals(ch.getString("parent_id"))) parent = n;
                        if (parent == null) return json("{\"_code\":\"NodeNotFound\",\"_msg\":\"\"}");
                        String nid = "n" + (nextNode++);
                        nodes.add(new JSONObject().put("id", nid).put("content", ch.getString("content"))
                                .put("note", ch.getString("note")).put("children", new JSONArray()));
                        JSONArray kids = parent.getJSONArray("children");
                        JSONArray nk = new JSONArray().put(nid);
                        for (int k = 0; k < kids.length(); k++) nk.put(kids.get(k));
                        parent.put("children", nk);
                        ids.put(nid);
                    }
                    if (dropResponseOnEdits > 0) {
                        dropResponseOnEdits--;
                        return new MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AFTER_REQUEST);
                    }
                    JSONObject res = new JSONObject().put("_code", "Ok");
                    if (!omitNodeIds) res.put("new_node_ids", ids);
                    return json(res.toString());
                }
                return new MockResponse().setResponseCode(404);
            } catch (Exception e) {
                return new MockResponse().setResponseCode(500);
            }
        }

        static MockResponse json(String s) {
            return new MockResponse().setHeader("Content-Type", "application/json").setBody(s);
        }

        int countMarker(String doc, String id) throws Exception {
            int n = 0;
            for (JSONObject node : docs.get(doc)) if (node.optString("note").endsWith(Policy.marker(id))) n++;
            return n;
        }
    }

    private MockWebServer server;
    private FakeDynalist fake;
    private Context ctx;
    private Queue q;

    @Before
    public void setUp() throws Exception {
        ctx = RuntimeEnvironment.getApplication();
        Queue.resetForTest();
        q = Queue.get(ctx);
        fake = new FakeDynalist();
        fake.addDoc("DOC_A_123456");
        fake.addDoc("DOC_B_123456");
        server = new MockWebServer();
        server.setDispatcher(fake);
        server.start();
        Dynalist.baseUrl = server.url("/api/v1/").toString();
        State.tokenForTest = TOKEN;
        State.setRateBlockedUntil(ctx, 0);
        UploadJob.minReadIntervalMs = 0;
        UploadJob.minEditIntervalMs = 0;
    }

    @After
    public void tearDown() throws Exception {
        server.shutdown();
        Dynalist.baseUrl = Dynalist.BASE;
        State.tokenForTest = null;
    }

    private UploadJob job() {
        return Robolectric.setupService(UploadJob.class);
    }

    private String add(String callKey, String text, String dest) {
        String id = Policy.itemId(callKey, text);
        q.insert(id, Policy.title(callKey, 0), text, callKey, dest, "share", System.currentTimeMillis());
        return id;
    }

    private void timePasses() {
        q.getWritableDatabase().execSQL("UPDATE items SET next_at=0");
        State.setRateBlockedUntil(ctx, 0);
    }

    @Test
    public void sendsWithRootParentAndMarker() throws Exception {
        String id = add("통화 녹음 A_251021.txt", "화자1: 안녕하세요", "DOC_A_123456");
        job().runOnce();
        Queue.Item it = q.find(id);
        assertEquals(Queue.SENT, it.state);
        assertNotNull(it.nodeId);
        assertEquals(1, fake.reads);
        assertEquals(1, fake.edits);
        JSONObject edit = fake.requests.get(1);
        assertEquals("DOC_A_123456", edit.getString("file_id"));
        JSONObject ch = edit.getJSONArray("changes").getJSONObject(0);
        assertEquals("insert", ch.getString("action"));
        assertEquals("root", ch.getString("parent_id"));
        assertEquals(0, ch.getInt("index"));
        assertEquals("통화 · 통화 녹음 A_251021", ch.getString("content"));
        assertTrue(ch.getString("note").startsWith("화자1: 안녕하세요"));
        assertTrue(ch.getString("note").endsWith("[장비스 통화 #" + id + "]"));
    }

    @Test
    public void existingMarkerIsNotSentAgain() throws Exception {
        String id = add("통화 B.txt", "본문", "DOC_A_123456");
        fake.docs.get("DOC_A_123456").add(new JSONObject().put("id", "old").put("content", "x")
                .put("note", "본문\n\n" + Policy.marker(id)));
        job().runOnce();
        assertEquals(Queue.SENT, q.find(id).state);
        assertEquals("old", q.find(id).nodeId);
        assertEquals(0, fake.edits);
    }

    @Test
    public void lostResponseIsVerifiedNotResent() throws Exception {
        String id = add("통화 C.txt", "본문 C", "DOC_A_123456");
        fake.dropResponseOnEdits = 1;
        job().runOnce();
        assertEquals(Queue.UNCERTAIN, q.find(id).state);
        assertEquals(1, fake.countMarker("DOC_A_123456", id));
        // 확인 지연 전에는 아무것도 하지 않음
        job().runOnce();
        assertEquals(1, fake.edits);
        timePasses();
        job().runOnce();
        assertEquals(Queue.SENT, q.find(id).state);
        assertEquals("재전송 없음", 1, fake.edits);
        assertEquals(1, fake.countMarker("DOC_A_123456", id));
    }

    @Test
    public void lostResponseWithoutServerSaveIsResentAfterVerification() throws Exception {
        String id = add("통화 D.txt", "본문 D", "DOC_A_123456");
        fake.dropResponseOnEdits = 1;
        job().runOnce();
        // 서버에 저장되지 않은 상황을 만든다(노드 제거)
        List<JSONObject> nodes = fake.docs.get("DOC_A_123456");
        for (int i = nodes.size() - 1; i >= 0; i--) {
            if (nodes.get(i).optString("note").endsWith(Policy.marker(id))) nodes.remove(i);
        }
        timePasses();
        job().runOnce();
        assertEquals(Queue.SENT, q.find(id).state);
        assertEquals(2, fake.edits);
        assertEquals(1, fake.countMarker("DOC_A_123456", id));
    }

    @Test
    public void okWithoutNodeIdIsVerifiedByMarker() throws Exception {
        String id = add("통화 E.txt", "본문 E", "DOC_A_123456");
        fake.omitNodeIds = true;
        job().runOnce();
        assertEquals(Queue.UNCERTAIN, q.find(id).state);
        timePasses();
        job().runOnce();
        assertEquals(Queue.SENT, q.find(id).state);
        assertEquals(1, fake.edits);
    }

    @Test
    public void rateLimitBacksOff() throws Exception {
        String id = add("통화 F.txt", "본문 F", "DOC_A_123456");
        fake.rateLimitNextRead = true;
        job().runOnce();
        Queue.Item it = q.find(id);
        assertEquals(Queue.PENDING, it.state);
        assertTrue(it.nextAt > System.currentTimeMillis());
        assertTrue(State.rateBlockedUntil(ctx) > System.currentTimeMillis());
        job().runOnce();
        assertEquals("제한 시간 동안 요청하지 않음", 1, fake.reads);
        timePasses();
        fake.rateLimitNextEdit = true; // HTTP 429
        job().runOnce();
        assertEquals(Queue.PENDING, q.find(id).state);
        timePasses();
        job().runOnce();
        assertEquals(Queue.SENT, q.find(id).state);
        assertEquals(1, fake.countMarker("DOC_A_123456", id));
    }

    @Test
    public void invalidTokenMarksErrorAndRetryAfterFix() throws Exception {
        String id = add("통화 G.txt", "본문 G", "DOC_A_123456");
        fake.invalidToken = true;
        job().runOnce();
        assertEquals(Queue.ERROR, q.find(id).state);
        assertEquals(0, fake.edits);
        fake.invalidToken = false;
        job().runOnce();
        assertEquals("재시도 전에는 그대로", Queue.ERROR, q.find(id).state);
        assertEquals(1, q.retryErrors(System.currentTimeMillis()));
        job().runOnce();
        assertEquals(Queue.SENT, q.find(id).state);
    }

    @Test
    public void unknownDocumentIsError() {
        String id = add("통화 H.txt", "본문 H", "NO_SUCH_DOC_1");
        job().runOnce();
        assertEquals(Queue.ERROR, q.find(id).state);
    }

    @Test
    public void offlineKeepsPending() {
        String id = add("통화 I.txt", "본문 I", "DOC_A_123456");
        Dynalist.baseUrl = "http://127.0.0.1:1/api/v1/";
        job().runOnce();
        Queue.Item it = q.find(id);
        assertEquals(Queue.PENDING, it.state);
        assertEquals(1, it.attempts);
        Dynalist.baseUrl = server.url("/api/v1/").toString();
        timePasses();
        job().runOnce();
        assertEquals(Queue.SENT, q.find(id).state);
    }

    @Test
    public void moreThanOneBatchIsAllSent() throws Exception {
        List<String> ids = new ArrayList<>();
        for (int i = 0; i < 47; i++) ids.add(add("통화 " + i + ".txt", "같은 문장", "DOC_A_123456"));
        assertEquals("다른 통화의 같은 문장은 별도 항목", 47, q.counts().get(Queue.PENDING).intValue());
        job().runOnce();
        for (String id : ids) assertEquals(Queue.SENT, q.find(id).state);
        assertEquals(47, fake.edits);
    }

    @Test
    public void destinationFixedPerItem() throws Exception {
        String a = add("통화 J.txt", "본문 J", "DOC_A_123456");
        String b = add("통화 K.txt", "본문 K", "DOC_B_123456");
        job().runOnce();
        assertEquals(1, fake.countMarker("DOC_A_123456", a));
        assertEquals(0, fake.countMarker("DOC_B_123456", a));
        assertEquals(1, fake.countMarker("DOC_B_123456", b));
    }

    @Test
    public void crashedSendIsVerifiedBeforeResend() throws Exception {
        String id = add("통화 L.txt", "본문 L", "DOC_A_123456");
        Queue.Item it = q.ready(System.currentTimeMillis(), 10).get(0);
        // 이전 프로세스가 선점한 뒤 죽었고, 서버에는 이미 저장됨
        assertTrue(q.claim(it, "dead", System.currentTimeMillis() - Queue.STALE_SENDING_MS - 1000));
        fake.docs.get("DOC_A_123456").add(new JSONObject().put("id", "saved").put("content", "x")
                .put("note", "본문 L\n\n" + Policy.marker(id)));
        job().runOnce();
        assertEquals(Queue.SENT, q.find(id).state);
        assertEquals(0, fake.edits);
    }

    @Test
    public void tokenNeverInStatus() {
        add("통화 M.txt", "본문 M", "DOC_A_123456");
        fake.invalidToken = true;
        job().runOnce();
        assertTrue(!State.status(ctx).contains(TOKEN));
        for (Queue.Item it : q.recent(10)) assertTrue(it.lastError == null || !it.lastError.contains(TOKEN));
    }
}
