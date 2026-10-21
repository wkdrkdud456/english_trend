package kr.jangvis.callrelay;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** 재부팅·앱 업데이트 후 대기열 처리를 다시 예약한다. 전송 작업은 setPersisted로도 유지된다. */
public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String a = intent == null ? null : intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(a) || Intent.ACTION_MY_PACKAGE_REPLACED.equals(a)) {
            UploadJob.schedule(context, UploadJob.JOB_NOW, 0);
        }
    }
}
