load helpers/common

bats_require_minimum_version 1.5.0

setup() {
  setup_sandbox
  install_fake_brew
  export OMAMAC_LOG="$BATS_TEST_TMPDIR/omamac.log"
  P="$OMAMAC_TEST_BREW_PREFIX"
  : > "$STUB_LOG"
}

# in_lib <cloud_clis> <code>: run bash 5 code with the CLI step loaded
# and CHOICES[cloud_clis] set to <cloud_clis>.
in_lib() {
  run "$BASH5" -c "set -Eeuo pipefail
    for f in paths ui questions choices clis; do source '$REPO_ROOT/lib/'\$f.sh; done
    CHOICES[cloud_clis]='$1'
    $2"
}

installs() { grep '^brew install' "$STUB_LOG" || true; }

@test "azure installs as a cask" {
  in_lib 'azure' 'clis_install'
  [ "$status" -eq 0 ]
  [ "$(installs)" = "brew install --cask azure-cli" ]
}

@test "installs formulas in one call, the cask in another" {
  in_lib 'aws gcloud gh' 'clis_install'
  [ "$status" -eq 0 ]
  [ "$(installs)" = "brew install awscli gh
brew install --cask gcloud-cli" ]
  [[ "$output" == *"✓ Your CLIs are installed"* ]]
}

@test "terraform: taps first, only when not tapped" {
  in_lib terraform 'clis_install'
  [ "$status" -eq 0 ]
  [ "$(grep -v '^brew list' "$STUB_LOG")" = "brew tap
brew tap hashicorp/tap
brew install hashicorp/tap/terraform" ]
  : > "$STUB_LOG"
  in_lib terraform 'clis_install'
  [ "$status" -eq 0 ]
  run ! grep -q 'brew tap hashicorp/tap' "$STUB_LOG"
  [ -z "$(installs)" ]
}

@test "no terraform chosen: never taps" {
  in_lib 'gh aws' 'clis_install'
  [ "$status" -eq 0 ]
  run ! grep -q '^brew tap' "$STUB_LOG"
}

@test "homebrew/core's terraform doesn't count, and stops the install" {
  mkdir -p "$P/Cellar/terraform"
  in_lib 'gh terraform' 'clis_install'
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ Terraform from homebrew/core is installed, and omamac installs HashiCorp's. Fix: brew uninstall terraform, then run omamac update."* ]]
  [ -z "$(installs)" ]
  run ! grep -q '^brew tap' "$STUB_LOG"
  in_lib terraform 'clis_where missing terraform'
  [ "$status" -eq 0 ]
  [ "$output" = terraform ]
}

@test "fake brew refuses a same-name formula from another tap" {
  mkdir -p "$P/Cellar/terraform"
  run "$P/bin/brew" install hashicorp/tap/terraform
  [ "$status" -eq 1 ]
}

@test "all present: no brew install" {
  mkdir -p "$P/Cellar/gh" "$P/Caskroom/gcloud-cli"
  in_lib 'gh gcloud' 'clis_install'
  [ "$status" -eq 0 ]
  [ -z "$(installs)" ]
  [[ "$output" == *"✓ Your CLIs are installed"* ]]
}

@test "clis_where keeps the given order and splits by state" {
  mkdir -p "$P/Cellar/gh" "$P/Caskroom/gcloud-cli"
  in_lib '' 'clis_where installed gcloud aws gh; echo --; clis_where missing gcloud aws gh'
  [ "$status" -eq 0 ]
  [ "$output" = "gcloud
gh
--
aws" ]
}

@test "named CLIs are installed instead of the chosen ones" {
  in_lib gh 'clis_install aws'
  [ "$status" -eq 0 ]
  [ "$(installs)" = "brew install awscli" ]
}

@test "no CLI: no brew call and nothing said" {
  in_lib '' 'clis_install'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -s "$STUB_LOG" ]
}

@test "clis_what names what Homebrew installs" {
  in_lib '' 'clis_what aws; clis_what terraform; clis_what gcloud; clis_what azure'
  [ "$output" = "awscli
hashicorp/tap/terraform
the gcloud-cli cask
the azure-cli cask" ]
}

@test "brew can't list: fails, installs nothing" {
  T_BREW_LIST_FAIL=1 in_lib gh 'clis_install'
  [ "$status" -ne 0 ]
  [ -z "$(installs)" ]
  [[ "$output" != *"CLIs are installed"* ]]
}

@test "brew tap fails: fails, installs nothing" {
  T_BREW_TAP_FAIL=1 in_lib terraform 'clis_install'
  [ "$status" -ne 0 ]
  [ -z "$(installs)" ]
  [[ "$output" != *"CLIs are installed"* ]]
}

@test "coding agents: formulas and casks install beside the cloud CLIs, in one call each" {
  in_lib gh 'CHOICES[coding_agents]="claude-code opencode antigravity-cli"; clis_install'
  [ "$status" -eq 0 ]
  [ "$(installs)" = "brew install gh opencode
brew install --cask claude-code antigravity-cli" ]
  [[ "$output" == *"Installing GitHub CLI, opencode CLI"* ]]
  [[ "$output" == *"Installing Claude Code CLI, Antigravity CLI"* ]]
  [[ "$output" == *"✓ Your CLIs are installed"* ]]
}

@test "clis_chosen, clis_key and clis_label cover both CLI questions" {
  in_lib 'gh aws' 'CHOICES[coding_agents]="opencode"
    echo $(clis_chosen); clis_key opencode; clis_key gh; clis_label antigravity-cli; clis_label gcloud
    clis_key vlc || echo "vlc: $?"'
  [ "$status" -eq 0 ]
  [ "$output" = "gh aws opencode
coding_agents
cloud_clis
Antigravity CLI
Google Cloud CLI
vlc: 1" ]
}

@test "clis_what names each coding agent's formula or cask" {
  in_lib '' 'for id in claude-code antigravity-cli opencode; do clis_what "$id"; done'
  [ "$output" = "the claude-code cask
the antigravity-cli cask
opencode" ]
}

@test "every CLI option has a formula or a cask" {
  in_lib '' 'for key in "${CLI_KEYS[@]}"; do
      for id in $(question_values "$key"); do
        [ -n "${CLI_FORMULA[$id]:-}${CLI_CASK[$id]:-}" ] || echo "no package: $id"
      done
    done'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
