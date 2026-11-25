# 与 trader-plan2 的对应关系

| 生成文件 | trader-plan2 对应 | 剥掉了什么 |
| --- | --- | --- |
| AGENTS.md | AGENTS.md | QTV 品牌、主机、交易所凭据规则、子目录 AGENTS |
| ENVIRONMENTS.md | ENVIRONMENTS.md | 43.106.83.160、/var/www、数据库名 |
| STATUS.md | STATUS.md | 具体阶段与里程碑编号 |
| README.md | README.md | 24 篇 spec 的固定清单 |
| docs/spec/README.md | docs/spec/conventions.md + spec 地图 | 前端与后端的业务规则 |
| docs/decisions/D-001.md | docs/decisions/D-01..D-93 | 业务口径与历史编号 |
| docs/evidence/README.md | docs/evidence/ | 验收、压测、联调记录 |
| tools/env.sh | tools/env.sh | .qtv-env、APP_ENV、host 映射，改为 env 三键 |
| tools/check-links.sh | tools/check-links.sh | 特定排除目录 |
| 子目录 AGENTS | web/AGENTS.md | 不生成；模板 §8 明确不设 |