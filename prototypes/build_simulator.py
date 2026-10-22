"""data/gimpo_schools.json을 템플릿에 넣어 highschool_simulator.html을 만든다."""
import json, pathlib
here = pathlib.Path(__file__).parent
data = json.loads((here / "data" / "gimpo_schools.json").read_text(encoding="utf-8"))
tpl = (here / "highschool_simulator.template.html").read_text(encoding="utf-8")
(here / "highschool_simulator.html").write_text(tpl.replace("__DATA__", json.dumps(data, ensure_ascii=False)), encoding="utf-8")
print("built", len(data), "schools")
