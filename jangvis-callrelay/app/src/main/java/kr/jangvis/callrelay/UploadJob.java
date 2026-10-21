package kr.jangvis.callrelay;

import android.app.job.JobInfo;
import android.app.job.JobParameters;
import android.app.job.JobScheduler;
import android.app.job.JobService;
import android.content.ComponentName;
import android.content.Context;
import android.os.SystemClock;

import org.json.JSONException;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * 대기열 전송 작업(JobScheduler). 네트워크 조건이 붙어 있어 오프라인이면 연결 복구 후 실행되고,
 * setPersisted로 재부팅 후에도 남는다(BootReceiver가 한 번 더 예약).
 */
public class UploadJob extends JobService {
    static final int JOB_NOW = 7101;
    static final int JOB_LATER = 7102;
    private static final int BATCH = 20;
    /** 한 번 실행에서 쓰는 최대 시간. 남은 항목은 즉시 다시 예약한다. */
    private static final long RUN_BUDGET_MS = 4 * 60_000L;
    /** 요청 간 최소 간격(단위 검사에서는 0으로 줄인다). */
    static long minReadIntervalMs = 2_500L;
    static long minEditIntervalMs = 1_200L;

    private static final AtomicBoolean running = new AtomicBoolean(false);
    private static final AtomicBoolean rerun = new AtomicBoolean(false);
    private static long lastReadAt, lastEditAt;

    private volatile boolean stopped;

    /** 새 항목·설정 변경·부팅 후 호출. 실행 중이면 끝난 뒤 한 번 더 돈다(실행 중 작업을 중단시키지 않음). */
    public static void kick(Context c) {
        if (running.get()) {
            rerun.set(true);
            return;
        }
        schedule(c, JOB_NOW, 0);
    }

    static void schedule(Context c, int jobId, long delayMs) {
        JobScheduler js = c.getSystemService(JobScheduler.class);
        JobInfo.Builder b = new JobInfo.Builder(jobId, new ComponentName(c, UploadJob.class))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPersisted(true)
                .setBackoffCriteria(30_000L, JobInfo.BACKOFF_POLICY_EXPONENTIAL);
        if (delayMs > 0) b.setMinimumLatency(delayMs);
        js.schedule(b.build());
    }

    @Override
    public boolean onStartJob(final JobParameters params) {
        if (!running.compareAndSet(false, true)) {
            // 다른 실행이 진행 중: 그쪽이 끝나며 다시 확인한다.
            rerun.set(true);
            return false;
        }
        stopped = false;
        new Thread(new Runnable() {
            @Override
            public void run() {
                boolean again;
                try {
                    again = runOnce();
                } catch (RuntimeException e) {
                    State.setStatus(UploadJob.this, "전송 작업 오류: " + e.getClass().getSimpleName());
                    again = false;
                } finally {
                    running.set(false);
                }
                jobFinished(params, false);
                reschedule(UploadJob.this, again || rerun.getAndSet(false));
            }
        }, "callrelay-upload").start();
        return true;
    }

    @Override
    public boolean onStopJob(JobParameters params) {
        // 진행 중인 HTTP 요청은 끝까지 기다리고(선점된 항목 정리), 새 항목은 꺼내지 않는다.
        stopped = true;
        return true;
    }

    /** 남은 일이 있으면 즉시, 대기 시각이 있으면 그때 다시 예약. */
    static void reschedule(Context c, boolean immediately) {
        long now = System.currentTimeMillis();
        long rate = State.rateBlockedUntil(c);
        if (immediately && rate <= now) {
            schedule(c, JOB_NOW, 0);
            return;
        }
        long next = Queue.get(c).nextWakeAt();
        if (next < 0) return;
        next = Math.max(next, rate);
        schedule(c, JOB_LATER, Math.max(1_000L, next - now));
    }

