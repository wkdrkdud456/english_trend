package kr.jangvis.callrelay;

import android.accessibilityservice.AccessibilityService;
import android.app.ActivityOptions;
import android.app.KeyguardManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.os.SystemClock;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/**
 * 제한된 화면 자동화: 완료 알림의 contentIntent로 삼성 통화 화면을 연 뒤
 * 더보기 → 공유 → 텍스트 파일 → 장비스 통화 연결 순서로 '라벨이 정확히 일치하는' 노드만 누른다.
 *
 * - 좌표 클릭 없음. 라벨을 못 찾으면 중단하고 이유를 남긴다.
 * - 삼성 앱과 공유 화면 후보 패키지에서만 동작. 다른 앱이 앞에 오면 중단.
 * - 잠금 중에는 시작하지 않고 잠금 해제(USER_PRESENT)를 기다린다. 잠금을 풀거나 우회하지 않는다.
 * - 45초 / 동작 10회 상한, 알림의 '취소'와 앱 화면에서 취소 가능.
 * 모든 상태는 메인 스레드에서만 바꾼다.
 */
public class SamsungAutomation extends AccessibilityService {
    private static final String CH_PROGRESS = "automation";
    private static final String CH_RESULT = "automation_result";
    private static final int NOTIF_PROGRESS = 41;
    private static final int NOTIF_RESULT = 42;
    private static final long TICK_MS = 400L;
    private static final long TASK_EXPIRY_MS = 30 * 60_000L;
    private static final long IMPORT_TIMEOUT_MS = 10_000L;
    private static final int MAX_QUEUE = 10;
    private static final String SYSTEM_UI = "com.android.systemui";

    private static final Handler main = new Handler(Looper.getMainLooper());
    private static final ArrayDeque<Task> tasks = new ArrayDeque<>();
    private static SamsungAutomation service;
    private static Task current;

    private BroadcastReceiver unlockReceiver;

    enum Step { OPENING, MORE_OR_SHARE, SHARE, TEXT_FILE, TARGET, WAIT_IMPORT }

    static final class Task {
        String key, signature, pkg;
        /** 알림 제목(예: '통화 녹음 완료'). 알림창에서 같은 제목의 알림을 찾을 때만 쓰고 저장·기록하지 않는다. */
        String title;
        PendingIntent intent;
        boolean test;
        long enqueuedAt;
        // 실행 상태
        Step step;
        long startedAt, stepStartedAt, lastScrollAt;
        int actions, lockRetries;
        long shadeAt;
        boolean shadeClicked;
    }

    // ---------------------------------------------------------------- 외부 진입점

    /** 완료 알림 → 작업 추가. 같은 서명은 한 번만. */
    static void enqueue(final Context c, final String key, final String sig, final String pkg, final String title,
                        final PendingIntent pi, final boolean test) {
        main.post(new Runnable() {
            @Override
            public void run() {
                if (current != null && sig.equals(current.signature)) return;
                for (Task t : tasks) if (t.signature.equals(sig)) return;
                Task t = new Task();
                t.key = key;
                t.signature = sig;
                t.title = title;
                t.pkg = pkg;
                t.intent = pi;
                t.test = test;
                t.enqueuedAt = SystemClock.elapsedRealtime();
                tasks.addLast(t);
                while (tasks.size() > MAX_QUEUE) tasks.removeFirst();
                State.setAutomationStatus(c, "완료 알림 감지 – 자동화 대기 " + tasks.size() + "건");
                tryStart(c);
            }
        });
    }

    /** 알림이 지워지면 아직 시작하지 않은 작업은 버린다(실행 중인 작업은 계속). */
    static void onNotificationRemoved(final String key) {
        main.post(new Runnable() {
            @Override
            public void run() {
                Iterator<Task> it = tasks.iterator();
                while (it.hasNext()) if (it.next().key.equals(key)) it.remove();
            }
        });
    }

    /** 사용자 취소: 진행 중 작업과 대기 작업 모두 중단. */
    static void cancelAll(final Context c, final String why) {
        main.post(new Runnable() {
            @Override
            public void run() {
                tasks.clear();
                if (current != null) abort(c, why, false);
                else State.setAutomationStatus(c, why);
            }
        });
    }

