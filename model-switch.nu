# model-switch.nu - Nushell script to switch the active Claude Code model
#
# Usage:
#   nu model-switch.nu                  # interactive picker
#   nu model-switch.nu qwen3.6-plus     # switch directly
#   nu model-switch.nu --list           # show available models

source model-env.nu

def main [
    model: string = "",
    --list (-l),
    --help (-h)
] {
    # Resolve script directory
    let script_dir = if 'FILE_PWD' in $env {
        $env.FILE_PWD
    } else {
        $env.PWD | into string
    }

    let config_dir = ($env | get -o CLAUDE_CONFIG_DIR | default ($nu.home-dir | path join ".claude"))
    let settings_file = ($config_dir | path join "settings.json")
    let models_file = ($script_dir | path join "models.json")

    # -- Help --
    if $help {
        print $"
Usage: model-switch.nu [MODEL]

Switch the active Claude Code model.

Arguments:
  MODEL         Model name from models.json (e.g. qwen3.6-plus)
  --list, -l    Show available models and current selection
  --help, -h    Show this help

Examples:
  nu model-switch.nu                    # interactive picker
  nu model-switch.nu qwen3.6-plus       # switch directly
  nu model-switch.nu --list             # show available models
"
        return
    }

    # -- List models --
    if $list {
        if not ($models_file | path exists) {
            print -e "[model-switch] models.json not found at ($models_file)"
            return
        }
        let data = (open $models_file | from json)
        let models = ($data | get -o models | default {})
        let current_model = try {
            if ($settings_file | path exists) {
                open $settings_file | from json | get -o model | default ""
            } else { "" }
        } catch { "" }

        print "Available models in models.json:"
        print ""
        for $model_name in ($models | columns) {
            let cfg = ($models | get $model_name)
            let marker = if $model_name == $current_model { "* " } else { "  " }
            let ctx = ($cfg | get -o context_tokens | default "?")
            let think = ($cfg | get -o max_thinking_tokens | default "?")
            let base = (try { ($cfg.base_url | url parse).host } catch { "?" })
            print $"  ($marker)($model_name)  context=($ctx)  thinking=($think)  [($base)]"
        }
        print ""
        let default_model = ($data | get -o default_model | default "")
        if ($default_model | is-not-empty) {
            print $"  Default model: ($default_model)"
        }
        return
    }

    # -- Validate model exists --
    if not ($models_file | path exists) {
        print -e "[model-switch] models.json not found at ($models_file)"
        return
    }

    # -- Interactive picker if no model specified --
    let model_to_use = if ($model == "") {
        let data = (open $models_file | from json)
        let models = ($data | get -o models | default {})
        let current_model = try {
            if ($settings_file | path exists) {
                open $settings_file | from json | get -o model | default ""
            } else { "" }
        } catch { "" }

        print "Available models:"
        print ""
        let model_names = ($models | columns)
        for $i in 0..($model_names | length - 1) {
            let name = ($model_names | get $i)
            let cfg = ($models | get $name)
            let marker = if $name == $current_model { " (current)" } else { "" }
            let ctx = ($cfg | get -o context_tokens | default "?")
            let think = ($cfg | get -o max_thinking_tokens | default "?")
            print $"  [($i + 1)] ($name)  (context=($ctx), thinking=($think))($marker)"
        }
        print ""
        print "  Enter number to switch, or press Enter to cancel"
        print ""

        let choice = (input "Choice: ")
        let choice_num = ($choice | into int | default 0)
        if $choice_num <= 0 or $choice_num > ($model_names | length) {
            print -e "[model-switch] Invalid choice: ($choice)"
            return
        }
        $model_names | get ($choice_num - 1)
    } else {
        $model
    }

    # Validate model exists
    let models_data = (open $models_file | from json | get -o models | default {})
    if ($model_to_use not-in ($models_data | columns)) {
        print -e $"[model-switch] Unknown model: ($model_to_use)"
        print ""
        model-switch --list
        return
    }

    # Update settings.json
    let cfg = ($nu | get -o config | default {})
    mkdir -p $config_dir

    if ($settings_file | path exists) {
        let content = (open $settings_file | from json)
        let old = ($content | get -o model | default "")
        let new_content = ($content | upsert "model" $model_to_use)
        $new_content | to json -i 2 | save --force $settings_file
        if ($old | is-not-empty) {
            print -e $"[model-switch] Switched: ($old) → ($model_to_use)"
        } else {
            print -e $"[model-switch] Set model: ($model_to_use)"
        }
    } else {
        { "model": $model_to_use } | to json -i 2 | save --force $settings_file
        print -e $"[model-switch] Created settings.json with model: ($model_to_use)"
    }

    # Show model info
    let cfg = ($models_data | get $model_to_use)
    let ctx = ($cfg | get -o context_tokens | default "?")
    let think = ($cfg | get -o max_thinking_tokens | default "?")
    let base = ($cfg | get -o base_url | default "")
    let id = ($cfg | get -o id | default $model_to_use)
    print -e $"[model-switch] id = ($id)"
    print -e $"[model-switch] base_url = ($base)"
    print -e $"[model-switch] context = ($ctx)"
    print -e $"[model-switch] thinking = ($think)"
}
