# model-env.nu — Nushell module: auto-detect the current model, fix settings.json
# if polluted, and export Claude Code environment variables tuned for that model.
#
# Usage:
#   source model-env.nu
#   model-env                 # detect from settings.json / models.json default
#   model-env qwen3.6-plus    # override with explicit model

export def "private log" [...msgs: string] {
    let tag = "[model-env]"
    print -e ($tag + " " + ($msgs | str join " "))
}

export def "private warn" [...msgs: string] {
    let tag = "[model-env]"
    print -e ($tag + " ⚠ " + ($msgs | str join " "))
}

# Model registry: reads from models.json
export def "private get-model-config" [model: string, script_dir: string] {
    let config_file = ($script_dir | path join "models.json")
    if not ($config_file | path exists) {
        return null
    }
    try {
        let data = (open $config_file | from json)
        let model_data = ($data | get -o models | default {} | get -o $model)
        if $model_data == null {
            return null
        }
        return {
            context: ($model_data | get -o context_tokens)
            thinking: ($model_data | get -o max_thinking_tokens)
            base_url: ($model_data | get -o base_url | default "")
            model_id: ($model_data | get -o id | default "")
            api_key_env: ($model_data | get -o api_key_env | default "")
            flags: ($model_data | get -o flags | default "")
        }
    } catch {
        return null
    }
}

# Get default model from models.json
export def "private get-default-model" [script_dir: string] {
    let config_file = ($script_dir | path join "models.json")
    if not ($config_file | path exists) {
        return null
    }
    try {
        let data = (open $config_file | from json)
        $data | get -o default_model
    } catch {
        null
    }
}

# Parse model from settings.json
export def "private parse-model-from-settings" [settings_file: string] {
    try {
        let content = open $settings_file | from json
        let raw = ($content | get -o model | default "")
        if ($raw | is-empty) {
            return null
        }
        let cleaned = $raw | str trim | split row " " | first
        return $cleaned
    } catch {
        return null
    }
}

# Fix polluted model field in settings.json
export def "private fix-polluted-settings" [settings_file: string, model: string] {
    try {
        let content = open $settings_file | from json
        let current = ($content | get -o model | default "")
        if ($current != $model) and ($current | str contains $model) {
            model-env log "Fixing polluted model field in settings.json"
            let prefix = ($current | str substring 0..49 | default "")
            $content | upsert model $model | to json -i 2 | save --force $settings_file
            model-env log $"  Fixed: \"($prefix)...\" → \"($model)\""
        }
    } catch {
        model-env warn $"Failed to fix settings.json"
    }
}

# Main entry point
export def main [model_override: string = ""] {
    # Resolve script directory from module location
    let script_dir = if 'FILE_PWD' in $env {
        $env.FILE_PWD
    } else {
        $env.PWD | into string
    }

    let config_dir = ($env | get -o CLAUDE_CONFIG_DIR | default ($nu.home-dir | path join ".claude"))
    let settings_file = ($config_dir | path join "settings.json")

    # Determine model — only use model_override if it looks like a model name
    let is_action = ["--help", "-h", "help", "new", "-n", "--new", "resume", "-r", "--resume"]
        | any { |x| $model_override == $x or ($model_override | str starts-with "--") }

    let mut model = if ($model_override != "") and (not $is_action) {
        $model_override
    } else {
        if ($settings_file | path exists) {
            parse-model-from-settings $settings_file
        } else {
            null
        }
    }

    # Fallback to default model from models.json
    if ($model | is-empty) {
        let default_model = (get-default-model $script_dir)
        if ($default_model | is-not-empty) {
            model-env log $"No model detected, using default: ($default_model)"
            $model = $default_model
        } else {
            model-env warn "No model detected and no default configured."
            return
        }
    }

    model-env log $"Detected model: ($model)"

    # Look up config from models.json
    let config = get-model-config $model $script_dir

    let mut context = 128000
    let mut thinking = 16000
    let mut base_url = ""
    let mut model_id = ""
    let mut api_key_env = ""

    if ($config != null) {
        model-env log "Matched known model config"
        $context = ($config.context | default 128000)
        $thinking = ($config.thinking | default 16000)
        $base_url = ($config.base_url | default "")
        $model_id = ($config.model_id | default "")
        $api_key_env = ($config.api_key_env | default "")
    } else {
        model-env warn $"Unknown model '($model)', using defaults (context=128k, thinking=16k)"
    }

    # Use model_id as ANTHROPIC_MODEL if present, otherwise use model name
    let anthropic_model = if ($model_id | is-not-empty) { $model_id } else { $model }

    # Fix polluted settings if needed
    if ($settings_file | path exists) {
        fix-polluted-settings $settings_file $model
    }

    # Build and export environment variables
    let mut env_vars = {
        ANTHROPIC_MODEL: $anthropic_model,
        MAX_THINKING_TOKENS: ($thinking | into string),
        CLAUDE_CODE_MAX_CONTEXT_TOKENS: ($context | into string),
    }

    if ($base_url | is-not-empty) {
        $env_vars = ($env_vars | merge { ANTHROPIC_BASE_URL: $base_url })
    }

    if ($api_key_env | is-not-empty) {
        let api_key_value = ($env | get -o $api_key_env | default "")
        if ($api_key_value | is-not-empty) {
            $env_vars = ($env_vars | merge { ANTHROPIC_AUTH_TOKEN: $api_key_value })
            model-env log $"Using API key from ($api_key_env)"
        } else {
            model-env warn $"($api_key_env) is not set — API calls may fail"
        }
    }

    load-env $env_vars

    # Re-enable prompt caching if it was disabled
    if ($env | get -o DISABLE_PROMPT_CACHING | is-not-empty) {
        hide-env DISABLE_PROMPT_CACHING
        model-env log "Re-enabled prompt caching"
    }

    # Summary
    let safe_context = ($context * 80 / 100)
    model-env log "┌──────────────────────────────────────────────┐"
    model-env log $"│ Model:    ($anthropic_model)"
    model-env log $"│ Context:  ($context) tokens (safe: ~($safe_context))"
    model-env log $"│ Thinking: ($thinking) tokens max"
    model-env log "│ Caching:  enabled"
    if ($base_url | is-not-empty) {
        model-env log $"│ Base URL: ($base_url)"
    }
    model-env log "└──────────────────────────────────────────────┘"
}
