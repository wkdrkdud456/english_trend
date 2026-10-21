package kr.jangvis.callrelay;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.provider.DocumentsContract;
import android.provider.OpenableColumns;

import java.io.IOException;
import java.io.InputStream;

/**
 * 텍스트를 검사해 대기열에 넣는 공통 처리(공유·파일 선택·폴더 불러오기).
 * hold=true면 '보관' 상태로 넣어 사용자가 목록에서 고를 때까지 전송하지 않는다.
 */
final class Importer {
    private Importer() {}

    /** 폴더 불러오기 상한(한 번에 읽는 파일 수). */
    static final int FOLDER_MAX_FILES = 300;

    static final class Outcome {
        final boolean ok;
        final boolean duplicate;
        final String message;
        final String id;

        Outcome(boolean ok, boolean duplicate, String message, String id) {
            this.ok = ok;
            this.duplicate = duplicate;
            this.message = message;
            this.id = id;
        }

        static Outcome fail(String m) {
            return new Outcome(false, false, m, null);
        }
    }

    /** content:// 파일 한 개를 읽어 넣는다. typeHint는 공유 인텐트가 알려준 형식(없으면 null). */
    static Outcome importFile(Context c, Uri uri, String typeHint, String extraKey, String source, boolean hold) {
        if (uri == null || !ContentResolver.SCHEME_CONTENT.equals(uri.getScheme())) {
            return Outcome.fail("content:// 형식의 파일만 받습니다.");
        }
        ContentResolver cr = c.getContentResolver();
        String streamType = cr.getType(uri);
        if (streamType == null) streamType = typeHint;
        String displayName = queryName(cr, uri);
        if (streamType != null && !Policy.isTextMime(streamType)
                && !(displayName != null && displayName.toLowerCase(java.util.Locale.ROOT).endsWith(".txt"))) {
            return Outcome.fail("텍스트 파일이 아닙니다(" + streamType + "). 녹음·이미지는 받지 않습니다.");
        }
        if (Policy.looksNonText(displayName)) {
            return Outcome.fail("텍스트 파일이 아닙니다(파일 확장자). 녹음·이미지는 받지 않습니다.");
        }
        Policy.Decoded d = readStream(cr, uri);
        if (!d.ok()) return Outcome.fail((displayName == null ? "" : displayName + ": ") + d.error);
        String key = displayName;
        if (key == null || key.trim().isEmpty()) key = extraKey;
        return insert(c, d.text, key, displayName, source, hold);
    }

    /** 이미 검사된 본문을 넣는다. */
    static Outcome insert(Context c, String text, String callKey, String displayName, String source, boolean hold) {
        String normKey = Policy.normalizeCallKey(callKey);
        long now = System.currentTimeMillis();
        String id = Policy.itemId(normKey, text);
        String title = Policy.title(displayName != null ? displayName : callKey, now);
        String dest = State.docId(c);
        Queue q = Queue.get(c);
        Queue.InsertResult ir = q.insert(id, title, text, normKey, dest, source, now,
                hold ? Queue.HELD : Queue.PENDING);
        if (ir == Queue.InsertResult.DUPLICATE) {
            Queue.Item existing = q.find(id);
            String st = existing == null ? "?" : ShareActivity.stateLabel(existing.state);
            return new Outcome(true, true, title + " – 이미 있음(" + st + ")", id);
        }
        if (!hold) UploadJob.kick(c);
        int chars = text.codePointCount(0, text.length());
        String m = title + " – " + chars + "자 " + (hold ? "목록에 보관" : "전송 대기열에 저장");
        if (normKey.isEmpty()) m += " (파일명 없음: 본문으로 중복 판단)";
        return new Outcome(true, false, m, id);
    }

    /** 폴더 불러오기 결과. */
    static final class FolderResult {
        int added, duplicates, failed, files;
        boolean truncated;
        String error;

        String describe() {
            if (error != null) return error;
            String s = "텍스트 파일 " + files + "개 확인 · 새로 보관 " + added + " · 이미 있음 " + duplicates;
            if (failed > 0) s += " · 읽기 실패 " + failed;
            if (truncated) s += " (" + FOLDER_MAX_FILES + "개까지만 확인)";
            return s;
        }
    }

    /** 사용자가 연결한 폴더(및 2단계 하위 폴더)의 .txt/텍스트 파일을 모두 '보관'으로 불러온다. */
    static FolderResult importFolder(Context c, Uri tree) {
        FolderResult r = new FolderResult();
        try {
            String rootDoc = DocumentsContract.getTreeDocumentId(tree);
            walk(c, tree, rootDoc, 0, r);
        } catch (RuntimeException e) {
            r.error = "폴더를 읽을 수 없습니다(" + e.getClass().getSimpleName() + "). 폴더를 다시 연결하세요.";
        }
        return r;
    }

    private static void walk(Context c, Uri tree, String docId, int depth, FolderResult r) {
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId);
        String[] cols = {DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_SIZE};
        try (Cursor cur = c.getContentResolver().query(children, cols, null, null, null)) {
            if (cur == null) return;
            while (cur.moveToNext()) {
                if (r.files >= FOLDER_MAX_FILES) {
                    r.truncated = true;
                    return;
                }
                String id = cur.getString(0);
                String name = cur.getString(1);
                String mime = cur.getString(2);
                long size = cur.isNull(3) ? 0 : cur.getLong(3);
                if (DocumentsContract.Document.MIME_TYPE_DIR.equals(mime)) {
                    if (depth < 2) walk(c, tree, id, depth + 1, r);
                    continue;
                }
                boolean txt = name != null && name.toLowerCase(java.util.Locale.ROOT).endsWith(".txt");
                if (!txt && !Policy.isTextMime(mime)) continue;
                r.files++;
                if (size > Policy.MAX_BYTES) {
                    r.failed++;
                    continue;
                }
                Outcome o = importFile(c, DocumentsContract.buildDocumentUriUsingTree(tree, id), mime, null, "folder", true);
                if (!o.ok) r.failed++;
                else if (o.duplicate) r.duplicates++;
                else r.added++;
            }
        }
    }

    static String queryName(ContentResolver cr, Uri uri) {
        try (Cursor c = cr.query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (c != null && c.moveToFirst() && !c.isNull(0)) return c.getString(0);
        } catch (RuntimeException ignored) {
            // 이름을 못 얻어도 본문은 읽는다
        }
        return null;
    }

    static Policy.Decoded readStream(ContentResolver cr, Uri uri) {
        byte[] buf = new byte[Policy.MAX_BYTES + 1];
        int total = 0;
        try (InputStream in = cr.openInputStream(uri)) {
            if (in == null) return Policy.checkText(null);
            int n;
            while (total < buf.length && (n = in.read(buf, total, buf.length - total)) > 0) total += n;
        } catch (IOException | SecurityException e) {
            return Policy.Decoded.failure("파일을 읽을 수 없습니다(" + e.getClass().getSimpleName() + ").");
        }
        if (total > Policy.MAX_BYTES) return Policy.Decoded.failure("파일이 2 MiB를 넘습니다.");
        return Policy.decode(buf, total);
    }
}
