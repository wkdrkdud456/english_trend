package kr.jangvis.callrelay;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.json.JSONObject;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import okhttp3.mockwebserver.SocketPolicy;

/** 실제 HTTP 계층: 요청 형식과 '보내기 전 실패 / 보낸 뒤 응답 손실' 구분. */
public class DynalistHttpTest {
    private MockWebServer server;

    @Before
    public void setUp() throws Exception {
        server = new MockWebServer();
        server.start();
        Dynalist.baseUrl = server.url("/api/v1/").toString();
    }

    @After
    public void tearDown() throws Exception {
        server.shutdown();
        Dynalist.baseUrl = Dynalist.BASE;
    }

    @Test
    public void postsJsonToEditEndpoint() throws Exception {
        server.enqueue(new MockResponse().setBody("{\"_code\":\"Ok\",\"new_node_ids\":[\"abc\"]}"));
        Dynalist.Response r = Dynalist.insert("tk", "DOC123456", "root", "통화 · 제목", "본문\n\n[장비스 통화 #x]");
        assertEquals(Dynalist.Kind.OK, r.kind);
        assertEquals("abc", Dynalist.newNodeId(r.json));
        RecordedRequest req = server.takeRequest();
        assertEquals("POST", req.getMethod());
        assertEquals("/api/v1/doc/edit", req.getPath());
        assertEquals("application/json; charset=utf-8", req.getHeader("Content-Type"));
        JSONObject b = new JSONObject(req.getBody().readUtf8());
        assertEquals("DOC123456", b.getString("file_id"));
        assertEquals("통화 · 제목", b.getJSONArray("changes").getJSONObject(0).getString("content"));
    }

    @Test
    public void readEndpoint() throws Exception {
        server.enqueue(new MockResponse().setBody("{\"_code\":\"InvalidToken\",\"_msg\":\"x\"}"));
        assertEquals(Dynalist.Kind.AUTH, Dynalist.readDoc("bad", "DOC123456").kind);
        assertEquals("/api/v1/doc/read", server.takeRequest().getPath());
    }

    @Test
    public void lostResponseIsUnknown() {
        server.enqueue(new MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AFTER_REQUEST));
        Dynalist.Response r = Dynalist.insert("tk", "DOC123456", "root", "c", "n");
        assertEquals(Dynalist.Kind.UNKNOWN, r.kind);
    }

    @Test
    public void serverErrorIsUnknown() {
        server.enqueue(new MockResponse().setResponseCode(502).setBody("gateway"));
        assertEquals(Dynalist.Kind.UNKNOWN, Dynalist.insert("tk", "DOC123456", "root", "c", "n").kind);
    }

    @Test
    public void connectionRefusedIsNotSent() throws Exception {
        Dynalist.baseUrl = "http://127.0.0.1:1/api/v1/";
        Dynalist.Response r = Dynalist.insert("tk", "DOC123456", "root", "c", "n");
        assertEquals(Dynalist.Kind.NOT_SENT, r.kind);
        assertTrue(!r.describe().contains("tk"));
    }

    @Test
    public void rateLimitHttp429() {
        server.enqueue(new MockResponse().setResponseCode(429));
        assertEquals(Dynalist.Kind.RATE_LIMITED, Dynalist.readDoc("tk", "DOC123456").kind);
    }

    @Test
    public void productionBaseIsHttps() {
        assertTrue(Dynalist.BASE.startsWith("https://dynalist.io/api/v1/"));
    }
}
