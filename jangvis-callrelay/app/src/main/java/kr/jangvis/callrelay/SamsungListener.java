package kr.jangvis.callrelay;

import android.app.Notification;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;

/**
 * 삼성 통화·음성 녹음 앱의 알림만 본다. 알림은 '텍스트 변환 완료' 신호로만 쓰고,
 * 녹취 본문을 알림에서 읽어 전송하지 않는다(본문은 공유 흐름으로만 받음).
 */
public class SamsungListener extends NotificationListenerService {
    private static volatile SamsungListener instance;

    static boolean isConnected() {
        return instance != null;
    }

    @Override
    public void onListenerConnected() {
        instance = this;
    }

    @Override
    public void onListenerDisconnected() {
        instance = null;
    }

    @Override
    public void onDestroy() {
        instance = null;
        super.onDestroy();
    }

    /** 알림에서 얻은 판정 정보. 본문은 담지 않는다. */
    static final class Seen {
        String key, pkg, skeleton, signature;
        long when, postTime;
        Policy.NotificationKind kind;
        StatusBarNotification sbn;
    }

    static Seen inspect(StatusBarNotification sbn) {
        Notification n = sbn.getNotification();
        Bundle ex = n.extras;
        // 제목·짧은 본문만 판정에 쓴다. 긴 본문(EXTRA_BIG_TEXT)·여러 줄(EXTRA_TEXT_LINES)은 읽지 않는다.
        CharSequence t = ex == null ? null : ex.getCharSequence(Notification.EXTRA_TITLE);
        CharSequence x = ex == null ? null : ex.getCharSequence(Notification.EXTRA_TEXT);
        String title = t == null ? "" : t.toString();
        String text = x == null ? "" : x.toString();
        boolean ongoing = (n.flags & Notification.FLAG_ONGOING_EVENT) != 0;
        boolean progress = ex != null && ex.getInt(Notification.EXTRA_PROGRESS_MAX, 0) > 0
                && ex.getInt(Notification.EXTRA_PROGRESS, 0) < ex.getInt(Notification.EXTRA_PROGRESS_MAX, 0);
        progress |= ex != null && ex.getBoolean(Notification.EXTRA_PROGRESS_INDETERMINATE, false);
        Seen s = new Seen();
        s.sbn = sbn;
        s.key = sbn.getKey();
        s.pkg = sbn.getPackageName();
        s.when = n.when;
        s.postTime = sbn.getPostTime();
        s.kind = Policy.classify(title, text, ongoing, progress);
        s.skeleton = Policy.skeleton(title) + " / " + Policy.skeleton(text);
        // 같은 알림의 반복 갱신은 같은 서명, 알림 ID가 재사용된 다음 통화는 when·문구가 달라 다른 서명.
        s.signature = Policy.sha256Hex(s.key + "|" + n.when + "|" + title + "|" + text).substring(0, 32);
        return s;
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        if (sbn == null) return;
        if (!Policy.isSamsungSource(sbn.getPackageName())) {
            discover(sbn);
            return;
        }
        if ((sbn.getNotification().flags & Notification.FLAG_GROUP_SUMMARY) != 0) return;
        Seen s = inspect(sbn);
        if (State.diagEnabled(this)) {
            Notification n = sbn.getNotification();
            State.diag(this, "알림 " + s.pkg
                    + " id=" + sbn.getId()
                    + (sbn.getTag() == null ? "" : " tag=" + Policy.skeleton(sbn.getTag()))
                    + " ch=" + n.getChannelId()
                    + " cat=" + n.category
                    + " 판정=" + s.kind
                    + " 열기=" + (n.contentIntent != null)
                    + " 문구=[" + s.skeleton + "]");
        }
        if (s.kind != Policy.NotificationKind.TRANSCRIPT_DONE) return;
        if (!State.autoEnabled(this)) return;
        if (sbn.getNotification().contentIntent == null) {
            State.setAutomationStatus(this, "완료 알림에 열기 동작이 없어 자동화를 시작하지 않음");
            return;
        }
        if (!State.markSignatureNew(this, s.signature, System.currentTimeMillis())) return; // 반복 이벤트
        SamsungAutomation.enqueue(this, s.key, s.signature, s.pkg, sbn.getNotification().contentIntent, false);
    }

