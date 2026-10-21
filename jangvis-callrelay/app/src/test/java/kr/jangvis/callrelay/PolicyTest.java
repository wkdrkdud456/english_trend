package kr.jangvis.callrelay;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/** Android 없이 도는 정책 검사. */
public class PolicyTest {
    private static Policy.Decoded dec(byte[] b) {
        return Policy.decode(b, b.length);
    }

    private static byte[] cat(byte[] a, byte[] b) {
        byte[] r = Arrays.copyOf(a, a.length + b.length);
        System.arraycopy(b, 0, r, a.length, b.length);
        return r;
    }

    private static final String SAMPLE = "화자 1: 여보세요\n화자 2: 네, 장비 점검 건입니다.";

    @Test
    public void utf8WithAndWithoutBom() {
        byte[] u = SAMPLE.getBytes(StandardCharsets.UTF_8);
        assertEquals(SAMPLE, dec(u).text);
        assertEquals(SAMPLE, dec(cat(new byte[]{(byte) 0xEF, (byte) 0xBB, (byte) 0xBF}, u)).text);
    }

    @Test
    public void utf16WithBom() {
        assertEquals(SAMPLE, dec(cat(new byte[]{(byte) 0xFF, (byte) 0xFE}, SAMPLE.getBytes(StandardCharsets.UTF_16LE))).text);
        assertEquals(SAMPLE, dec(cat(new byte[]{(byte) 0xFE, (byte) 0xFF}, SAMPLE.getBytes(StandardCharsets.UTF_16BE))).text);
    }

    @Test
    public void invalidEncodingRejected() {
        // EUC-KR 바이트는 UTF-8로 잘못된 순서
        byte[] euckr = {(byte) 0xC5, (byte) 0xEB, (byte) 0xC8, (byte) 0xAD};
        Policy.Decoded d = dec(euckr);
        assertFalse(d.ok());
        assertTrue(d.error.contains("인코딩"));
        // BOM 없는 UTF-16은 NUL 바이트 때문에 텍스트가 아님
        assertFalse(dec("abc".getBytes(StandardCharsets.UTF_16LE)).ok());
        // UTF-16 BOM 뒤 홀수 바이트
        assertFalse(dec(new byte[]{(byte) 0xFF, (byte) 0xFE, 0x41}).ok());
        // UTF-32 BOM
        assertFalse(dec(new byte[]{(byte) 0xFF, (byte) 0xFE, 0, 0, 0x41, 0, 0, 0}).ok());
    }

    @Test
    public void emptyAndWhitespaceRejected() {
        assertFalse(dec(new byte[0]).ok());
        assertFalse(dec(" \n\t\r\n".getBytes(StandardCharsets.UTF_8)).ok());
        assertFalse(dec(new byte[]{(byte) 0xEF, (byte) 0xBB, (byte) 0xBF}).ok());
        assertFalse(Policy.checkText(null).ok());
    }

