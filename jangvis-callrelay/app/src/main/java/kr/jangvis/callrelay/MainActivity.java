package kr.jangvis.callrelay;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.ComponentName;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.View;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONException;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/** 설정·상태 화면. */
public class MainActivity extends Activity {
    private final Handler main = new Handler(Looper.getMainLooper());
    private TextView status, items, diagLog;
    private EditText token, doc;
    private Switch auto, diag;
    private Button save;
    private boolean visible;

    private final CompoundButton.OnCheckedChangeListener autoListener = new CompoundButton.OnCheckedChangeListener() {
        @Override
        public void onCheckedChanged(CompoundButton b, boolean on) {
            if (on && !confirmAutoOn()) return;
            State.setAutoEnabled(MainActivity.this, on);
            if (!on) SamsungAutomation.cancelAll(MainActivity.this, "자동 전송을 껐습니다");
            refresh();
        }
    };

    private final Runnable refresher = new Runnable() {
        @Override
        public void run() {
            refresh();
            if (visible) main.postDelayed(this, 2_000L);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        status = findViewById(R.id.status);
        items = findViewById(R.id.items);
        diagLog = findViewById(R.id.diag_log);
        token = findViewById(R.id.token);
        doc = findViewById(R.id.doc);
        auto = findViewById(R.id.auto);
        diag = findViewById(R.id.diag);
        save = findViewById(R.id.save);
        // 토큰·문서 주소가 자동완성 서비스에 저장되지 않게 한다.
        token.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS);
        doc.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO);

        String d = State.docId(this);
        if (d != null) doc.setText(d);
        if (State.hasToken(this)) token.setHint("저장된 토큰 있음 (바꿀 때만 입력)");
        auto.setChecked(State.autoEnabled(this));
        diag.setChecked(State.diagEnabled(this));

