# start-claude-quick.nu — Start Claude Code with auto-detected model environment
#
# Usage:
#   use start-claude-quick.nu; start-claude-quick          # interactive picker
#   use start-claude-quick.nu; start-claude-quick --new    # fresh conversation
#   use start-claude-quick.nu; start-claude-quick --resume # resume latest
#   start-claude-quick -- --model sonnet                    # pass extra args
#
# Or run directly:
#   nu start-claude-quick.nu --new

source model-env.nu
source model-switch.nu

def main [
    --new (-n),
    --resume (-r),
    --switch: string = "",   # switch model before launching
    --help (-h),
    rest: list<string>  # extra args passed through to claude
] {
    if $help {
        print $"
Usage: start-claude-quick.nu [OPTIONS] [-- EXTRA_ARGS...]

Start Claude Code with auto-detected model environment and session management.

Actions:
  --resume, -r        Resume the most recent conversation
  --new, -n           Start a fresh conversation
  --switch <model>, -s  Switch model then start
  (none)              Interactive picker (new / resume / pick)

Extra args:
  Any arguments after '--' are passed through to claude directly.
  Examples:
    nu start-claude-quick.nu -- --model sonnet
    nu start-claude-quick.nu -- -c 'explain the project structure'
    nu start-claude-quick.nu -- --name 'refactor auth'

Environment:
  Automatically sources model-env.nu to set:
    ANTHROPIC_MODEL            — model from settings.json or models.json
    ANTHROPIC_BASE_URL         — provider base URL from models.json
    ANTHROPIC_AUTH_TOKEN       — API key (via provider env var)
    MAX_THINKING_TOKENS        — model-specific thinking budget
    CLAUDE_CODE_MAX_CONTEXT_TOKENS — model context window

Model switching:
  1. Run: model-switch <model> (updates settings.json)
  2. Run: nu start-claude-quick.nu  (auto-reads new model)
  Or:    nu start-claude-quick.nu --switch deepseek-v4-flash  (one step)
"
        return
    }

    # ── Resolve script directory ──────────────────────────────
    let script_dir = if 'FILE_PWD' in $env {
        $env.FILE_PWD
    } else {
        $env.PWD | into string
    }

    # ── Load model environment variables ──────────────────────
    model-env

    # ── Switch model if requested ─────────────────────────────
    if ($switch | is-not-empty) {
        model-switch $switch
    }

    # ── Determine action ──────────────────────────────────────
    let mut action = if $new {
        "new"
    } else if $resume {
        "resume"
    } else {
        ""
    }

    # Check rest args for action keywords
    let action_args = $rest | where { |a|
        ["resume", "-r", "--resume", "new", "-n", "--new"] | any { |k| $a == $k }
    }
    if ($action == "") and ($action_args | length) > 0 {
        let first = ($action_args | first)
        $action = (match $first {
            "resume" | "-r" | "--resume" => "resume"
            "new" | "-n" | "--new"       => "new"
            _                            => ""
        })
    }

    # ── Auto-prompt when no action specified ──────────────────
    let action_to_use = if ($action == "") {
        let project_key = ($script_dir | str replace --all "/" "-" | str replace "^-" "-")
        let project_dir = ($nu.home-dir | path join ".claude" "projects" $project_key)

        if ($project_dir | path exists) {
            let session_count = (try { ls ($project_dir | path join "*.jsonl") | length } catch { 0 })
            if $session_count > 0 {
                print ""
                print "  [1] New session (default)"
                print "  [2] Resume latest"
                print "  [3] Pick session..."
                print ""
                let choice = (input "  Choice (Enter=1): ")
                match $choice {
                    "2" => "resume"
                    "3" => "pick"
                    _   => "new"
                }
            } else {
                "new"
            }
        } else {
            "new"
        }
    } else {
        $action
    }

    # ── Build claude command args ─────────────────────────────
    let mut claude_args = ["--allow-dangerously-skip-permissions"]

    # Collect extra args (filter out action keywords)
    let extra_args = $rest | where { |a|
        ["resume", "-r", "--resume", "new", "-n", "--new"] | all { |k| $a != $k }
    }
    $claude_args = ($claude_args | concat $extra_args)

    match $action_to_use {
        "resume" => { $claude_args = ($claude_args | push "--continue") }
        "pick"   => { $claude_args = ($claude_args | push "--resume") }
        _        => {}
    }

    # ── Execute claude ────────────────────────────────────────
    ^claude ...$claude_args
}