    @Test
    public void sizeLimits() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < Policy.MAX_CHARS; i++) sb.append('가');
        assertTrue(Policy.checkText(sb).ok());
        sb.append('가');
        assertFalse(Policy.checkText(sb).ok());
        // 2 MiB 초과 파일
        byte[] big = new byte[Policy.MAX_BYTES + 1];
        Arrays.fill(big, (byte) 'a');
        assertFalse(dec(big).ok());
        // 서로게이트 쌍(이모지)은 한 글자로 센다
        StringBuilder em = new StringBuilder();
        for (int i = 0; i < Policy.MAX_CHARS; i++) em.append("😀");
        // 200,000자 이모지 = 800,000 바이트 → 허용
        assertTrue(Policy.checkText(em).ok());
    }

    @Test
    public void normalizesLineEndings() {
        Policy.Decoded d = Policy.checkText("\r\n\r\n첫 줄\r\n  둘째 줄  \r\n\r\n");
        assertEquals("첫 줄\n  둘째 줄", d.text);
    }

    @Test
    public void mimeAndExtension() {
        assertTrue(Policy.isTextMime("text/plain"));
        assertTrue(Policy.isTextMime("text/plain; charset=utf-8"));
        assertTrue(Policy.isTextMime("TEXT/Markdown"));
        assertFalse(Policy.isTextMime("text/"));
        assertFalse(Policy.isTextMime("audio/mp4"));
        assertFalse(Policy.isTextMime("image/jpeg"));
        assertFalse(Policy.isTextMime("application/octet-stream"));
        assertFalse(Policy.isTextMime(null));
        assertTrue(Policy.looksNonText("통화 녹음 홍길동_251021.m4a"));
        assertTrue(Policy.looksNonText("photo.JPG"));
        assertFalse(Policy.looksNonText("통화 녹음 홍길동_251021.txt"));
        assertFalse(Policy.looksNonText(null));
    }

    @Test
    public void itemIdStableAndDistinct() {
        String a = Policy.itemId("통화 녹음 홍길동_251021_101112.txt", SAMPLE);
        assertEquals(Policy.ID_HEX, a.length());
        assertTrue(Policy.isItemId(a));
        // 같은 통화 재공유(복사본 번호·대소문자·확장자 차이)는 같은 ID
        assertEquals(a, Policy.itemId("통화 녹음 홍길동_251021_101112 (1).TXT", SAMPLE));
        // 다른 통화의 같은 문장은 다른 ID
        assertNotEquals(a, Policy.itemId("통화 녹음 홍길동_251022_090000.txt", SAMPLE));
        // 같은 통화라도 본문이 바뀌면 다른 ID
        assertNotEquals(a, Policy.itemId("통화 녹음 홍길동_251021_101112.txt", SAMPLE + "!"));
        // 키 경계 혼동 방지: ("ab","c…") 와 ("a","bc…")
        assertNotEquals(Policy.itemId("ab", "c"), Policy.itemId("a", "bc"));
    }

    @Test
    public void markerRoundTrip() {
        String id = Policy.itemId("k", "t");
        String note = Policy.note("본문", id);
        assertTrue(note.endsWith("[장비스 통화 #" + id + "]"));
        assertEquals(id, Policy.findMarkerId(note));
        assertNull(Policy.findMarkerId("[장비스 통화 #xyz]"));
        assertNull(Policy.findMarkerId(null));
    }

    @Test
    public void docIdParsing() {
        assertEquals("AbCdEf123456_-x", Policy.parseDocId("https://dynalist.io/d/AbCdEf123456_-x"));
        // #z= 뒤는 노드 ID → 버림
        assertEquals("AbCdEf123456", Policy.parseDocId("https://dynalist.io/d/AbCdEf123456#z=nodeXYZ123"));
        assertEquals("AbCdEf123456", Policy.parseDocId("  AbCdEf123456 "));
        assertNull(Policy.parseDocId("http://dynalist.io/d/AbCdEf123456"));
        assertNull(Policy.parseDocId("https://evil.example/d/AbCdEf123456"));
        assertNull(Policy.parseDocId("https://dynalist.io.evil.example/d/AbCdEf123456"));
        assertNull(Policy.parseDocId("short"));
        assertNull(Policy.parseDocId(""));
        assertNull(Policy.parseDocId(null));
    }

    @Test
    public void titles() {
        assertEquals("통화 · 통화 녹음 홍길동_251021", Policy.title("통화 녹음 홍길동_251021.txt", 0));
        assertTrue(Policy.title(null, 0).startsWith("통화 · 19"));
    }

    @Test
    public void notificationClassification() {
        assertEquals(Policy.NotificationKind.TRANSCRIPT_DONE, Policy.classify("통화 녹음", "텍스트 변환 완료", false, false));
        assertEquals(Policy.NotificationKind.TRANSCRIPT_DONE, Policy.classify("홍길동", "텍스트로 변환되었습니다", false, false));
        assertEquals(Policy.NotificationKind.TRANSCRIPT_DONE, Policy.classify("Call recording", "Transcript ready", false, false));
        assertEquals(Policy.NotificationKind.RECORDING_DONE, Policy.classify("통화 녹음", "녹음이 저장되었습니다", false, false));
        assertEquals(Policy.NotificationKind.IN_PROGRESS, Policy.classify("통화 녹음", "텍스트로 변환 중…", false, false));
        assertEquals(Policy.NotificationKind.IN_PROGRESS, Policy.classify("통화 녹음", "텍스트 변환 완료", true, false));
        assertEquals(Policy.NotificationKind.IN_PROGRESS, Policy.classify("통화 녹음", "텍스트 변환 완료", false, true));
        assertEquals(Policy.NotificationKind.FAILED, Policy.classify("통화 녹음", "텍스트 변환 실패", false, false));
        assertEquals(Policy.NotificationKind.FAILED, Policy.classify("통화 녹음", "변환 오류가 발생했습니다", false, false));
        assertEquals(Policy.NotificationKind.OTHER, Policy.classify("통화 녹음 완료", "텍스트로 변환할 수 있습니다", false, false));
        assertEquals(Policy.NotificationKind.OTHER, Policy.classify("부재중 전화", "홍길동", false, false));
        assertEquals(Policy.NotificationKind.OTHER, Policy.classify(null, null, false, false));
        // S25 Ultra 실기기 알림(2026-10-21 화면)
        assertEquals(Policy.NotificationKind.TRANSCRIPT_DONE, Policy.classify("통화 녹음 완료",
                "통화 녹음이 저장되고 텍스트로 변환되었습니다. 통화 내용을 간략히 보려면 요약을 누르세요.", false, false));
        assertTrue(Policy.isSamsungSource("com.samsung.android.incallui"));
        // 원본 프로토타입 검사 사례
        assertEquals(Policy.NotificationKind.TRANSCRIPT_DONE, Policy.classify("통화", "텍스트 변환 완료", false, false));
        assertEquals(Policy.NotificationKind.TRANSCRIPT_DONE, Policy.classify("Call", "Transcription complete", false, false));
        assertEquals(Policy.NotificationKind.FAILED, Policy.classify("통화", "텍스트 변환이 완료되지 않았습니다", false, false));
        assertEquals(Policy.NotificationKind.IN_PROGRESS, Policy.classify("통화", "텍스트 변환 중", false, false));
        assertEquals(Policy.NotificationKind.FAILED, Policy.classify("Call", "Transcription incomplete", false, false));
        assertEquals(Policy.NotificationKind.FAILED, Policy.classify("Call", "Transcript not ready", false, false));
        // 원본은 이 문구를 '완료'로 오판했다(변환 중 + 녹음 완료)
        assertEquals(Policy.NotificationKind.IN_PROGRESS, Policy.classify("녹음 완료", "텍스트 변환 중", false, false));
    }

    @Test
    public void skeletonHidesContent() {
        String s = Policy.skeleton("홍길동 010-1234-5678 통화 텍스트 변환 완료");
        assertFalse(s.contains("홍길동"));
        assertFalse(s.contains("1234"));
        assertTrue(s.contains("텍스트"));
        assertTrue(s.contains("완료"));
        assertTrue(s.contains("▢3"));
    }

    @Test
    public void labelsMatchExactlyOnly() {
        assertTrue(Policy.labelMatches("공유", Policy.SHARE_LABELS));
        assertTrue(Policy.labelMatches(" 텍스트  파일 ", Policy.TEXT_FILE_LABELS));
        assertTrue(Policy.labelMatches("more options", Policy.MORE_LABELS));
        assertFalse(Policy.labelMatches("공유된 문서를 확인", Policy.SHARE_LABELS));
        assertFalse(Policy.labelMatches("녹음 파일", Policy.TEXT_FILE_LABELS));
        assertFalse(Policy.labelMatches("", Policy.SHARE_LABELS));
        assertFalse(Policy.labelMatches(null, Policy.SHARE_LABELS));
        assertTrue(Policy.labelMatches("한 번만", Policy.JUST_ONCE_LABELS));
        assertFalse("'항상'은 누르지 않음", Policy.labelMatches("항상", Policy.JUST_ONCE_LABELS));
    }

    @Test
    public void sourcesAllowList() {
        assertTrue(Policy.isSamsungSource("com.samsung.android.dialer"));
        assertTrue(Policy.isSamsungSource("com.sec.android.app.voicenote"));
        assertFalse(Policy.isSamsungSource("com.samsung.android.messaging"));
        assertFalse(Policy.isSamsungSource(null));
        assertFalse(Policy.isShareSheet("com.kakao.talk"));
    }

    @Test
    public void backoffGrowsAndCaps() {
        assertEquals(30_000L, Policy.backoffMillis(0));
        assertEquals(60_000L, Policy.backoffMillis(1));
        assertEquals(30 * 60_000L, Policy.backoffMillis(20));
        assertEquals(30_000L, Policy.backoffMillis(-3));
    }
}
