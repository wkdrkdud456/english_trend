package kr.jangvis.callrelay;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

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
        if (intent == null) return new Result(false, false, "지원하지 않는 공유 방식입니다.", null);
        String action = intent.getAction();
        boolean multiple = Intent.ACTION_SEND_MULTIPLE.equals(action);
        if (!Intent.ACTION_SEND.equals(action) && !multiple) {
            return new Result(false, false, "지원하지 않는 공유 방식입니다.", null);
        }
        String type = intent.getType();
        if (!Policy.isTextMime(type)) {
            return new Result(false, false, "텍스트(text/*)만 받습니다. 받은 형식: " + type, null);
        }
        // 자동화로 들어온 공유는 바로 전송, 사람이 공유한 것은 설정에 따라 목록에 보관(기본)
        boolean hold = automationKey == null && State.holdShares(this);
        String source = automationKey != null ? "automation" : "share";
        String subjectKey = intent.getStringExtra(Intent.EXTRA_SUBJECT);
        if (subjectKey == null || subjectKey.trim().isEmpty()) subjectKey = intent.getStringExtra(Intent.EXTRA_TITLE);
        if ((subjectKey == null || subjectKey.trim().isEmpty()) && automationKey != null) subjectKey = automationKey;

        if (multiple) {
            List<Uri> uris = streamList(intent);
            if (uris.isEmpty()) return new Result(false, false, "공유된 파일이 없습니다.", null);
            int ok = 0, dup = 0, fail = 0;
            StringBuilder failures = new StringBuilder();
            for (Uri u : uris) {
                Importer.Outcome o = Importer.importFile(this, u, type, null, source, hold);
                if (!o.ok) {
                    fail++;
                    if (failures.length() < 400) failures.append("\n• ").append(o.message);
                } else if (o.duplicate) dup++;
                else ok++;
            }
            String m = "파일 " + uris.size() + "개: 새로 " + (hold ? "보관 " : "저장 ") + ok + " · 이미 있음 " + dup
                    + (fail > 0 ? " · 실패 " + fail + failures : "") + (hold ? "\n앱의 '통화 목록'에서 골라 전송하세요." : "");
            return new Result(ok + dup > 0, ok == 0 && dup > 0, m, null);
        }

        Uri stream = streamExtra(intent);
        Importer.Outcome o;
        if (stream != null) {
            o = Importer.importFile(this, stream, type, subjectKey, source, hold);
        } else {
            CharSequence extraText = intent.getCharSequenceExtra(Intent.EXTRA_TEXT);
            if (extraText == null) return new Result(false, false, "공유된 텍스트가 없습니다.", null);
            Policy.Decoded d = Policy.checkText(extraText);
            if (!d.ok()) return new Result(false, false, d.error, null);
            o = Importer.insert(this, d.text, subjectKey, intent.getStringExtra(Intent.EXTRA_SUBJECT), source, hold);
        }
        if (!o.ok) return new Result(false, false, o.message, null);
        if (o.duplicate) return new Result(true, true, o.message + ". 다시 보내지 않습니다.", o.id);
        StringBuilder m = new StringBuilder(o.message).append("\n");
        if (hold) {
            m.append("앱의 '통화 목록'에서 골라 전송하세요.");
        } else if (State.docId(this) == null) {
            m.append("Dynalist 문서가 아직 설정되지 않아 전송 대기 중입니다.");
        } else if (!State.hasToken(this)) {
            m.append("Dynalist 토큰이 없어 전송 대기 중입니다.");
        } else {
            m.append("Dynalist 전송은 백그라운드에서 진행됩니다.");
        }
        return new Result(true, false, m.toString(), o.id);
    }

    @SuppressWarnings("deprecation")
    private static List<Uri> streamList(Intent intent) {
        List<Uri> out = new ArrayList<>();
        List<?> l;
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            l = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri.class);
        } else {
            l = intent.<android.os.Parcelable>getParcelableArrayListExtra(Intent.EXTRA_STREAM);
        }
        if (l != null) for (Object o : l) if (o instanceof Uri) out.add((Uri) o);
        return out;
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
        if (Queue.HELD.equals(s)) return "보관(미전송)";
        if (Queue.DISMISSED.equals(s)) return "숨김";
        return s;
    }
}
