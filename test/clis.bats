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

@test "installs formulas in one call, the cask in another" {
  in_lib 'aws gcloud gh' 'clis_install'
  [ "$status" -eq 0 ]
  [ "$(installs)" = "brew install awscli gh
brew install --cask gcloud-cli" ]
  [[ "$output" == *"✓ Cloud CLIs are installed"* ]]
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

@test "homebrew/core's terraform doesn't count" {
  mkdir -p "$P/Cellar/terraform"
  in_lib terraform 'clis_install'
  [ "$status" -eq 0 ]
  [ "$(installs)" = "brew install hashicorp/tap/terraform" ]
  in_lib terraform 'clis_where installed terraform'
  [ "$status" -eq 0 ]
  [ "$output" = terraform ]
}

@test "all present: no brew install" {
  mkdir -p "$P/Cellar/gh" "$P/Caskroom/gcloud-cli"
  in_lib 'gh gcloud' 'clis_install'
  [ "$status" -eq 0 ]
  [ -z "$(installs)" ]
  [[ "$output" == *"✓ Cloud CLIs are installed"* ]]
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
  in_lib '' 'clis_what azure; clis_what terraform; clis_what gcloud'
  [ "$output" = "azure-cli
hashicorp/tap/terraform
the gcloud-cli cask" ]
}

@test "brew can't list: fails, installs nothing" {
  T_BREW_LIST_FAIL=1 in_lib gh 'clis_install'
  [ "$status" -ne 0 ]
  [ -z "$(installs)" ]
  [[ "$output" != *"Cloud CLIs are installed"* ]]
}

@test "brew tap fails: fails, installs nothing" {
  T_BREW_TAP_FAIL=1 in_lib terraform 'clis_install'
  [ "$status" -ne 0 ]
  [ -z "$(installs)" ]
  [[ "$output" != *"Cloud CLIs are installed"* ]]
}