    /** @return 시간 예산 안에 다 못 끝내 바로 다시 돌아야 하면 true */
    boolean runOnce() {
        Queue q = Queue.get(this);
        long start = SystemClock.elapsedRealtime();
        long now = System.currentTimeMillis();
        q.recoverStale(now);
        q.pruneSentText(now);
        if (State.rateBlockedUntil(this) > now) return false;

        String token = State.token(this);
        if (token == null) {
            State.setStatus(this, "Dynalist 토큰이 없어 전송 대기 중");
            return false;
        }
        int sent = 0;
        while (!stopped) {
            if (SystemClock.elapsedRealtime() - start > RUN_BUDGET_MS) return true;
            now = System.currentTimeMillis();
            List<Queue.Item> batch = q.ready(now, BATCH);
            if (batch.isEmpty()) break;
            Map<String, List<Queue.Item>> byDest = new LinkedHashMap<>();
            for (Queue.Item it : batch) {
                List<Queue.Item> l = byDest.get(it.destination);
                if (l == null) byDest.put(it.destination, l = new ArrayList<>());
                l.add(it);
            }
            boolean progressed = false;
            for (Map.Entry<String, List<Queue.Item>> e : byDest.entrySet()) {
                if (stopped) break;
                int r = sendGroup(q, token, e.getKey(), e.getValue());
                if (r < 0) return false; // 요청 제한·인증 오류: 이번 실행 중단
                if (r > 0) progressed = true;
                sent += r;
            }
            if (!progressed) break;
        }
        if (sent > 0) State.setStatus(this, "Dynalist 전송 완료 " + sent + "건");
        return false;
    }

    /**
     * 한 목적지 문서의 항목들을 전송한다.
     * 1) 선점 2) doc/read로 루트 노드·기존 식별자 확인 3) 없는 항목만 insert
     * @return 처리(완료·오류 확정)한 건수, 이번 실행을 멈춰야 하면 -1
     */
    private int sendGroup(Queue q, String token, String fileId, List<Queue.Item> items) {
        String claimToken = UUID.randomUUID().toString();
        long now = System.currentTimeMillis();
        List<Queue.Item> mine = new ArrayList<>();
        for (Queue.Item it : items) if (q.claim(it, claimToken, now)) mine.add(it);
        if (mine.isEmpty()) return 0;

        pace(true);
        Dynalist.Response rr = Dynalist.readDoc(token, fileId);
        Dynalist.Doc doc = null;
        if (rr.kind == Dynalist.Kind.OK) {
            try {
                doc = Dynalist.parseDoc(rr.json);
            } catch (JSONException e) {
                rr = new Dynalist.Response(Dynalist.Kind.INVALID, null, "문서 구조 해석 실패: " + e.getMessage(), null);
            }
        }
        if (doc == null) {
            // 조회 실패: 아무것도 보내지 않았으므로 원래 상태(pending/uncertain)로 되돌린다.
            return handleFailure(q, mine, rr, true);
        }

        int done = 0;
        for (int i = 0; i < mine.size(); i++) {
            Queue.Item it = mine.get(i);
            now = System.currentTimeMillis();
            String existing = doc.markers.get(it.id);
            if (existing != null) {
                // 이미 서버에 있음(재공유·응답 손실 후 저장됨): 다시 보내지 않는다.
                q.markSent(it, existing, now);
                done++;
                continue;
            }
            if (Queue.UNCERTAIN.equals(it.prevState)) {
                // 확인 지연 후 조회했는데 식별자가 없음 → 서버에 저장되지 않은 것으로 판단, 다시 보낸다.
                it.prevState = Queue.PENDING;
            }
            if (stopped) {
                releaseRest(q, mine, i, null);
                break;
            }
            pace(false);
            Dynalist.Response er = Dynalist.insert(token, fileId, doc.rootId, it.title, Policy.note(it.text, it.id));
            now = System.currentTimeMillis();
            if (er.kind == Dynalist.Kind.OK) {
                String nodeId = Dynalist.newNodeId(er.json);
                if (nodeId == null) {
                    // _code는 Ok지만 생성 노드 ID가 없음 → 저장 여부를 식별자로 다시 대조
                    q.markUncertain(it, "응답에 생성 노드 ID 없음 – 서버 대조 예정", now);
                } else {
                    q.markSent(it, nodeId, now);
                    doc.markers.put(it.id, nodeId);
                    done++;
                }
                continue;
            }
            List<Queue.Item> one = new ArrayList<>();
            one.add(it);
            int r = handleFailure(q, one, er, false);
            if (r < 0) {
                releaseRest(q, mine, i + 1, null);
                return -1;
            }
            if (er.kind == Dynalist.Kind.INVALID) {
                // 이 항목만의 문제일 수 있음(예: 본문 거부): 다음 항목은 계속
                done += r;
                continue;
            }
            if (er.kind == Dynalist.Kind.NOT_FOUND) {
                // 문서·루트 노드가 사라짐: 같은 문서의 나머지도 같은 오류
                List<Queue.Item> rest = new ArrayList<>(mine.subList(i + 1, mine.size()));
                return done + r + handleFailure(q, rest, er, false);
            }
            // 네트워크·응답 손실·일시 오류: 나머지는 손대지 않고 다음 실행으로
            releaseRest(q, mine, i + 1, null);
            return done;
        }
        return done;
    }

