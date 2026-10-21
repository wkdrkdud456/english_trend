package kr.jangvis.callrelay;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * SQLite 전송 대기열.
 *
 * 상태: pending → sending → sent
 *                        ↘ error     (사용자 조치 필요: 토큰·문서 오류)
 *                        ↘ uncertain (요청이 서버에 닿았을 수 있음: 다음 전송 전에 식별자로 대조)
 *
 * 모든 상태 전이는 조건부 UPDATE로 하고, 반영된 행 수로 선점 여부를 판단한다.
 */
public final class Queue extends SQLiteOpenHelper {
    public static final String PENDING = "pending";
    public static final String SENDING = "sending";
    public static final String SENT = "sent";
    public static final String ERROR = "error";
    public static final String UNCERTAIN = "uncertain";
    /** 수동 선택 전송: 목록에 보관만 하고, 사용자가 고를 때 pending으로 바꾼다. */
    public static final String HELD = "held";
    /** 목록에서 숨김(ID는 남겨 같은 통화를 다시 불러와도 다시 나타나지 않게 함). */
    public static final String DISMISSED = "dismissed";

    /** 프로세스가 죽어 sending에 남은 항목을 uncertain으로 돌리는 기준. */
    public static final long STALE_SENDING_MS = 5 * 60_000L;

    private static volatile Queue instance;

    public static Queue get(Context c) {
        if (instance == null) {
            synchronized (Queue.class) {
                if (instance == null) instance = new Queue(c.getApplicationContext());
            }
        }
        return instance;
    }

    /** 단위 검사 전용: 검사마다 새 데이터베이스를 쓰도록 싱글턴을 비운다. */
    static synchronized void resetForTest() {
        if (instance != null) instance.close();
        instance = null;
    }

    private Queue(Context c) {
        super(c, "callrelay.db", null, 1);
    }

