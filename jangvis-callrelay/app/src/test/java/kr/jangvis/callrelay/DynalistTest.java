package kr.jangvis.callrelay;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.fail;

import org.json.JSONException;
import org.json.JSONObject;
import org.junit.Test;

/** 응답 해석 규칙. org.json은 테스트 의존성(org.json:json)으로 JVM에서 실행한다. */
public class DynalistTest {
    @Test
    public void interpretsApiCodeNotJustHttpStatus() {
        assertEquals(Dynalist.Kind.OK, Dynalist.interpret(200, "{\"_code\":\"Ok\"}").kind);
        assertEquals(Dynalist.Kind.AUTH, Dynalist.interpret(200, "{\"_code\":\"InvalidToken\"}").kind);
        assertEquals(Dynalist.Kind.AUTH, Dynalist.interpret(200, "{\"_code\":\"Unauthorized\"}").kind);
        assertEquals(Dynalist.Kind.RATE_LIMITED, Dynalist.interpret(200, "{\"_code\":\"TooManyRequests\"}").kind);
        assertEquals(Dynalist.Kind.NOT_FOUND, Dynalist.interpret(200, "{\"_code\":\"NotFound\"}").kind);
        assertEquals(Dynalist.Kind.NOT_FOUND, Dynalist.interpret(200, "{\"_code\":\"NodeNotFound\"}").kind);
        assertEquals(Dynalist.Kind.TEMPORARY, Dynalist.interpret(200, "{\"_code\":\"LockFail\"}").kind);
        assertEquals(Dynalist.Kind.INVALID, Dynalist.interpret(200, "{\"_code\":\"Invalid\"}").kind);
        assertEquals(Dynalist.Kind.INVALID, Dynalist.interpret(200, "{\"_code\":\"SomethingNew\"}").kind);
        assertEquals(Dynalist.Kind.INVALID, Dynalist.interpret(200, "<html>proxy</html>").kind);
        assertEquals(Dynalist.Kind.RATE_LIMITED, Dynalist.interpret(429, "").kind);
        assertEquals(Dynalist.Kind.UNKNOWN, Dynalist.interpret(502, "bad gateway").kind);
    }

    @Test
    public void findsRootAndMarkers() throws Exception {
        String id = Policy.itemId("k", "t");
        JSONObject doc = new JSONObject("{\"_code\":\"Ok\",\"title\":\"수집\",\"nodes\":["
                + "{\"id\":\"a1\",\"content\":\"통화\",\"note\":\"t\\n\\n" + Policy.marker(id) + "\"},"
                + "{\"id\":\"root\",\"content\":\"수집\",\"children\":[\"a1\"]}]}");
        Dynalist.Doc d = Dynalist.parseDoc(doc);
        assertEquals("root", d.rootId);
        assertEquals("a1", d.markers.get(id));
        assertEquals(2, d.nodeCount);
    }

    @Test
    public void rootWithOtherIdIsAccepted() throws Exception {
        JSONObject doc = new JSONObject("{\"nodes\":[{\"id\":\"zz9\",\"children\":[\"c\"]},{\"id\":\"c\"}]}");
        assertEquals("zz9", Dynalist.parseDoc(doc).rootId);
    }

    @Test
    public void ambiguousRootRejected() throws Exception {
        JSONObject doc = new JSONObject("{\"nodes\":[{\"id\":\"x\"},{\"id\":\"y\"}]}");
        try {
            Dynalist.parseDoc(doc);
            fail();
        } catch (JSONException expected) {
            // 루트를 추측하지 않는다
        }
    }

    @Test
    public void newNodeIdRequiresExactlyOne() throws Exception {
        assertEquals("n1", Dynalist.newNodeId(new JSONObject("{\"_code\":\"Ok\",\"new_node_ids\":[\"n1\"]}")));
        assertNull(Dynalist.newNodeId(new JSONObject("{\"_code\":\"Ok\"}")));
        assertNull(Dynalist.newNodeId(new JSONObject("{\"_code\":\"Ok\",\"new_node_ids\":[]}")));
        assertNull(Dynalist.newNodeId(null));
    }

    @Test
    public void insertBodyShape() throws Exception {
        JSONObject b = Dynalist.insertBody("tk", "DOC", "root", "통화 · x", "본문");
        assertEquals("DOC", b.getString("file_id"));
        JSONObject ch = b.getJSONArray("changes").getJSONObject(0);
        assertEquals("insert", ch.getString("action"));
        assertEquals("root", ch.getString("parent_id"));
        assertEquals(0, ch.getInt("index"));
    }
}
