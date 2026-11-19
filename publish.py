#!/usr/bin/env python3
"""Set name/icon/description (slug comes from the stored name), then publish in Auromations."""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path("~/.claude/skills/create-template-for-railway/scripts").expanduser()))
import rw  # noqa: E402

HERE = pathlib.Path(__file__).parent
WS = "fc4796db-2c6c-4354-a564-d4a1d900af53"
TID = (HERE / "template-id").read_text().strip()
NAME = json.loads((HERE / "template.json").read_text())["name"]
DESC = "AI SRE agent for incident root cause analysis, via HTTP API or Telegram"
ICON = "https://raw.githubusercontent.com/hmseeb/opensre-railway-template/main/assets/icon.png"
assert len(DESC) <= 75 and "—" not in DESC

rw.gql("mutation($id:String!,$i:TemplateUpsertSettingsInput!){templateUpsertSettings(id:$id,input:$i){id}}",
       {"id": TID, "i": {"workspaceId": WS, "name": NAME, "image": ICON, "description": DESC}}, internal=True)
got = rw.gql("query($id:String!){template(id:$id){name}}", {"id": TID})["template"]["name"]
assert got == NAME, got
r = rw.gql("mutation($id:String!,$i:TemplatePublishInput!){templatePublish(id:$id,input:$i){id code status}}",
           {"id": TID, "i": {"workspaceId": WS, "category": "AI/ML", "description": DESC, "image": ICON,
                             "readme": (HERE / "TEMPLATE_OVERVIEW.md").read_text()}})
print(r)
