package kr.jangvis.callrelay;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.content.Context;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;

import java.util.List;

@RunWith(RobolectricTestRunner.class)
public class QueueTest {
    private Context ctx;
    private Queue q;

    @Before
    public void setUp() {
        ctx = RuntimeEnvironment.getApplication();
        Queue.resetForTest();
        q = Queue.get(ctx);
        q.getWritableDatabase().delete("items", null, null);
    }

    @Test
    public void duplicateInsertKeepsOriginal() {
        assertEquals(Queue.InsertResult.INSERTED, q.insert("a1", "t", "본문", "k", "DOC1", "share", 1));
        assertEquals(Queue.InsertResult.DUPLICATE, q.insert("a1", "t2", "다른", "k", "DOC2", "share", 2));
        Queue.Item it = q.find("a1");
        assertEquals("본문", it.text);
        assertEquals("DOC1", it.destination);
    }

    @Test
    public void claimIsExclusive() {
        q.insert("a1", "t", "x", "", "DOC", "share", 1);
        Queue.Item first = q.ready(10, 10).get(0);
        Queue.Item second = q.ready(10, 10).get(0);
        assertTrue(q.claim(first, "T1", 10));
        assertFalse("다른 작업이 같은 항목을 다시 선점하면 안 됨", q.claim(second, "T2", 10));
        // 선점하지 않은 쪽은 상태를 바꿀 수 없다
        second.claim = "T2";
        assertFalse(q.markSent(second, "n", 11));
        assertTrue(q.markSent(first, "n1", 11));
        assertEquals(Queue.SENT, q.find("a1").state);
        assertEquals("n1", q.find("a1").nodeId);
        assertTrue(q.ready(100, 10).isEmpty());
    }

    @Test
    public void noDestinationWaitsUntilAssigned() {
        q.insert("a1", "t", "x", "", null, "share", 1);
        q.insert("a2", "t", "x", "", "OLD", "share", 2);
        assertEquals(1, q.ready(10, 10).size());
        assertEquals(1, q.assignMissingDestination("NEW", 3));
        assertEquals("NEW", q.find("a1").destination);
        assertEquals("기존 항목의 목적지는 바뀌지 않음", "OLD", q.find("a2").destination);
    }

    @Test
    public void backoffDelaysReady() {
        q.insert("a1", "t", "x", "", "DOC", "share", 1);
        Queue.Item it = q.ready(10, 10).get(0);
        assertTrue(q.claim(it, "T", 10));
        assertTrue(q.release(it, 5_000, "net", true, 10));
        assertTrue(q.ready(4_999, 10).isEmpty());
        assertEquals(1, q.ready(5_000, 10).size());
        assertEquals(1, q.find("a1").attempts);
        assertEquals(5_000, q.nextWakeAt());
    }

    @Test
    public void staleSendingBecomesUncertainAndVerifiedLater() {
        q.insert("a1", "t", "x", "", "DOC", "share", 1);
        Queue.Item it = q.ready(10, 10).get(0);
        assertTrue(q.claim(it, "T", 10));
        assertEquals(0, q.recoverStale(10 + Queue.STALE_SENDING_MS - 1));
        assertEquals(1, q.recoverStale(10 + Queue.STALE_SENDING_MS + 1));
        Queue.Item u = q.find("a1");
        assertEquals(Queue.UNCERTAIN, u.state);
        // 늦게 도착한 원래 작업은 결과를 덮어쓸 수 없다
        assertFalse(q.markSent(it, "late", 20));
    }

    @Test
    public void uncertainNeedsDelayAndHasCap() {
        q.insert("a1", "t", "x", "", "DOC", "share", 1);
        long now = 1_000;
        for (int i = 0; i < Policy.MAX_UNCERTAIN; i++) {
            Queue.Item it = q.ready(now, 10).get(0);
            assertTrue(q.claim(it, "T" + i, now));
            assertTrue(q.markUncertain(it, "lost", now));
            assertTrue("확인 지연 전에는 다시 꺼내지 않음", q.ready(now + 1, 10).isEmpty());
            now += Policy.UNCERTAIN_VERIFY_DELAY_MS;
        }
        assertTrue("한도 초과 시 자동 처리 중단", q.ready(now, 10).isEmpty());
        assertEquals(1, q.retryErrors(now));
        Queue.Item it = q.ready(now, 10).get(0);
        assertEquals("재시도해도 uncertain 그대로(대조 후에만 재전송)", Queue.UNCERTAIN, it.state);
    }

    @Test
    public void errorsRetryKeepDestination() {
        q.insert("a1", "t", "x", "", "DOC", "share", 1);
        Queue.Item it = q.ready(10, 10).get(0);
        assertTrue(q.claim(it, "T", 10));
        assertTrue(q.markError(it, "토큰 오류", 10));
        assertTrue(q.ready(10, 10).isEmpty());
        assertEquals(1, q.retryErrors(20));
        List<Queue.Item> r = q.ready(20, 10);
        assertEquals(1, r.size());
        assertEquals("DOC", r.get(0).destination);
        assertEquals(Queue.PENDING, r.get(0).state);
    }

    @Test
    public void prunesOldSentText() {
        q.insert("a1", "t", "x", "", "DOC", "share", 1);
        Queue.Item it = q.ready(10, 10).get(0);
        q.claim(it, "T", 10);
        q.markSent(it, "n", 10);
        long later = 10 + 31L * 24 * 3600_000L;
        assertEquals(1, q.pruneSentText(later));
        assertEquals("", q.find("a1").text);
        // 재공유는 여전히 중복으로 판단
        assertEquals(Queue.InsertResult.DUPLICATE, q.insert("a1", "t", "x", "", "DOC", "share", later));
        assertNull(q.find("a1").lastError);
    }
}
