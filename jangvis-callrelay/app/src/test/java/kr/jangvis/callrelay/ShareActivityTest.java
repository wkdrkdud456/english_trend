package kr.jangvis.callrelay;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.robolectric.Shadows.shadowOf;

import android.content.Intent;
import android.database.MatrixCursor;
import android.net.Uri;
import android.provider.OpenableColumns;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.function.Supplier;
import java.nio.charset.StandardCharsets;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;

@RunWith(RobolectricTestRunner.class)
public class ShareActivityTest {
    private ShareActivity activity;
    private Queue q;

    /** 삼성 '텍스트 파일' 공유를 흉내 내는 content:// 제공자. */
    public static class FakeFiles extends ContentProvider {
        static String name = "통화 녹음 홍길동_251021_101112.txt";
        static String type = "text/plain";
        static byte[] data = new byte[0];

        @Override public boolean onCreate() { return true; }

        @Override
        public Cursor query(Uri uri, String[] projection, String selection, String[] args, String sort) {
            MatrixCursor c = new MatrixCursor(new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE});
            c.addRow(new Object[]{name, data.length});
            return c;
        }

        @Override public String getType(Uri uri) { return type; }
        @Override public Uri insert(Uri uri, ContentValues v) { return null; }
        @Override public int delete(Uri uri, String s, String[] a) { return 0; }
        @Override public int update(Uri uri, ContentValues v, String s, String[] a) { return 0; }
    }

    private static final Uri FILE = Uri.parse("content://kr.test.files/recording/1");

    @Before
    public void setUp() {
        Queue.resetForTest();
        q = Queue.get(RuntimeEnvironment.getApplication());
        Robolectric.setupContentProvider(FakeFiles.class, "kr.test.files");
        FakeFiles.name = "통화 녹음 홍길동_251021_101112.txt";
        FakeFiles.type = "text/plain";
        State.setDoc(RuntimeEnvironment.getApplication(), "DOC_A_123456", "수집");
        activity = Robolectric.buildActivity(ShareActivity.class, new Intent(Intent.ACTION_MAIN)).create().get();
    }

    private Intent fileShare() {
        // 파일 내용은 Robolectric ContentResolver 스트림으로, 이름·형식은 위 제공자로 응답한다.
        shadowOf(RuntimeEnvironment.getApplication().getContentResolver())
                .registerInputStreamSupplier(FILE, new Supplier<InputStream>() {
                    @Override
                    public InputStream get() {
                        return new ByteArrayInputStream(FakeFiles.data);
                    }
                });
        Intent i = new Intent(Intent.ACTION_SEND);
        i.setType("text/plain");
        i.putExtra(Intent.EXTRA_STREAM, FILE);
        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        return i;
    }

    @Test
    public void importsUtf16FileIntoQueueBeforeSending() {
        String text = "화자 1: 점검 일정 확인 부탁드립니다.";
        byte[] body = text.getBytes(StandardCharsets.UTF_16LE);
        FakeFiles.data = new byte[body.length + 2];
        FakeFiles.data[0] = (byte) 0xFF;
        FakeFiles.data[1] = (byte) 0xFE;
        System.arraycopy(body, 0, FakeFiles.data, 2, body.length);
        ShareActivity.Result r = activity.importShared(fileShare(), null);
        assertTrue(r.message, r.ok);
        assertFalse(r.duplicate);
        Queue.Item it = q.find(r.itemId);
        assertEquals("기본: 목록에 보관, 사용자가 고를 때까지 전송 안 함", Queue.HELD, it.state);
        assertEquals(text, it.text);
        assertEquals("DOC_A_123456", it.destination);
        assertEquals("통화 · 통화 녹음 홍길동_251021_101112", it.title);
        // 같은 통화 재공유는 중복
        ShareActivity.Result again = activity.importShared(fileShare(), null);
        assertTrue(again.ok);
        assertTrue(again.duplicate);
        assertEquals(1, q.recent(10).size());
        // 다른 통화의 같은 본문은 별도 항목
        FakeFiles.name = "통화 녹음 홍길동_251022_090000.txt";
        ShareActivity.Result other = activity.importShared(fileShare(), null);
        assertFalse(other.duplicate);
        assertEquals(2, q.recent(10).size());
    }

    @Test
    public void rejectsAudioAndImages() {
        FakeFiles.data = new byte[]{1, 2, 3};
        FakeFiles.type = "audio/mp4";
        FakeFiles.name = "통화 녹음.m4a";
        assertFalse(activity.importShared(fileShare(), null).ok);
        Intent img = new Intent(Intent.ACTION_SEND);
        img.setType("image/jpeg");
        img.putExtra(Intent.EXTRA_STREAM, FILE);
        assertFalse(activity.importShared(img, null).ok);
        // MIME은 text지만 파일명이 녹음
        FakeFiles.type = null;
        FakeFiles.name = "녹음.m4a";
        assertFalse(activity.importShared(fileShare(), null).ok);
        assertTrue(q.recent(10).isEmpty());
    }

    @Test
    public void rejectsEmptyBadEncodingAndOversize() {
        FakeFiles.data = "   \n".getBytes(StandardCharsets.UTF_8);
        assertFalse(activity.importShared(fileShare(), null).ok);
        FakeFiles.data = new byte[]{(byte) 0xC5, (byte) 0xEB};
        assertFalse(activity.importShared(fileShare(), null).ok);
        FakeFiles.data = new byte[Policy.MAX_BYTES + 10];
        java.util.Arrays.fill(FakeFiles.data, (byte) 'a');
        ShareActivity.Result r = activity.importShared(fileShare(), null);
        assertFalse(r.ok);
        assertTrue(r.message.contains("2 MiB"));
        assertTrue(q.recent(10).isEmpty());
    }

    @Test
    public void extraTextWithoutFileName() {
        Intent i = new Intent(Intent.ACTION_SEND);
        i.setType("text/plain");
        i.putExtra(Intent.EXTRA_TEXT, "짧은 녹취");
        ShareActivity.Result r = activity.importShared(i, null);
        assertTrue(r.ok);
        assertTrue(r.message.contains("본문으로 중복 판단"));
        // 자동화 세션 키가 있으면 같은 본문도 통화별로 구분
        ShareActivity.Result r2 = activity.importShared(i, "notif-abc");
        assertFalse(r2.duplicate);
    }

    @Test
    public void withoutDestinationStillImports() {
        State.setDoc(RuntimeEnvironment.getApplication(), null, null);
        State.setHoldShares(RuntimeEnvironment.getApplication(), false);
        Intent i = new Intent(Intent.ACTION_SEND);
        i.setType("text/plain");
        i.putExtra(Intent.EXTRA_TEXT, "문서 설정 전 공유");
        ShareActivity.Result r = activity.importShared(i, null);
        assertTrue(r.ok);
        assertNull(q.find(r.itemId).destination);
        assertTrue(r.message.contains("문서가 아직 설정되지"));
    }

    @Test
    public void immediateModeQueuesForSending() {
        State.setHoldShares(RuntimeEnvironment.getApplication(), false);
        Intent i = new Intent(Intent.ACTION_SEND);
        i.setType("text/plain");
        i.putExtra(Intent.EXTRA_SUBJECT, "통화 녹음 즉시");
        i.putExtra(Intent.EXTRA_TEXT, "바로 전송");
        ShareActivity.Result r = activity.importShared(i, null);
        assertEquals(Queue.PENDING, q.find(r.itemId).state);
    }

    @Test
    public void automationShareIsSentEvenInHoldMode() {
        Intent i = new Intent(Intent.ACTION_SEND);
        i.setType("text/plain");
        i.putExtra(Intent.EXTRA_TEXT, "자동화 공유");
        ShareActivity.Result r = activity.importShared(i, "notif-xyz");
        assertEquals(Queue.PENDING, q.find(r.itemId).state);
    }

    @Test
    public void multipleFilesShare() {
        FakeFiles.data = "여러 파일 중 하나".getBytes(StandardCharsets.UTF_8);
        fileShare(); // 스트림 등록
        Intent i = new Intent(Intent.ACTION_SEND_MULTIPLE);
        i.setType("text/plain");
        java.util.ArrayList<Uri> uris = new java.util.ArrayList<>();
        uris.add(FILE);
        uris.add(FILE);
        i.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris);
        ShareActivity.Result r = activity.importShared(i, null);
        assertTrue(r.message, r.ok);
        assertTrue(r.message, r.message.contains("새로 보관 1") && r.message.contains("이미 있음 1"));
        assertEquals(1, q.recent(10).size());
    }

    @Test
    public void rejectsNonSendAction() {
        Intent i = new Intent(Intent.ACTION_VIEW);
        i.setType("text/plain");
        assertFalse(activity.importShared(i, null).ok);
        assertFalse(activity.importShared(null, null).ok);
    }
}