    @Override
    public void onConfigure(SQLiteDatabase db) {
        db.enableWriteAheadLogging();
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE items ("
                + "id TEXT PRIMARY KEY NOT NULL,"
                + "title TEXT NOT NULL,"
                + "text TEXT NOT NULL,"
                + "state TEXT NOT NULL,"
                + "created INTEGER NOT NULL,"
                + "destination TEXT,"          // 수집 당시 Dynalist 문서 ID(고정)
                + "call_key TEXT NOT NULL DEFAULT '',"
                + "source TEXT NOT NULL DEFAULT 'share',"
                + "attempts INTEGER NOT NULL DEFAULT 0,"
                + "uncertain_count INTEGER NOT NULL DEFAULT 0,"
                + "next_at INTEGER NOT NULL DEFAULT 0,"
                + "claim TEXT,"
                + "claimed_at INTEGER,"
                + "prev_state TEXT,"
                + "node_id TEXT,"
                + "last_error TEXT,"
                + "updated INTEGER NOT NULL)");
        db.execSQL("CREATE INDEX items_state ON items(state, next_at)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldV, int newV) {
        // 버전 1만 존재
    }

    /** 대기열 항목(전송 작업용 스냅샷). */
    public static final class Item {
        public String id, title, text, state, destination, callKey, source, nodeId, lastError, claim, prevState;
        public long created, nextAt, updated;
        public int attempts, uncertainCount;
    }

    public enum InsertResult { INSERTED, DUPLICATE }

    /** 새 항목 저장. 같은 ID가 있으면 아무것도 바꾸지 않는다. */
    public InsertResult insert(String id, String title, String text, String callKey, String destination,
                               String source, long now) {
        return insert(id, title, text, callKey, destination, source, now, PENDING);
    }

    public InsertResult insert(String id, String title, String text, String callKey, String destination,
                               String source, long now, String state) {
        ContentValues v = new ContentValues();
        v.put("id", id);
        v.put("title", title);
        v.put("text", text);
        v.put("state", state);
        v.put("created", now);
        if (destination == null) v.putNull("destination");
        else v.put("destination", destination);
        v.put("call_key", callKey == null ? "" : callKey);
        v.put("source", source);
        v.put("updated", now);
        long row = getWritableDatabase().insertWithOnConflict("items", null, v, SQLiteDatabase.CONFLICT_IGNORE);
        return row == -1 ? InsertResult.DUPLICATE : InsertResult.INSERTED;
    }

    public Item find(String id) {
        try (Cursor c = getReadableDatabase().query("items", null, "id=?", new String[]{id}, null, null, null)) {
            return c.moveToFirst() ? read(c) : null;
        }
    }

    /**
     * 전송 후보: 목적지가 있고, 대기 시간이 지난 pending 항목과 확인 지연이 지난 uncertain 항목.
     */
    public List<Item> ready(long now, int limit) {
        List<Item> out = new ArrayList<>();
        try (Cursor c = getReadableDatabase().query("items", null,
                "destination IS NOT NULL AND ((state='pending' AND next_at<=?) OR (state='uncertain' AND next_at<=? AND uncertain_count<?))",
                new String[]{Long.toString(now), Long.toString(now), Integer.toString(Policy.MAX_UNCERTAIN)},
                null, null, "created ASC", Integer.toString(limit))) {
            while (c.moveToNext()) out.add(read(c));
        }
        return out;
    }

    /**
     * 조건부 UPDATE로 항목을 선점한다. 다른 작업이 먼저 가져갔으면 false.
     * prev_state에 원래 상태를 남겨 실패 시 되돌린다.
     */
    public boolean claim(Item it, String token, long now) {
        ContentValues v = new ContentValues();
        v.put("state", SENDING);
        v.put("claim", token);
        v.put("claimed_at", now);
        v.put("prev_state", it.state);
        v.put("updated", now);
        int n = getWritableDatabase().update("items", v,
                "id=? AND state=? AND next_at<=? AND destination IS NOT NULL",
                new String[]{it.id, it.state, Long.toString(now)});
        if (n == 1) {
            it.prevState = it.state;
            it.state = SENDING;
            it.claim = token;
        }
        return n == 1;
    }

    public boolean markSent(Item it, String nodeId, long now) {
        ContentValues v = new ContentValues();
        v.put("state", SENT);
        if (nodeId == null) v.putNull("node_id");
        else v.put("node_id", nodeId);
        v.putNull("last_error");
        v.putNull("claim");
        v.put("updated", now);
        return finish(it, v);
    }

    /** 서버에 닿지 않은 것이 확실한 실패: 원래 상태로 되돌리고 나중에 재시도. */
    public boolean release(Item it, long nextAt, String error, boolean countAttempt, long now) {
        ContentValues v = new ContentValues();
        v.put("state", it.prevState == null ? PENDING : it.prevState);
        v.put("next_at", nextAt);
        if (countAttempt) v.put("attempts", it.attempts + 1);
        if (error == null) v.putNull("last_error");
        else v.put("last_error", error);
        v.putNull("claim");
        v.put("updated", now);
        return finish(it, v);
    }

    /** 확인 결과 서버에 없음: 다시 보낼 수 있는 pending으로. */
    public boolean releaseAsPending(Item it, long now) {
        it.prevState = PENDING;
        return release(it, 0, null, false, now);
    }

    public boolean markError(Item it, String error, long now) {
        ContentValues v = new ContentValues();
        v.put("state", ERROR);
        v.put("attempts", it.attempts + 1);
        v.put("last_error", error);
        v.putNull("claim");
        v.put("updated", now);
        return finish(it, v);
    }

    /** 요청 본문을 보낸 뒤 응답을 못 받음: 재전송 전 반드시 식별자로 대조. */
    public boolean markUncertain(Item it, String error, long now) {
        ContentValues v = new ContentValues();
        v.put("state", UNCERTAIN);
        v.put("uncertain_count", it.uncertainCount + 1);
        v.put("next_at", now + Policy.UNCERTAIN_VERIFY_DELAY_MS);
        v.put("last_error", error);
        v.putNull("claim");
        v.put("updated", now);
        return finish(it, v);
    }

    private boolean finish(Item it, ContentValues v) {
        int n = getWritableDatabase().update("items", v, "id=? AND state='sending' AND claim=?",
                new String[]{it.id, it.claim});
        return n == 1;
    }

    /** 오래된 sending(프로세스 종료 등)은 서버 반영 여부를 모르므로 uncertain으로. */
    public int recoverStale(long now) {
        ContentValues v = new ContentValues();
        v.put("state", UNCERTAIN);
        v.put("next_at", now);
        v.put("last_error", "전송 중 앱이 종료됨 – 서버 대조 필요");
        v.putNull("claim");
        v.put("updated", now);
        return getWritableDatabase().update("items", v, "state='sending' AND claimed_at<?",
                new String[]{Long.toString(now - STALE_SENDING_MS)});
    }

    /** 사용자가 설정을 고친 뒤 오류·확인 한도 초과 항목을 다시 시도. 목적지는 바꾸지 않는다. */
    public int retryErrors(long now) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues v = new ContentValues();
        v.put("state", PENDING);
        v.put("attempts", 0);
        v.put("next_at", 0);
        v.put("updated", now);
        int n = db.update("items", v, "state='error'", null);
        // 확인 한도를 넘긴 uncertain은 상태를 유지한 채 대조만 다시 허용(바로 재전송하지 않음)
        ContentValues u = new ContentValues();
        u.put("uncertain_count", 0);
        u.put("next_at", 0);
        u.put("updated", now);
        n += db.update("items", u, "state='uncertain' AND uncertain_count>=?",
                new String[]{Integer.toString(Policy.MAX_UNCERTAIN)});
        return n;
    }