    private void releaseRest(Queue q, List<Queue.Item> mine, int from, String err) {
        long now = System.currentTimeMillis();
        for (int j = from; j < mine.size(); j++) q.release(mine.get(j), 0, err, false, now);
    }

    /** 실패 처리. readPhase=true면 아직 아무 요청도 보내지 않은 상태. */
    private int handleFailure(Queue q, List<Queue.Item> items, Dynalist.Response r, boolean readPhase) {
        long now = System.currentTimeMillis();
        String why = r.describe();
        switch (r.kind) {
            case RATE_LIMITED: {
                int a = 0;
                for (Queue.Item it : items) a = Math.max(a, it.attempts);
                long until = now + Policy.backoffMillis(a);
                State.setRateBlockedUntil(this, until);
                for (Queue.Item it : items) q.release(it, until, "요청 제한 – 잠시 후 재시도", true, now);
                State.setStatus(this, "Dynalist 요청 제한: " + (Policy.backoffMillis(a) / 1000) + "초 후 재시도");
                return -1;
            }
            case AUTH:
                for (Queue.Item it : items) q.markError(it, "토큰 오류(" + why + ") – 설정에서 토큰 확인", now);
                State.setStatus(this, "Dynalist 토큰 오류: 설정 확인 후 '오류 항목 재시도'");
                return -1;
            case NOT_FOUND:
                for (Queue.Item it : items) q.markError(it, "문서를 찾을 수 없음(" + why + ") – 문서 ID 확인", now);
                return items.size();
            case INVALID:
                for (Queue.Item it : items) q.markError(it, "요청 거부(" + why + ")", now);
                return items.size();
            case UNKNOWN:
                if (readPhase) {
                    // 조회 요청의 응답 손실은 쓰기가 아니므로 중복 위험 없음
                    for (Queue.Item it : items) q.release(it, now + Policy.backoffMillis(it.attempts), why, true, now);
                    return 0;
                }
                for (Queue.Item it : items) q.markUncertain(it, why, now);
                return 0;
            case NOT_SENT:
            case TEMPORARY:
            default:
                for (Queue.Item it : items) q.release(it, now + Policy.backoffMillis(it.attempts), why, true, now);
                return 0;
        }
    }

    /** 공식 요청 제한보다 느리게 보내도록 최소 간격 유지. */
    private static synchronized void pace(boolean read) {
        long now = SystemClock.elapsedRealtime();
        long last = read ? lastReadAt : lastEditAt;
        long wait = (read ? minReadIntervalMs : minEditIntervalMs) - (now - last);
        if (wait > 0) SystemClock.sleep(wait);
        if (read) lastReadAt = SystemClock.elapsedRealtime();
        else lastEditAt = SystemClock.elapsedRealtime();
    }
}