    /**
     * 진단이 켜져 있으면 허용 목록 밖의 통화 녹음 관련 알림을 패키지 이름과 문구 골격만 기록한다.
     * 이 알림으로 자동화를 시작하지는 않는다(허용 목록은 코드에서만 바꾼다).
     */
    private void discover(StatusBarNotification sbn) {
        if (!State.diagEnabled(this)) return;
        Notification n = sbn.getNotification();
        Bundle ex = n.extras;
        CharSequence t = ex == null ? null : ex.getCharSequence(Notification.EXTRA_TITLE);
        CharSequence x = ex == null ? null : ex.getCharSequence(Notification.EXTRA_TEXT);
        String title = t == null ? "" : t.toString();
        String text = x == null ? "" : x.toString();
        if (!Policy.looksCallRelated(title, text)) return;
        Seen s = inspect(sbn);
        State.diag(this, "허용 목록 밖 알림 " + s.pkg + " 판정=" + s.kind + " 문구=[" + s.skeleton + "]");
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        if (sbn == null || !Policy.isSamsungSource(sbn.getPackageName())) return;
        SamsungAutomation.onNotificationRemoved(sbn.getKey());
    }

    /**
     * '알림 연결 시험': 현재 표시 중인 삼성 변환 완료 알림 중 가장 최근 것으로 자동화를 실행한다.
     * @return 사용자에게 보여줄 결과 문구
     */
    static String runTest(android.content.Context c) {
        SamsungListener l = instance;
        if (l == null) return "알림 접근 권한이 꺼져 있거나 서비스가 연결되지 않았습니다.";
        StatusBarNotification[] all;
        try {
            all = l.getActiveNotifications();
        } catch (RuntimeException e) {
            return "현재 알림을 읽을 수 없습니다.";
        }
        Seen best = null;
        int samsung = 0;
        if (all != null) {
            for (StatusBarNotification sbn : all) {
                if (!Policy.isSamsungSource(sbn.getPackageName())) continue;
                samsung++;
                Seen s = inspect(sbn);
                if (s.kind != Policy.NotificationKind.TRANSCRIPT_DONE) continue;
                if (sbn.getNotification().contentIntent == null) continue;
                if (best == null || s.postTime > best.postTime) best = s;
            }
        }
        if (best == null) {
            // 허용 목록 밖 패키지에서 완료로 보이는 알림이 있는지 패키지 이름만 알려준다(본문 표시 없음).
            StringBuilder other = new StringBuilder();
            if (all != null) {
                for (StatusBarNotification sbn : all) {
                    if (Policy.isSamsungSource(sbn.getPackageName())) continue;
                    if (inspect(sbn).kind != Policy.NotificationKind.TRANSCRIPT_DONE) continue;
                    if (other.indexOf(sbn.getPackageName()) < 0) other.append("\n• ").append(sbn.getPackageName());
                }
            }
            String msg = "표시 중인 삼성 알림 " + samsung + "개 중 '텍스트 변환 완료'로 판정된 알림이 없습니다. "
                    + "통화 후 변환 완료 알림이 실제로 오는지 '삼성 알림 진단'으로 확인하세요.";
            if (other.length() > 0) {
                msg += "\n\n허용 목록 밖에서 완료 알림으로 보이는 패키지:" + other
                        + "\n이 패키지 이름을 알려주시면 허용 목록에 추가합니다.";
            }
            return msg;
        }
        State.markSignatureNew(c, best.signature, System.currentTimeMillis());
        SamsungAutomation.enqueue(c, best.key, best.signature, best.pkg, best.sbn.getNotification().contentIntent, true);
        return "시험 시작: 삼성 화면이 열리고 공유 흐름을 진행합니다. 성공하면 실제 녹취가 Dynalist로 전송됩니다.";
    }
}
