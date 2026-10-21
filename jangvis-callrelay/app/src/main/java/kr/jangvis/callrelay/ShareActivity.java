package kr.jangvis.callrelay;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.OpenableColumns;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import java.io.IOException;
import java.io.InputStream;

/**
 * 공유 수신: ACTION_SEND + text/*. EXTRA_STREAM(content://)이 있으면 파일을, 없으면 EXTRA_TEXT를 읽는다.
 * 네트워크 전송 전에 SQLite 대기열에 먼저 저장하고, '가져오기'와 'Dynalist 전송'을 따로 표시한다.
 */
public class ShareActivity extends Activity {
    private final Handler main = new Handler(Looper.getMainLooper());
    private TextView titleView, messageView;
    private Button closeButton;

    /** 가져오기 결과. */
    static final class Result {
        final boolean ok;
        final boolean duplicate;
        final String message;
        final String itemId;

        Result(boolean ok, boolean duplicate, String message, String itemId) {
            this.ok = ok;
            this.duplicate = duplicate;
            this.message = message;
            this.itemId = itemId;
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_share);
        titleView = findViewById(R.id.share_title);
        messageView = findViewById(R.id.share_message);
        closeButton = findViewById(R.id.share_close);
        closeButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });
        titleView.setText("통화 텍스트 가져오는 중…");
        messageView.setText("");
        if (savedInstanceState != null) {
            // 화면 회전 등으로 재생성: 이미 처리했으므로 다시 가져오지 않는다.
            titleView.setText("가져오기 처리 완료");
            return;
        }
        final Intent intent = getIntent();
        final boolean fromAutomation = SamsungAutomation.isWaitingForShare();
        final String automationKey = SamsungAutomation.sessionCallKey();
        new Thread(new Runnable() {
            @Override
            public void run() {
                Result r;
                try {
                    r = importShared(intent, automationKey);
                } catch (RuntimeException e) {
                    r = new Result(false, false, "가져오기 실패: " + e.getClass().getSimpleName(), null);
                }
                final Result fr = r;
                main.post(new Runnable() {
                    @Override
                    public void run() {
                        show(fr, fromAutomation);
                    }
                });
            }
        }, "callrelay-import").start();
    }

    private void show(Result r, boolean fromAutomation) {
        if (isFinishing() || isDestroyed()) return;
        titleView.setText(r.ok ? (r.duplicate ? "이미 가져온 통화" : "가져오기 성공") : "가져오기 실패");
        messageView.setText(r.message);
        if (fromAutomation) SamsungAutomation.onShareImported(r.ok, r.message);
        if (r.ok) {
            main.postDelayed(new Runnable() {
                @Override
                public void run() {
                    if (!isFinishing()) finish();
                }
            }, fromAutomation ? 1_500L : 3_500L);
        }
    }

    Result importShared(Intent intent, String automationKey) {
        if (intent == null || !Intent.ACTION_SEND.equals(intent.getAction())) {
            return new Result(false, false, "지원하지 않는 공유 방식입니다.", null);
        }
        String type = intent.getType();
        if (!Policy.isTextMime(type)) {
            return new Result(false, false, "텍스트(text/*)만 받습니다. 받은 형식: " + type, null);
        }
        Uri stream = streamExtra(intent);
        CharSequence extraText = intent.getCharSequenceExtra(Intent.EXTRA_TEXT);
        String displayName = null;
        Policy.Decoded decoded;
        if (stream != null) {
            if (!ContentResolver.SCHEME_CONTENT.equals(stream.getScheme())) {
                return new Result(false, false, "content:// 형식의 파일만 받습니다.", null);
            }
            ContentResolver cr = getContentResolver();
            String streamType = cr.getType(stream);
            displayName = queryName(cr, stream);
            if (streamType != null && !Policy.isTextMime(streamType)) {
                return new Result(false, false, "텍스트 파일이 아닙니다(" + streamType + "). 녹음·이미지는 받지 않습니다.", null);
            }
            if (Policy.looksNonText(displayName)) {
                return new Result(false, false, "텍스트 파일이 아닙니다(파일 확장자). 녹음·이미지는 받지 않습니다.", null);
            }
            decoded = readStream(cr, stream);
        } else if (extraText != null) {
            decoded = Policy.checkText(extraText);
        } else {
            return new Result(false, false, "공유된 텍스트가 없습니다.", null);
        }
        if (!decoded.ok()) return new Result(false, false, decoded.error, null);

        String callKey = displayName;
        if (callKey == null || callKey.trim().isEmpty()) callKey = intent.getStringExtra(Intent.EXTRA_SUBJECT);
        if (callKey == null || callKey.trim().isEmpty()) callKey = intent.getStringExtra(Intent.EXTRA_TITLE);
        if ((callKey == null || callKey.trim().isEmpty()) && automationKey != null) callKey = automationKey;
        String normKey = Policy.normalizeCallKey(callKey);

        long now = System.currentTimeMillis();
        String id = Policy.itemId(normKey, decoded.text);
        String titleName = displayName != null ? displayName : intent.getStringExtra(Intent.EXTRA_SUBJECT);
        String title = Policy.title(titleName, now);
        String dest = State.docId(this);
        String source = automationKey != null ? "automation" : "share";
        Queue q = Queue.get(this);
        Queue.InsertResult ir = q.insert(id, title, decoded.text, normKey, dest, source, now);
        if (ir == Queue.InsertResult.DUPLICATE) {
            Queue.Item existing = q.find(id);
            String st = existing == null ? "?" : stateLabel(existing.state);
            UploadJob.kick(this);
            return new Result(true, true, "같은 통화가 이미 대기열에 있습니다(상태: " + st + "). 다시 보내지 않습니다.", id);
        }
        UploadJob.kick(this);
        int chars = decoded.text.codePointCount(0, decoded.text.length());
        StringBuilder m = new StringBuilder();
        m.append(title).append("\n").append(chars).append("자를 휴대폰 대기열에 저장했습니다.\n");
        if (dest == null) {
            m.append("Dynalist 문서가 아직 설정되지 않아 전송 대기 중입니다. 앱 설정에서 문서를 지정하세요.");
        } else if (!State.hasToken(this)) {
            m.append("Dynalist 토큰이 없어 전송 대기 중입니다.");
        } else {
            m.append("Dynalist 전송은 백그라운드에서 진행되며, 결과는 앱 화면에서 확인할 수 있습니다.");
        }
        if (normKey.isEmpty()) {
            m.append("\n(파일명 정보가 없어 본문만으로 중복을 판단합니다.)");
        }
        return new Result(true, false, m.toString(), id);
    }

    @SuppressWarnings("deprecation")
    private static Uri streamExtra(Intent intent) {
        if (android.os.Build.VERSION.SDK_INT >= 33) return intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri.class);
        Object o = intent.getParcelableExtra(Intent.EXTRA_STREAM);
        return o instanceof Uri ? (Uri) o : null;
    }

    static String stateLabel(String s) {
        if (Queue.PENDING.equals(s)) return "전송 대기";
        if (Queue.SENDING.equals(s)) return "전송 중";
        if (Queue.SENT.equals(s)) return "Dynalist 전송 완료";
        if (Queue.ERROR.equals(s)) return "오류";
        if (Queue.UNCERTAIN.equals(s)) return "서버 대조 필요";
        return s;
    }

    private static String queryName(ContentResolver cr, Uri uri) {
        try (Cursor c = cr.query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (c != null && c.moveToFirst() && !c.isNull(0)) return c.getString(0);
        } catch (RuntimeException ignored) {
            // 이름을 못 얻어도 본문은 읽는다
        }
        return null;
    }

    private static Policy.Decoded readStream(ContentResolver cr, Uri uri) {
        byte[] buf = new byte[Policy.MAX_BYTES + 1];
        int total = 0;
        try (InputStream in = cr.openInputStream(uri)) {
            if (in == null) return Policy.checkText(null);
            int n;
            while (total < buf.length && (n = in.read(buf, total, buf.length - total)) > 0) total += n;
        } catch (IOException | SecurityException e) {
            return failure("파일을 읽을 수 없습니다(" + e.getClass().getSimpleName() + ").");
        }
        if (total > Policy.MAX_BYTES) return failure("파일이 2 MiB를 넘습니다.");
        return Policy.decode(buf, total);
    }

    private static Policy.Decoded failure(String msg) {
        return Policy.Decoded.failure(msg);
    }
}
