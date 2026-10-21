package kr.jangvis.callrelay;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.SparseBooleanArray;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * 통화 목록: 공유·파일·폴더로 불러온 통화를 보여주고, 사용자가 고른 것만 Dynalist로 보낸다.
 * 보관(미전송)·오류 항목만 전송·숨기기 대상이고, 전송 중·완료 항목은 목록에 표시만 한다.
 */
public class CallListActivity extends Activity {
    private static final int REQ_FILES = 11;
    private static final int REQ_FOLDER = 12;
    private static final int LIST_LIMIT = 300;

    private final Handler main = new Handler(Looper.getMainLooper());
    private final List<Queue.Item> items = new ArrayList<>();
    private ArrayAdapter<String> adapter;
    private ListView list;
    private TextView summary;
    private boolean busy;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setTitle("통화 목록");
        setContentView(R.layout.activity_calls);
        summary = findViewById(R.id.calls_summary);
        list = findViewById(R.id.calls_list);
        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_multiple_choice, new ArrayList<String>());
        list.setAdapter(adapter);
        list.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int pos, long id) {
                if (!selectable(items.get(pos))) {
                    list.setItemChecked(pos, false);
                    toast("'" + ShareActivity.stateLabel(items.get(pos).state) + "' 항목은 선택할 수 없습니다. 길게 누르면 내용을 봅니다.");
                }
                updateSummary();
            }
        });
        list.setOnItemLongClickListener(new AdapterView.OnItemLongClickListener() {
            @Override
            public boolean onItemLongClick(AdapterView<?> parent, View view, int pos, long id) {
                preview(items.get(pos));
                return true;
            }
        });
        click(R.id.calls_pick_files, new Runnable() {
            @Override
            public void run() {
                Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                i.addCategory(Intent.CATEGORY_OPENABLE);
                i.setType("text/*");
                i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                startActivityForResult(i, REQ_FILES);
            }
        });
        click(R.id.calls_folder, new Runnable() {
            @Override
            public void run() {
                startActivityForResult(new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), REQ_FOLDER);
            }
        });
        click(R.id.calls_refresh, new Runnable() {
            @Override
            public void run() {
                String f = State.folderUri(CallListActivity.this);
                if (f == null) {
                    toast("먼저 '폴더 연결'로 통화 텍스트 파일이 있는 폴더를 고르세요.");
                    return;
                }
                scanFolder(Uri.parse(f));
            }
        });
        click(R.id.calls_select_all, new Runnable() {
            @Override
            public void run() {
                for (int i = 0; i < items.size(); i++) list.setItemChecked(i, selectable(items.get(i)));
                updateSummary();
            }
        });
        click(R.id.calls_upload, new Runnable() {
            @Override
            public void run() {
                confirmUpload();
            }
        });
        click(R.id.calls_dismiss, new Runnable() {
            @Override
            public void run() {
                final List<String> ids = checkedIds();
                if (ids.isEmpty()) {
                    toast("숨길 항목을 선택하세요.");
                    return;
                }
                new AlertDialog.Builder(CallListActivity.this)
                        .setMessage(ids.size() + "건을 목록에서 숨기고 휴대폰에 보관한 본문을 지웁니다. 같은 통화를 다시 불러와도 나타나지 않습니다.")
                        .setPositiveButton("숨기기", new DialogInterface.OnClickListener() {
                            @Override
                            public void onClick(DialogInterface d, int w) {
                                int n = Queue.get(CallListActivity.this).dismiss(ids, System.currentTimeMillis());
                                toast(n + "건 숨김");
                                reload();
                            }
                        })
                        .setNegativeButton("취소", null)
                        .show();
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        reload();
    }

    private void click(int id, final Runnable r) {
        findViewById(id).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (busy) {
                    toast("불러오는 중입니다. 잠시 후 다시 누르세요.");
                    return;
                }
                r.run();
            }
        });
    }

    static boolean selectable(Queue.Item it) {
        return Queue.HELD.equals(it.state) || Queue.ERROR.equals(it.state);
    }

    private void reload() {
        List<String> keep = checkedIds();
        items.clear();
        items.addAll(Queue.get(this).pickList(LIST_LIMIT));
        List<String> rows = new ArrayList<>();
        SimpleDateFormat f = new SimpleDateFormat("MM-dd HH:mm", Locale.KOREA);
        for (Queue.Item it : items) {
            int chars = it.text == null ? 0 : it.text.codePointCount(0, it.text.length());
            StringBuilder r = new StringBuilder();
            r.append(it.title).append('\n')
                    .append(ShareActivity.stateLabel(it.state)).append(" · ").append(f.format(new Date(it.created)));
            if (chars > 0) r.append(" · ").append(chars).append("자");
            if (it.lastError != null && !Queue.SENT.equals(it.state)) r.append("\n↳ ").append(it.lastError);
            rows.add(r.toString());
        }
        adapter.clear();
        adapter.addAll(rows);
        adapter.notifyDataSetChanged();
        list.clearChoices();
        for (int i = 0; i < items.size(); i++) {
            if (keep.contains(items.get(i).id) && selectable(items.get(i))) list.setItemChecked(i, true);
        }
        updateSummary();
    }

    private List<String> checkedIds() {
        List<String> out = new ArrayList<>();
        if (list == null) return out;
        SparseBooleanArray c = list.getCheckedItemPositions();
        if (c == null) return out;
        for (int i = 0; i < c.size(); i++) {
            int pos = c.keyAt(i);
            if (c.valueAt(i) && pos < items.size() && selectable(items.get(pos))) out.add(items.get(pos).id);
        }
        return out;
    }

    private void updateSummary() {
        int held = 0, sent = 0, other = 0;
        for (Queue.Item it : items) {
            if (selectable(it)) held++;
            else if (Queue.SENT.equals(it.state)) sent++;
            else other++;
        }
        String folder = State.folderUri(this) == null ? "폴더 미연결" : "폴더 연결됨";
        summary.setText("미전송 " + held + " · 전송 중/대기 " + other + " · 완료 " + sent + " · 선택 " + checkedIds().size()
                + "\n" + folder + " · 길게 누르면 내용 미리보기");
    }

    private void confirmUpload() {
        final List<String> ids = checkedIds();
        if (ids.isEmpty()) {
            toast("전송할 통화를 선택하세요.");
            return;
        }
        final String doc = State.docId(this);
        if (doc == null || !State.hasToken(this)) {
            toast("먼저 설정 화면에서 Dynalist 토큰과 문서를 저장하세요.");
            return;
        }
        String docName = State.docTitle(this) == null ? doc : State.docTitle(this);
        new AlertDialog.Builder(this)
                .setTitle("Dynalist 전송")
                .setMessage("선택한 " + ids.size() + "건의 통화 녹취 텍스트를 전송합니다.\n"
                        + "목적지가 정해지지 않은 항목은 지금 문서('" + docName + "')로 보냅니다.\n"
                        + "이미 Dynalist에 있는 통화는 식별자로 확인해 다시 넣지 않습니다.")
                .setPositiveButton("전송", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface d, int w) {
                        int n = Queue.get(CallListActivity.this).queueSelected(ids, doc, System.currentTimeMillis());
                        UploadJob.kick(CallListActivity.this);
                        toast(n + "건 전송 시작 – 결과는 목록과 설정 화면에 표시됩니다");
                        list.clearChoices();
                        reload();
                    }
                })
                .setNegativeButton("취소", null)
                .show();
    }

    private void preview(Queue.Item it) {
        Queue.Item full = Queue.get(this).find(it.id);
        String text = full == null || full.text == null || full.text.isEmpty() ? "(본문 없음)" : full.text;
        if (text.length() > 3000) text = text.substring(0, 3000) + "\n…";
        new AlertDialog.Builder(this).setTitle(it.title).setMessage(text).setPositiveButton("닫기", null).show();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != RESULT_OK || data == null) return;
        if (requestCode == REQ_FILES) {
            final List<Uri> uris = new ArrayList<>();
            if (data.getClipData() != null) {
                for (int i = 0; i < data.getClipData().getItemCount(); i++) uris.add(data.getClipData().getItemAt(i).getUri());
            } else if (data.getData() != null) {
                uris.add(data.getData());
            }
            importFiles(uris);
        } else if (requestCode == REQ_FOLDER && data.getData() != null) {
            Uri tree = data.getData();
            try {
                getContentResolver().takePersistableUriPermission(tree, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            } catch (SecurityException e) {
                toast("폴더 권한을 유지할 수 없습니다. 이번만 불러옵니다.");
            }
            State.setFolderUri(this, tree.toString());
            scanFolder(tree);
        }
    }

    private void importFiles(final List<Uri> uris) {
        busy = true;
        summary.setText("파일 " + uris.size() + "개 불러오는 중…");
        new Thread(new Runnable() {
            @Override
            public void run() {
                int ok = 0, dup = 0, fail = 0;
                StringBuilder err = new StringBuilder();
                for (Uri u : uris) {
                    Importer.Outcome o = Importer.importFile(CallListActivity.this, u, null, null, "file", true);
                    if (!o.ok) {
                        fail++;
                        if (err.length() < 400) err.append("\n• ").append(o.message);
                    } else if (o.duplicate) dup++;
                    else ok++;
                }
                final String msg = "새로 보관 " + ok + " · 이미 있음 " + dup + (fail > 0 ? " · 실패 " + fail + err : "");
                done(msg);
            }
        }, "callrelay-files").start();
    }

    private void scanFolder(final Uri tree) {
        busy = true;
        summary.setText("폴더의 텍스트 파일을 불러오는 중…");
        new Thread(new Runnable() {
            @Override
            public void run() {
                done(Importer.importFolder(CallListActivity.this, tree).describe());
            }
        }, "callrelay-folder").start();
    }

    private void done(final String msg) {
        main.post(new Runnable() {
            @Override
            public void run() {
                busy = false;
                if (isFinishing() || isDestroyed()) return;
                reload();
                new AlertDialog.Builder(CallListActivity.this).setMessage(msg).setPositiveButton("확인", null).show();
            }
        });
    }

    private void toast(String s) {
        Toast.makeText(this, s, Toast.LENGTH_LONG).show();
    }
}
