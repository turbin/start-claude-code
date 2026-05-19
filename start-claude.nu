# start-claude.nu — Nushell module for starting Claude Code
#
# Usage:
#   use start-claude.nu
#   start-claude
#   start-claude --new
#   start-claude --resume

# Resolve the directory where this module lives
def "private get-script-dir" [] {
    if 'FILE_PWD' in $env {
        $env.FILE_PWD
    } else {
        $env.PWD | into string
    }
}

export def main [
    --new (-n)       # Start a fresh conversation
    --resume (-r)    # Resume the most recent conversation
] {
    let script_dir = (private get-script-dir)

    # Run model-env.nu to set environment variables
    let model_env_path = ($script_dir | path join 'model-env.nu')
    if ($model_env_path | path exists) {
        nu $model_env_path
    }

    # Build command args
    let cmd_args_base = ['--allow-dangerously-skip-permissions']
    let extra_args = if $resume {
        ['--continue']
    } else if $new {
        []
    } else {
        # Interactive picker
        let project_key = ($script_dir | str replace --all '/' '-' | str replace '^-' '-')
        let project_dir = ($nu.home-dir | path join '.claude' 'projects' $project_key)

        if ($project_dir | path exists) {
            let session_count = (try { ls ($project_dir | path join '*.jsonl') | length } catch { 0 })

            if $session_count > 0 {
                print ''
                print '  [1] New session (default)'
                print '  [2] Resume latest'
                print '  [3] Pick session...'
                print ''
                let choice = (input '  Choice (Enter=1): ')
                if $choice == '2' {
                    ['--continue']
                } else if $choice == '3' {
                    ['--resume']
                } else {
                    []
                }
            } else {
                []
            }
        } else {
            []
        }
    }

    let cmd_args = ($cmd_args_base | concat $extra_args)

    # Launch Claude Code
    ^claude ...$cmd_args
}
