# 002 - JIRA管理 実装結果

## 実装完了日
2026-03-29

## 結果サマリー

`002-jira-management-impl.md` の設計通りに実装完了。
Phase 1 のJIRAチケット（Epic 1件 + Task 12件）の作成・紐づけまで完了。

---

## 実装内容

### スクリプト一覧

| ファイル | 状態 | 備考 |
|---|---|---|
| `scripts/jira/config.sh` | ✅ 完了 | JIRA_BASE_URL / JIRA_PROJECT_KEY 定義 |
| `scripts/jira/config.local.sh.example` | ✅ 完了 | 認証情報テンプレート |
| `scripts/jira/common.sh` | ✅ 完了 | 共通関数（認証・API呼び出し・種別取得） |
| `scripts/jira/issues/get-issue-types.sh` | ✅ 完了 | Issue種別一覧取得 |
| `scripts/jira/issues/create-issue.sh` | ✅ 完了 | チケット作成（ADF形式・ステータス遷移） |
| `scripts/jira/issues/get-issue.sh` | ✅ 完了 | チケット参照 |
| `scripts/jira/issues/link-task-to-epic.sh` | ✅ 完了 | EpicへのTask紐づけ（parentフィールド） |
| `scripts/jira/create-phase-tickets.sh` | ✅ 完了 | Phase単位の一括チケット作成 |
| `data/jira/phase1-tickets.yaml` | ✅ 完了 | Phase 1 チケット定義 |

### Phase 1 JIRAチケット

| キー | 種別 | タイトル | 状態 |
|---|---|---|---|
| SA-1 | エピック | Phase 1: CLIエージェントエンジン基盤構築 | ToDo |
| SA-2 | タスク | Task 1: 環境構築（pyenv + poetry + pyproject.toml） | ToDo |
| SA-3 | タスク | Task 2: 設定管理（src/config/settings.py） | ToDo |
| SA-4 | タスク | Task 3: Embeddingsモジュール（src/memory/embeddings.py） | ToDo |
| SA-5 | タスク | Task 4: データベース基盤（src/tools/database.py） | ToDo |
| SA-6 | タスク | Task 5: Short-termメモリ（src/memory/short_term.py） | ToDo |
| SA-7 | タスク | Task 6: Long-termメモリ（src/memory/long_term.py） | ToDo |
| SA-8 | タスク | Task 7: MemoryManager（src/memory/manager.py） | ToDo |
| SA-9 | タスク | Task 8: BaseAgent（src/agents/base.py） | ToDo |
| SA-10 | タスク | Task 9: GeneralAgent（src/agents/general_agent.py） | ToDo |
| SA-11 | タスク | Task 10: Router（src/orchestrator/router.py） | ToDo |
| SA-12 | タスク | Task 11: Orchestratorグラフ（src/orchestrator/graph.py） | ToDo |
| SA-13 | タスク | Task 12: CLIインターフェース（src/interface/cli.py） | ToDo |

全タスク（SA-2〜SA-13）が SA-1（エピック）の子として紐づけ済み。

---

## 実装中に発生した問題と対応

### 問題1: `createmeta` エンドポイントがエピックを返さない

**原因:** JIRA Cloud の `createmeta` エンドポイントはエピック・サブタスクを返さない制限がある。

**対応:** Issue種別取得を `createmeta` から `/project/{key}` エンドポイントに変更。全種別（エピック・サブタスク含む）が正しく取得できるようになった。

### 問題2: Issue種別名が日本語

**原因:** プロジェクト SA の Issue種別名はすべて日本語（タスク・バグ・ストーリー・エピック・サブタスク）。

**対応:** スクリプト内の Issue種別指定を日本語名に統一。

### 問題3: Epicへの親子リンク失敗

**原因:** SA-1 をストーリーとして作成したため、タスクの親に設定できなかった（ストーリー→タスクの親子関係は JIRA 階層上サポートされない）。

**対応:**
1. SA-1 の Issue種別をエピックに変更
2. `link-task-to-epic.sh` を `parent` フィールドによる正式な親子関係に変更（フォールバックとして issueLink Relates を保持）

---

## 完了基準の達成状況

- [x] `./scripts/jira/issues/get-issue-types.sh SA` でIssue種別一覧が取得できる
- [x] `./scripts/jira/create-phase-tickets.sh 1` でPhase 1の Epic + 12 Tasks が作成される
- [x] 全TaskがJIRA上でEpicに紐づいている（parent フィールドによる親子関係）
- [x] `config.local.sh` が Git にコミットされていない（`git status` で表示されない）