        save.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                saveAndCheck();
            }
        });
        click(R.id.retry, new Runnable() {
            @Override
            public void run() {
                int n = Queue.get(MainActivity.this).retryErrors(System.currentTimeMillis());
                UploadJob.kick(MainActivity.this);
                toast("재시도 대상 " + n + "건 (목적지 문서는 수집 당시 그대로)");
                refresh();
            }
        });
        click(R.id.open_listener, new Runnable() {
            @Override
            public void run() {
                Intent i = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS);
                i.putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        new ComponentName(MainActivity.this, SamsungListener.class).flattenToString());
                try {
                    startActivity(i);
                } catch (RuntimeException e) {
                    startActivity(new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS));
                }
            }
        });
        click(R.id.open_accessibility, new Runnable() {
            @Override
            public void run() {
                startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
            }
        });
        click(R.id.test, new Runnable() {
            @Override
            public void run() {
                confirmTest();
            }
        });
        click(R.id.cancel, new Runnable() {
            @Override
            public void run() {
                SamsungAutomation.cancelAll(MainActivity.this, "사용자가 자동화를 취소함");
                toast("자동화를 취소했습니다.");
            }
        });
        click(R.id.clear_diag, new Runnable() {
            @Override
            public void run() {
                State.clearDiag(MainActivity.this);
                refresh();
            }
        });
        auto.setOnCheckedChangeListener(autoListener);
        diag.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton b, boolean on) {
                State.setDiagEnabled(MainActivity.this, on);
                refresh();
            }
        });

        if (Build.VERSION.SDK_INT >= 33
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1);
        }
        SamsungAutomation.createChannels(this);
        UploadJob.kick(this);
    }

    private void click(int id, final Runnable r) {
        findViewById(id).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                r.run();
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        visible = true;
        main.post(refresher);
    }

    @Override
    protected void onPause() {
        visible = false;
        main.removeCallbacks(refresher);
        super.onPause();
    }

    /** 자동 전송을 켤 때 화면이 열린다는 점을 알린다. 권한이 없으면 켜지 않는다. */
    private boolean confirmAutoOn() {
        if (!SamsungListener.isConnected() || !SamsungAutomation.isEnabled()) {
            setAutoSwitch(false);
            new AlertDialog.Builder(this)
                    .setTitle("권한 필요")
                    .setMessage("자동 전송에는 '알림 접근'과 '접근성' 권한이 모두 필요합니다. 아래 버튼으로 설정을 연 뒤 다시 켜세요.")
                    .setPositiveButton("확인", null)
                    .show();
            return false;
        }
        new AlertDialog.Builder(this)
                .setTitle("자동 전송 안내")
                .setMessage("삼성 통화 녹음의 '텍스트 변환 완료' 알림이 오면 삼성 통화 화면이 앞으로 열리고, "
                        + "더보기 → 공유 → 텍스트 파일 → 장비스 통화 연결을 자동으로 누릅니다.\n\n"
                        + "• 실기기의 실제 메뉴 이름과 맞을 때만 누르고, 다르면 중단합니다.\n"
                        + "• 잠금 중에는 시작하지 않습니다.\n"
                        + "• 실행 중 알림의 '취소'로 멈출 수 있습니다.\n"
                        + "• 가져온 녹취는 Dynalist로 전송됩니다.")
                .setPositiveButton("켜기", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface d, int w) {
                        State.setAutoEnabled(MainActivity.this, true);
                        setAutoSwitch(true);
                        refresh();
                    }
                })
                .setNegativeButton("취소", null)
                .show();
        setAutoSwitch(false);
        return false;
    }

    /** 리스너를 거치지 않고 스위치 표시만 바꾼다. */
    private void setAutoSwitch(boolean on) {
        auto.setOnCheckedChangeListener(null);
        auto.setChecked(on);
        auto.setOnCheckedChangeListener(autoListener);
    }

    private void confirmTest() {
        if (!SamsungListener.isConnected() || !SamsungAutomation.isEnabled()) {
            toast("알림 접근과 접근성 권한을 먼저 허용하세요.");
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle("알림 연결 시험")
                .setMessage("현재 알림창에 있는 삼성 '텍스트 변환 완료' 알림 중 가장 최근 것으로 자동화를 실행합니다.\n\n"
                        + "삼성 통화 화면이 열리고, 성공하면 실제 통화 녹취 텍스트가 Dynalist 문서로 전송됩니다.")
                .setPositiveButton("실행", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface d, int w) {
                        String msg = SamsungListener.runTest(MainActivity.this);
                        new AlertDialog.Builder(MainActivity.this).setMessage(msg).setPositiveButton("확인", null).show();
                    }
                })
                .setNegativeButton("취소", null)
                .show();
    }

    private void saveAndCheck() {
        final String tokenInput = token.getText().toString().trim();
        final String docId = Policy.parseDocId(doc.getText().toString());
        if (docId == null) {
            toast("문서 URL(https://dynalist.io/d/…) 또는 문서 ID 형식이 아닙니다.");
            return;
        }
        if (tokenInput.isEmpty() && !State.hasToken(this)) {
            toast("API 토큰을 입력하세요.");
            return;
        }
        save.setEnabled(false);
        status.setText("연결 확인 중…");
        new Thread(new Runnable() {
            @Override
            public void run() {
                final String msg = check(tokenInput, docId);
                main.post(new Runnable() {
                    @Override
                    public void run() {
                        save.setEnabled(true);
                        token.setText("");
                        if (State.hasToken(MainActivity.this)) token.setHint("저장된 토큰 있음 (바꿀 때만 입력)");
                        new AlertDialog.Builder(MainActivity.this).setTitle("연결 확인")
                                .setMessage(msg).setPositiveButton("확인", null).show();
                        refresh();
                    }
                });
            }
        }, "callrelay-check").start();
    }

    /** 토큰 저장 → doc/read로 문서·루트 노드 확인 → 문서 설정 저장. */
    private String check(String tokenInput, String docId) {
        String tk = tokenInput.isEmpty() ? State.token(this) : tokenInput;
        if (tk == null) return "저장된 토큰을 읽을 수 없습니다. 토큰을 다시 입력하세요.";
        Dynalist.Response r = Dynalist.readDoc(tk, docId);
        String previous = State.docId(this);
        StringBuilder sb = new StringBuilder();
        if (!tokenInput.isEmpty()) {
            if (r.kind == Dynalist.Kind.AUTH) return "토큰이 올바르지 않습니다(" + r.describe() + "). 저장하지 않았습니다.";
            try {
                State.saveToken(this, tokenInput);
                sb.append("토큰을 Keystore로 암호화해 저장했습니다.\n");
            } catch (Exception e) {
                return "토큰 암호화 저장 실패: " + e.getClass().getSimpleName();
            }
        }
        if (r.kind == Dynalist.Kind.OK) {
            try {
                Dynalist.Doc d = Dynalist.parseDoc(r.json);
                State.setDoc(this, docId, d.title);
                sb.append("연결 성공: 문서 '").append(d.title).append("' (노드 ").append(d.nodeCount)
                        .append("개, 루트 노드 ID ").append(d.rootId).append(")\n");
            } catch (JSONException e) {
                return sb + "문서 응답을 해석할 수 없습니다: " + e.getMessage();
            }
        } else if (r.kind == Dynalist.Kind.NOT_FOUND) {
            return sb + "문서를 찾을 수 없습니다(" + r.describe() + "). 문서 ID 대신 노드 ID(#z=…)를 넣지 않았는지 확인하세요.";
        } else if (r.kind == Dynalist.Kind.AUTH) {
            return sb + "토큰 오류: " + r.describe();
        } else {
            // 오프라인 등: 형식이 맞는 문서 ID는 저장해 두고 나중에 전송
            State.setDoc(this, docId, null);
            sb.append("지금은 연결을 확인하지 못했습니다(").append(r.describe())
                    .append("). 설정은 저장했고, 네트워크가 되면 전송합니다.\n");
        }
        long now = System.currentTimeMillis();
        Queue q = Queue.get(this);
        int assigned = q.assignMissingDestination(docId, now);
        if (assigned > 0) sb.append("문서 미지정 항목 ").append(assigned).append("건을 이 문서로 지정했습니다.\n");
        if (previous != null && !previous.equals(docId)) {
            int old = q.countUnsentFor(previous);
            if (old > 0) sb.append("이전 문서의 미전송 ").append(old).append("건은 이전 문서로만 전송됩니다.\n");
        }
        UploadJob.kick(this);
        return sb.toString().trim();
    }

    private void refresh() {
        Queue q = Queue.get(this);
        Map<String, Integer> c = q.counts();
        StringBuilder sb = new StringBuilder();
        String d = State.docId(this);
        sb.append("Dynalist: ").append(State.hasToken(this) ? "토큰 저장됨" : "토큰 없음")
                .append(" · 문서 ").append(d == null ? "미설정" : (State.docTitle(this) == null ? d : State.docTitle(this)))
                .append('\n');
        sb.append("권한: 알림 접근 ").append(SamsungListener.isConnected() ? "켜짐" : "꺼짐")
                .append(" · 접근성 ").append(SamsungAutomation.isEnabled() ? "켜짐" : "꺼짐")
                .append(" · 자동 전송 ").append(State.autoEnabled(this) ? "켜짐" : "꺼짐").append('\n');
        sb.append("대기열: 대기 ").append(c.get(Queue.PENDING))
                .append(" · 전송 중 ").append(c.get(Queue.SENDING))
                .append(" · 완료 ").append(c.get(Queue.SENT))
                .append(" · 오류 ").append(c.get(Queue.ERROR))
                .append(" · 대조 필요 ").append(c.get(Queue.UNCERTAIN)).append('\n');
        int noDest = q.countWithoutDestination();
        if (noDest > 0) sb.append("문서 미지정 ").append(noDest).append("건 – 문서를 설정하면 전송됩니다\n");
        long rate = State.rateBlockedUntil(this);
        if (rate > System.currentTimeMillis()) sb.append("요청 제한으로 ").append(fmt(rate)).append("까지 대기\n");
        if (!TextUtils.isEmpty(State.status(this))) sb.append("전송: ").append(State.status(this)).append('\n');
        String as = State.automationStatus(this);
        if (SamsungAutomation.isRunning()) sb.append("자동화: 진행 중\n");
        else if (!TextUtils.isEmpty(as)) sb.append("자동화: ").append(as).append('\n');
        status.setText(sb.toString().trim());

        StringBuilder il = new StringBuilder();
        List<Queue.Item> list = q.recent(30);
        for (Queue.Item it : list) {
            il.append(fmt(it.created)).append("  ").append(ShareActivity.stateLabel(it.state)).append("  ")
                    .append(it.title).append("  #").append(it.id.substring(0, 8));
            if (it.lastError != null && !Queue.SENT.equals(it.state)) il.append("\n   ↳ ").append(it.lastError);
            il.append('\n');
        }
        items.setText(list.isEmpty() ? "아직 가져온 통화가 없습니다." : il.toString().trim());
        diagLog.setText(State.diagEnabled(this) || !State.diagText(this).isEmpty()
                ? State.diagText(this) : "진단 기록 꺼짐");
    }

    private static String fmt(long t) {
        return new SimpleDateFormat("MM-dd HH:mm", Locale.KOREA).format(new Date(t));
    }

    private void toast(String s) {
        Toast.makeText(this, s, Toast.LENGTH_LONG).show();
    }
}