    /** 목적지 없이 수집된 항목(설정 전 공유)을 처음 설정한 문서로 지정. 이미 지정된 항목은 그대로. */
    public int assignMissingDestination(String docId, long now) {
        ContentValues v = new ContentValues();
        v.put("destination", docId);
        v.put("updated", now);
        return getWritableDatabase().update("items", v, "destination IS NULL", null);
    }

    /** 통화 목록 화면: 숨김을 뺀 항목(최신순). */
    public List<Item> pickList(int limit) {
        List<Item> out = new ArrayList<>();
        try (Cursor c = getReadableDatabase().query("items",
                new String[]{"id", "title", "text", "state", "created", "destination", "attempts", "uncertain_count",
                        "next_at", "node_id", "last_error", "updated", "call_key", "source"},
                "state!='dismissed'", null, null, null, "created DESC", Integer.toString(limit))) {
            while (c.moveToNext()) out.add(read(c));
        }
        return out;
    }

    /** 선택 항목 전송: 보관·오류 항목만 pending으로. 목적지가 없으면 지금 설정된 문서로 지정. */
    public int queueSelected(List<String> ids, String currentDoc, long now) {
        SQLiteDatabase db = getWritableDatabase();
        int n = 0;
        db.beginTransaction();
        try {
            for (String id : ids) {
                ContentValues v = new ContentValues();
                v.put("state", PENDING);
                v.put("attempts", 0);
                v.put("next_at", 0);
                v.put("updated", now);
                int k = db.update("items", v, "id=? AND state IN ('held','error') AND destination IS NOT NULL",
                        new String[]{id});
                if (k == 0 && currentDoc != null) {
                    v.put("destination", currentDoc);
                    k = db.update("items", v, "id=? AND state IN ('held','error') AND destination IS NULL",
                            new String[]{id});
                }
                n += k;
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
        return n;
    }

    /** 선택 항목 숨기기: 보관·오류 항목만(전송 중·완료 항목은 건드리지 않음). 본문도 지운다. */
    public int dismiss(List<String> ids, long now) {
        SQLiteDatabase db = getWritableDatabase();
        int n = 0;
        for (String id : ids) {
            ContentValues v = new ContentValues();
            v.put("state", DISMISSED);
            v.put("text", "");
            v.put("updated", now);
            n += db.update("items", v, "id=? AND state IN ('held','error')", new String[]{id});
        }
        return n;
    }

    public Map<String, Integer> counts() {
        Map<String, Integer> m = new LinkedHashMap<>();
        for (String s : new String[]{HELD, PENDING, SENDING, SENT, ERROR, UNCERTAIN}) m.put(s, 0);
        try (Cursor c = getReadableDatabase().rawQuery("SELECT state, COUNT(*) FROM items GROUP BY state", null)) {
            while (c.moveToNext()) m.put(c.getString(0), c.getInt(1));
        }
        return m;
    }

    public int countWithoutDestination() {
        try (Cursor c = getReadableDatabase().rawQuery(
                "SELECT COUNT(*) FROM items WHERE destination IS NULL AND state!='sent'", null)) {
            return c.moveToFirst() ? c.getInt(0) : 0;
        }
    }

    public int countUnsentFor(String destination) {
        try (Cursor c = getReadableDatabase().rawQuery(
                "SELECT COUNT(*) FROM items WHERE destination=? AND state!='sent'", new String[]{destination})) {
            return c.moveToFirst() ? c.getInt(0) : 0;
        }
    }

    /**
     * 다음에 깨어나야 할 시각(대기 중인 항목 중 가장 이른 next_at), 없으면 -1.
     * sending에 남은 항목은 오래된 선점을 정리할 시각을 포함한다.
     */
    public long nextWakeAt() {
        try (Cursor c = getReadableDatabase().rawQuery(
                "SELECT MIN(t) FROM ("
                        + "SELECT next_at AS t FROM items WHERE destination IS NOT NULL AND (state='pending' OR (state='uncertain' AND uncertain_count<?))"
                        + " UNION ALL SELECT claimed_at+? AS t FROM items WHERE state='sending')",
                new String[]{Integer.toString(Policy.MAX_UNCERTAIN), Long.toString(STALE_SENDING_MS + 1_000L)})) {
            if (c.moveToFirst() && !c.isNull(0)) return c.getLong(0);
            return -1;
        }
    }

    public List<Item> recent(int limit) {
        List<Item> out = new ArrayList<>();
        try (Cursor c = getReadableDatabase().query("items",
                new String[]{"id", "title", "state", "created", "destination", "attempts", "uncertain_count",
                        "next_at", "node_id", "last_error", "updated", "call_key", "source"},
                null, null, null, null, "created DESC", Integer.toString(limit))) {
            while (c.moveToNext()) out.add(read(c));
        }
        return out;
    }

    /** 전송 완료 후 30일 지난 항목은 본문만 비워 개인정보를 줄인다(ID는 남겨 재공유 중복 방지). */
    public int pruneSentText(long now) {
        ContentValues v = new ContentValues();
        v.put("text", "");
        return getWritableDatabase().update("items", v, "state='sent' AND updated<? AND text!=''",
                new String[]{Long.toString(now - 30L * 24 * 3600_000L)});
    }

    private static Item read(Cursor c) {
        Item it = new Item();
        it.id = str(c, "id");
        it.title = str(c, "title");
        it.text = str(c, "text");
        it.state = str(c, "state");
        it.destination = str(c, "destination");
        it.callKey = str(c, "call_key");
        it.source = str(c, "source");
        it.nodeId = str(c, "node_id");
        it.lastError = str(c, "last_error");
        it.claim = str(c, "claim");
        it.prevState = str(c, "prev_state");
        it.created = lng(c, "created");
        it.nextAt = lng(c, "next_at");
        it.updated = lng(c, "updated");
        it.attempts = (int) lng(c, "attempts");
        it.uncertainCount = (int) lng(c, "uncertain_count");
        return it;
    }

    private static String str(Cursor c, String col) {
        int i = c.getColumnIndex(col);
        return i < 0 || c.isNull(i) ? null : c.getString(i);
    }

    private static long lng(Cursor c, String col) {
        int i = c.getColumnIndex(col);
        return i < 0 || c.isNull(i) ? 0 : c.getLong(i);
    }
}