    /** ShareActivity가 메인 스레드에서 호출: 자동화가 공유 화면 단계에 있는지. */
    static boolean isWaitingForShare() {
        return current != null && (current.step == Step.TARGET || current.step == Step.WAIT_IMPORT
                || current.step == Step.TEXT_FILE);
    }

    /** 파일명이 없을 때 쓰는 통화 식별 키(알림 서명). */
    static String sessionCallKey() {
        return isWaitingForShare() ? "notif-" + current.signature : null;
    }

    static void onShareImported(final boolean ok, final String message) {
        main.post(new Runnable() {
            @Override
            public void run() {
                Task t = current;
                SamsungAutomation s = service;
                if (t == null || s == null) return;
                if (ok) finishSuccess(s, t);
                else abort(s, "가져오기 실패: " + message, false);
            }
        });
    }

    static boolean isRunning() {
        return current != null;
    }

    static int queuedCount() {
        return tasks.size();
    }

    static boolean isEnabled() {
        return service != null;
    }

    // ---------------------------------------------------------------- 서비스 생명주기

    @Override
    protected void onServiceConnected() {
        service = this;
        createChannels(this);
        unlockReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                tryStart(context);
            }
        };
        IntentFilter f = new IntentFilter(Intent.ACTION_USER_PRESENT);
        // USER_PRESENT는 시스템 방송이라 NOT_EXPORTED여도 수신된다(API 33 미만에서는 플래그 무시).
        registerReceiver(unlockReceiver, f, Context.RECEIVER_NOT_EXPORTED);
        tryStart(this);
    }

    @Override
    public boolean onUnbind(Intent intent) {
        cleanup();
        return super.onUnbind(intent);
    }

    @Override
    public void onDestroy() {
        cleanup();
        super.onDestroy();
    }

    private void cleanup() {
        if (unlockReceiver != null) {
            try {
                unregisterReceiver(unlockReceiver);
            } catch (IllegalArgumentException ignored) {
                // 이미 해제됨
            }
            unlockReceiver = null;
        }
        if (service == this) {
            if (current != null) abort(this, "접근성 서비스가 꺼져 중단", false);
            service = null;
        }
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        // 화면 변화가 오면 다음 확인을 앞당긴다. 이벤트 내용(본문)은 저장하지 않는다.
        if (current != null) {
            main.removeCallbacks(TICK);
            main.postDelayed(TICK, 150);
        }
    }

    @Override
    public void onInterrupt() {
        // 피드백 없음
    }

    // ---------------------------------------------------------------- 실행

    private static boolean deviceLocked(Context c) {
        KeyguardManager km = c.getSystemService(KeyguardManager.class);
        PowerManager pm = c.getSystemService(PowerManager.class);
        return (km != null && km.isKeyguardLocked()) || (pm != null && !pm.isInteractive());
    }

    static void tryStart(Context c) {
        if (current != null) return;
        long now = SystemClock.elapsedRealtime();
        Iterator<Task> it = tasks.iterator();
        while (it.hasNext()) if (now - it.next().enqueuedAt > TASK_EXPIRY_MS) it.remove();
        if (tasks.isEmpty()) return;
        SamsungAutomation s = service;
        if (s == null) {
            State.setAutomationStatus(c, "접근성 권한이 꺼져 있어 자동화 대기 – 수동 공유를 사용하세요");
            return;
        }
        if (!State.autoEnabled(s) && !tasks.peekFirst().test) {
            tasks.clear();
            return;
        }
        if (deviceLocked(s)) {
            State.setAutomationStatus(s, "화면 잠금 중 – 잠금 해제 후 자동화 시작(대기 " + tasks.size() + "건)");
            return;
        }
        Task t = tasks.pollFirst();
        current = t;
        t.startedAt = now;
        t.step = Step.OPENING;
        t.stepStartedAt = now;
        t.actions = 0;
        t.shadeAt = 0;
        t.shadeClicked = false;
        showProgress(s, "삼성 통화 화면을 여는 중…");
        if (State.diagEnabled(s)) State.diag(s, "자동화 시작 " + t.pkg + " 열기유형=" + intentKind(t.intent));
        State.setAutomationStatus(s, "자동화 시작" + (t.test ? "(연결 시험)" : "") + " – 삼성 화면을 엽니다");
        try {
            t.intent.send(s, 0, null, null, null, null, launchOptions());
        } catch (PendingIntent.CanceledException e) {
            abort(s, "알림의 열기 동작이 만료됨(알림이 갱신·삭제됨)", false);
            return;
        }
        main.removeCallbacks(TICK);
        main.postDelayed(TICK, TICK_MS);
    }

    /**
     * 알림의 PendingIntent로 삼성 화면을 열 때 보내는 쪽(이 앱)의 백그라운드 실행 허용을 명시한다(Android 14+).
     * 실행 가능 여부의 근거는 이 앱이 시스템에 바인딩된 접근성 서비스를 가진다는 점이다. 실기기 미검증.
     */
    /** PendingIntent 종류(진단용). activity가 아니면 삼성 쪽에서 화면을 다시 여는 중계(트램펄린)일 수 있다. */
    static String intentKind(PendingIntent pi) {
        if (pi == null) return "없음";
        if (Build.VERSION.SDK_INT < 31) return "알 수 없음";
        if (pi.isActivity()) return "activity";
        if (pi.isBroadcast()) return "broadcast";
        if (pi.isForegroundService()) return "foregroundService";
        if (pi.isService()) return "service";
        return "기타";
    }

    @SuppressWarnings("deprecation")
    private static Bundle launchOptions() {
        if (Build.VERSION.SDK_INT < 34) return null;
        ActivityOptions ao = ActivityOptions.makeBasic();
        if (Build.VERSION.SDK_INT >= 36) {
            ao.setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOW_ALWAYS);
        } else {
            ao.setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED);
        }
        return ao.toBundle();
    }

    private static final Runnable TICK = new Runnable() {
        @Override
        public void run() {
            Task t = current;
            SamsungAutomation s = service;
            if (t == null) return;
            if (s == null) {
                current = null;
                return;
            }
            s.tick(t);
            if (current == t) {
                main.removeCallbacks(TICK);
                main.postDelayed(TICK, TICK_MS);
            }
        }
    };

    private void tick(Task t) {
        long now = SystemClock.elapsedRealtime();
        if (now - t.startedAt > Policy.AUTOMATION_TIMEOUT_MS) {
            abort(this, "45초 안에 끝나지 않아 중단(단계: " + stepName(t.step) + ")", true);
            return;
        }
        if (deviceLocked(this)) {
            // 진행 중 잠김: 즉시 멈추고, 한 번만 잠금 해제 후 처음부터 다시 시도
            boolean retry = t.lockRetries < 1;
            abort(this, "화면이 잠겨 중단" + (retry ? " – 잠금 해제 후 다시 시도" : ""), false);
            if (retry) {
                t.lockRetries++;
                t.enqueuedAt = now;
                tasks.addFirst(t);
            }
            return;
        }
        String active = activePackage();
        if (t.step == Step.OPENING) {
            tickOpening(t, active, now);
            return;
        }
        if (active == null || SYSTEM_UI.equals(active)) return; // 알림창 등: 기다리되 누르지 않음
        boolean ownApp = getPackageName().equals(active);
        boolean samsung = Policy.isSamsungSource(active);
        boolean sheet = Policy.isShareSheet(active);
        boolean allowed = samsung
                || (sheet && (t.step == Step.TEXT_FILE || t.step == Step.TARGET || t.step == Step.WAIT_IMPORT))
                || (ownApp && (t.step == Step.TARGET || t.step == Step.WAIT_IMPORT));
        if (!allowed) {
            abort(this, "다른 앱(" + active + ")으로 이동해 중단", true);
            return;
        }
        if (t.actions >= Policy.AUTOMATION_MAX_ACTIONS && t.step != Step.WAIT_IMPORT) {
            abort(this, "동작 10회 상한 도달", true);
            return;
        }
        boolean stepTimedOut = now - t.stepStartedAt > Policy.STEP_TIMEOUT_MS;
        switch (t.step) {
            case MORE_OR_SHARE:
                if (clickLabel(t, Policy.SHARE_LABELS, false)) setStep(t, Step.TEXT_FILE);
                else if (clickLabel(t, Policy.MORE_LABELS, false)) setStep(t, Step.SHARE);
                else if (stepTimedOut) abort(this, "'더보기' 또는 '공유' 메뉴를 찾지 못함", true);
                break;
            case SHARE:
                if (clickLabel(t, Policy.SHARE_LABELS, false)) setStep(t, Step.TEXT_FILE);
                else if (stepTimedOut) abort(this, "'공유' 메뉴를 찾지 못함", true);
                break;
            case TEXT_FILE:
                if (clickLabel(t, Policy.TEXT_FILE_LABELS, false)) setStep(t, Step.TARGET);
                else if (clickLabel(t, Policy.TARGET_LABELS, true)) setStep(t, Step.WAIT_IMPORT);
                else if (stepTimedOut) abort(this, "'텍스트 파일' 선택지를 찾지 못함", true);
                break;
            case TARGET:
                if (ownApp) {
                    setStep(t, Step.WAIT_IMPORT);
                } else if (clickLabel(t, Policy.TARGET_LABELS, true)) {
                    setStep(t, Step.WAIT_IMPORT);
                } else if (sheet && now - t.lastScrollAt > 1_200L && scrollSheet(t)) {
                    t.lastScrollAt = now;
                } else if (stepTimedOut) {
                    abort(this, "공유 목록에서 '장비스 통화 연결'을 찾지 못함", true);
                }
                break;
            case WAIT_IMPORT:
                if (sheet && now - t.lastScrollAt > 1_200L && t.actions < Policy.AUTOMATION_MAX_ACTIONS
                        && clickLabel(t, Policy.JUST_ONCE_LABELS, true)) {
                    // 선택창이 '한 번만/항상'을 물으면 '한 번만'만 누른다(공유 화면 후보 패키지 안에서만)
                    t.lastScrollAt = now;
                } else if (now - t.stepStartedAt > IMPORT_TIMEOUT_MS) {
                    abort(this, "공유 후 가져오기 결과가 오지 않음", false);
                }
                break;
            default:
                break;
        }
    }

    /** 알림의 열기 동작 후 이 시간 안에 삼성 화면이 안 뜨면 알림창에서 직접 누른다. */
    private static final long SHADE_FALLBACK_AFTER_MS = 3_000L;
    private static final long OPENING_TIMEOUT_MS = 14_000L;

    /**
     * 통화 화면 열기 단계.
     * 1) contentIntent.send() 결과로 삼성 화면이 뜨면 다음 단계.
     * 2) 3초 안에 안 뜨면(삼성 알림이 중계 방식이라 다른 앱이 보낸 요청으로는 화면이 막히는 경우)
     *    알림창을 내리고, 제목이 정확히 같은 삼성 알림 한 개를 누른다(사람이 알림을 누른 것과 같은 경로).
     */
    private void tickOpening(Task t, String active, long now) {
        if (active != null && Policy.isSamsungSource(active)) {
            if (State.diagEnabled(this)) {
                State.diag(this, "통화 화면 열림 " + active + (t.shadeClicked ? " (알림창에서 누름)" : " (열기 동작)"));
            }
            setStep(t, Step.MORE_OR_SHARE);
            return;
        }
        long elapsed = now - t.stepStartedAt;
        if (elapsed > OPENING_TIMEOUT_MS) {
            abort(this, "삼성 통화 화면이 열리지 않음(앞 화면: " + active + ")", true);
            return;
        }
        if (t.shadeAt == 0 && elapsed > SHADE_FALLBACK_AFTER_MS) {
            if (t.title == null || t.title.trim().isEmpty()) {
                abort(this, "열기 동작으로 화면이 열리지 않았고, 알림 제목이 없어 알림창에서 찾을 수 없음", true);
                return;
            }
            t.shadeAt = now;
            showProgress(this, "알림창에서 삼성 알림을 누르는 중…");
            performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS);
            return;
        }
        if (t.shadeAt > 0 && !t.shadeClicked && now - t.shadeAt > 800L) {
            if (clickInShade(t)) {
                t.shadeClicked = true;
            } else if (now - t.shadeAt > 5_000L) {
                abort(this, "알림창에서 '" + t.title + "' 알림을 찾지 못함", true);
            }
        }
    }

    /** 시스템 UI(알림창) 창에서 알림 제목이 정확히 같은 노드의 클릭 가능한 상위 노드를 누른다. 위쪽(최신) 알림부터. */
    private boolean clickInShade(Task t) {
        if (t.actions >= Policy.AUTOMATION_MAX_ACTIONS) return false;
        List<AccessibilityWindowInfo> ws = getWindows();
        if (ws == null) return false;
        String[] label = {t.title};
        for (AccessibilityWindowInfo w : ws) {
            AccessibilityNodeInfo r = w.getRoot();
            if (r == null || r.getPackageName() == null || !SYSTEM_UI.equals(r.getPackageName().toString())) continue;
            AccessibilityNodeInfo hit = findLabel(r, label, 0);
            if (hit == null) continue;
            AccessibilityNodeInfo target = hit;
            int up = 0;
            while (target != null && !target.isClickable() && up++ < 8) target = target.getParent();
            if (target == null || !target.isClickable()) continue;
            t.actions++;
            if (target.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true;
        }
        return false;
    }

    private static void setStep(Task t, Step s) {
        t.step = s;
        t.stepStartedAt = SystemClock.elapsedRealtime();
        SamsungAutomation svc = service;
        if (svc != null) showProgress(svc, "진행 중: " + stepName(s));
    }

    static String stepName(Step s) {
        if (s == null) return "-";
        switch (s) {
            case OPENING: return "통화 화면 열기";
            case MORE_OR_SHARE: return "더보기";
            case SHARE: return "공유";
            case TEXT_FILE: return "텍스트 파일";
            case TARGET: return "장비스 통화 연결 선택";
            case WAIT_IMPORT: return "가져오기 확인";
            default: return s.name();
        }
    }

    private String activePackage() {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return null;
        CharSequence p = root.getPackageName();
        return p == null ? null : p.toString();
    }

    /** 허용 패키지 창들의 루트(위에 있는 창부터). */
    private List<AccessibilityNodeInfo> roots(boolean includeSheet) {
        List<AccessibilityNodeInfo> out = new ArrayList<>();
        List<AccessibilityWindowInfo> ws = getWindows();
        if (ws != null) {
            List<AccessibilityWindowInfo> sorted = new ArrayList<>(ws);
            java.util.Collections.sort(sorted, new java.util.Comparator<AccessibilityWindowInfo>() {
                @Override
                public int compare(AccessibilityWindowInfo a, AccessibilityWindowInfo b) {
                    return Integer.compare(b.getLayer(), a.getLayer());
                }
            });
            for (AccessibilityWindowInfo w : sorted) {
                if (w.getType() != AccessibilityWindowInfo.TYPE_APPLICATION
                        && w.getType() != AccessibilityWindowInfo.TYPE_SYSTEM) continue;
                AccessibilityNodeInfo r = w.getRoot();
                if (r == null || r.getPackageName() == null) continue;
                String p = r.getPackageName().toString();
                if (Policy.isSamsungSource(p) || (includeSheet && Policy.isShareSheet(p))) out.add(r);
            }
        }
        if (out.isEmpty()) {
            AccessibilityNodeInfo r = getRootInActiveWindow();
            if (r != null && r.getPackageName() != null) {
                String p = r.getPackageName().toString();
                if (Policy.isSamsungSource(p) || (includeSheet && Policy.isShareSheet(p))) out.add(r);
            }
        }
        return out;
    }

    /** 라벨이 정확히 일치하고 화면에 보이는 노드(또는 클릭 가능한 상위 노드)를 ACTION_CLICK. */
    private boolean clickLabel(Task t, String[] labels, boolean includeSheet) {
        for (AccessibilityNodeInfo root : roots(includeSheet)) {
            AccessibilityNodeInfo hit = findLabel(root, labels, 0);
            if (hit == null) continue;
            AccessibilityNodeInfo target = hit;
            int up = 0;
            while (target != null && !target.isClickable() && up++ < 4) target = target.getParent();
            if (target == null || !target.isClickable() || !target.isEnabled()) continue;
            t.actions++;
            if (target.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true;
        }
        return false;
    }

    private static AccessibilityNodeInfo findLabel(AccessibilityNodeInfo n, String[] labels, int depth) {
        if (n == null || depth > 40) return null;
        if (n.isVisibleToUser() && !n.isEditable()
                && (Policy.labelMatches(n.getText(), labels) || Policy.labelMatches(n.getContentDescription(), labels))) {
            return n;
        }
        for (int i = 0; i < n.getChildCount(); i++) {
            AccessibilityNodeInfo r = findLabel(n.getChild(i), labels, depth + 1);
            if (r != null) return r;
        }
        return null;
    }

    /** 공유 화면 후보 패키지의 스크롤 목록만 한 칸 넘긴다(좌표 사용 없음). */
    private boolean scrollSheet(Task t) {
        for (AccessibilityNodeInfo root : roots(true)) {
            CharSequence p = root.getPackageName();
            if (p == null || !Policy.isShareSheet(p.toString())) continue;
            AccessibilityNodeInfo sc = findScrollable(root, 0);
            if (sc != null) {
                t.actions++;
                return sc.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD);
            }
        }
        return false;
    }

    private static AccessibilityNodeInfo findScrollable(AccessibilityNodeInfo n, int depth) {
        if (n == null || depth > 40) return null;
        if (n.isScrollable() && n.isVisibleToUser()) return n;
        for (int i = 0; i < n.getChildCount(); i++) {
            AccessibilityNodeInfo r = findScrollable(n.getChild(i), depth + 1);
            if (r != null) return r;
        }
        return null;
    }

    // ---------------------------------------------------------------- 종료 처리

    private static void finishSuccess(SamsungAutomation s, Task t) {
        current = null;
        main.removeCallbacks(TICK);
        nm(s).cancel(NOTIF_PROGRESS);
        State.setAutomationStatus(s, "자동 가져오기 성공 – Dynalist 전송은 대기열에서 진행");
        // 녹취 화면을 앞에 남겨두지 않도록 홈으로(삼성 화면이 앞에 있을 때만)
        String active = s.activePackage();
        if (active != null && (Policy.isSamsungSource(active) || s.getPackageName().equals(active))) {
            s.performGlobalAction(GLOBAL_ACTION_HOME);
        }
        scheduleNext(s);
    }

    /** 중단: 이유를 상태·알림에 남기고 다음 작업으로. dumpUi면 진단 기록에 화면 골격을 남긴다. */
    static void abort(Context c, String why, boolean dumpUi) {
        Task t = current;
        current = null;
        main.removeCallbacks(TICK);
        SamsungAutomation s = service;
        if (s != null && t != null && t.shadeAt > 0 && !t.shadeClicked) {
            // 이 앱이 내린 알림창은 다시 닫는다
            if (Build.VERSION.SDK_INT >= 31) s.performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE);
            else s.performGlobalAction(GLOBAL_ACTION_BACK);
        }
        if (dumpUi && s != null && State.diagEnabled(s)) s.dumpUi(t);
        State.setAutomationStatus(c, "자동화 중단: " + why + " – 통화 텍스트를 수동으로 공유하세요");
        if (State.diagEnabled(c)) {
            State.diag(c, "자동화 중단 단계=" + (t == null ? "-" : stepName(t.step))
                    + " 동작=" + (t == null ? 0 : t.actions) + " 이유=" + why);
        }
        nm(c).cancel(NOTIF_PROGRESS);
        Notification n = new Notification.Builder(c, CH_RESULT)
                .setSmallIcon(android.R.drawable.stat_notify_error)
                .setContentTitle("자동 공유 중단")
                .setContentText(why)
                .setStyle(new Notification.BigTextStyle().bigText(why + "\n통화 텍스트를 수동으로 공유하면 같은 방식으로 저장됩니다."))
                .setContentIntent(openApp(c))
                .setAutoCancel(true)
                .build();
        notifySafe(c, NOTIF_RESULT, n);
        scheduleNext(c);
    }

    private static void scheduleNext(final Context c) {
        main.postDelayed(new Runnable() {
            @Override
            public void run() {
                tryStart(c);
            }
        }, 1_500L);
    }

    /**
     * 화면 진단: 창 패키지와 노드의 view ID·클래스·짧은 접근성 설명만 남긴다.
     * 일반 텍스트(녹취 문장 가능성)는 남기지 않고, 후보 라벨과 일치하는 경우만 표시한다.
     */
    private void dumpUi(Task t) {
        StringBuilder sb = new StringBuilder("화면 진단 단계=" + (t == null ? "-" : stepName(t.step)) + "\n");
        List<AccessibilityWindowInfo> ws = getWindows();
        if (ws == null) return;
        int lines = 0;
        for (AccessibilityWindowInfo w : ws) {
            AccessibilityNodeInfo r = w.getRoot();
            if (r == null) continue;
            String p = String.valueOf(r.getPackageName());
            sb.append(" 창 type=").append(w.getType()).append(" pkg=").append(p).append('\n');
            if (!Policy.isSamsungSource(p) && !Policy.isShareSheet(p)) continue;
            lines = dumpNode(r, sb, 0, lines);
        }
        State.diag(this, sb.toString());
    }

    private static int dumpNode(AccessibilityNodeInfo n, StringBuilder sb, int depth, int lines) {
        if (n == null || depth > 30 || lines > 60) return lines;
        if (n.isClickable() && n.isVisibleToUser()) {
            String cls = String.valueOf(n.getClassName());
            cls = cls.substring(cls.lastIndexOf('.') + 1);
            CharSequence d = n.getContentDescription();
            CharSequence tx = n.getText();
            String label = "";
            String[][] all = {Policy.MORE_LABELS, Policy.SHARE_LABELS, Policy.TEXT_FILE_LABELS, Policy.TARGET_LABELS};
            for (String[] ls : all) {
                if (Policy.labelMatches(tx, ls) || Policy.labelMatches(d, ls)) label = " 후보일치";
            }
            String desc = d != null && d.length() <= 20 ? " desc=" + Policy.skeleton(d.toString()) : "";
            sb.append("  ").append(cls)
                    .append(n.getViewIdResourceName() == null ? "" : " id=" + n.getViewIdResourceName())
                    .append(desc)
                    .append(tx == null ? "" : " text=▢" + tx.length())
                    .append(label).append('\n');
            lines++;
        }
        for (int i = 0; i < n.getChildCount(); i++) lines = dumpNode(n.getChild(i), sb, depth + 1, lines);
        return lines;
    }

    // ---------------------------------------------------------------- 알림

    static void createChannels(Context c) {
        NotificationManager m = nm(c);
        m.createNotificationChannel(new NotificationChannel(CH_PROGRESS, "자동 공유 진행",
                NotificationManager.IMPORTANCE_LOW));
        m.createNotificationChannel(new NotificationChannel(CH_RESULT, "자동 공유 결과",
                NotificationManager.IMPORTANCE_DEFAULT));
    }

    private static void showProgress(Context c, String text) {
        PendingIntent cancel = PendingIntent.getBroadcast(c, 1,
                new Intent(c, CancelReceiver.class), PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        Notification n = new Notification.Builder(c, CH_PROGRESS)
                .setSmallIcon(android.R.drawable.stat_sys_upload)
                .setContentTitle("장비스 자동 공유 진행 중")
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .addAction(new Notification.Action.Builder(null, "취소", cancel).build())
                .build();
        notifySafe(c, NOTIF_PROGRESS, n);
    }

    private static PendingIntent openApp(Context c) {
        return PendingIntent.getActivity(c, 2, new Intent(c, MainActivity.class),
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    }

    private static void notifySafe(Context c, int id, Notification n) {
        try {
            nm(c).notify(id, n);
        } catch (SecurityException ignored) {
            // 알림 권한이 없으면 표시하지 않는다(상태는 앱 화면에 남음)
        }
    }

    private static NotificationManager nm(Context c) {
        return c.getSystemService(NotificationManager.class);
    }

    /** 진행 알림의 '취소' 버튼. */
    public static class CancelReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            cancelAll(context.getApplicationContext(), "사용자가 자동화를 취소함");
        }
    }
}
