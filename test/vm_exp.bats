#!/usr/bin/env bats
# test/vm.exp against a fake ssh that asks for the password a set number of times.

load helpers/common

setup() {
  setup_sandbox
  # shellcheck disable=SC2016 # the stub expands these itself
  stub ssh 'n=${T_PROMPTS:-1}
while [ "$n" -gt 0 ]; do printf "Password:"; read -r _; n=$((n - 1)); done
[ -z "${T_SIZE:-}" ] || echo "size:$(stty size)"
if [ -n "${T_INSTALL:-}" ]; then
  i=$T_INSTALL
  while [ "$i" -gt 0 ]; do printf "Install?\n"; i=$((i - 1)); done
  read -r -n1 k; echo "got:$k"
  if read -r -t 2 -n1 extra; then echo "extra:$extra"; fi
fi
if [ -n "${T_REMOVE:-}" ]; then
  IFS="|" read -ra texts <<< "$T_REMOVE"
  last=""
  for t in "${texts[@]}"; do
    printf "%s\n" "$t"
    # a repeat is a redraw: gum reads no new key for it
    [ "$t" != "$last" ] || continue
    last=$t
    read -r -n1 k; echo "got:$k"
  done
  if read -r -t 2 -n1 extra; then echo "extra:$extra"; fi
fi
if [ -n "${T_ASK:-}" ]; then printf "%s " "$T_ASK"; read -r _; fi
[ -z "${T_KILL:-}" ] || kill -TERM $$
exit "${T_EXIT:-0}"'
  export OMAMAC_VM_TIMEOUT=10
}

vm_exp() { run /usr/bin/expect -f "$REPO_ROOT/test/vm.exp" 192.0.2.1 true; }

@test "one password prompt is answered" {
  vm_exp
  [ "$status" -eq 0 ]
}

@test "passes on the command's exit status" {
  T_EXIT=3 vm_exp
  [ "$status" -eq 3 ]
}

@test "a second password prompt fails by default" {
  T_PROMPTS=2 vm_exp
  [ "$status" -eq 1 ]
  [[ "$output" == *"asked for a password 2 times"* ]]
}

@test "OMAMAC_VM_MAX_PASSWORDS raises the limit" {
  T_PROMPTS=2 OMAMAC_VM_MAX_PASSWORDS=2 vm_exp
  [ "$status" -eq 0 ]
  T_PROMPTS=3 OMAMAC_VM_MAX_PASSWORDS=2 vm_exp
  [ "$status" -eq 1 ]
}

@test "a timeout or password limit that isn't a number stops first" {
  OMAMAC_VM_MAX_PASSWORDS=two vm_exp
  [ "$status" -eq 2 ]
  [[ "$output" == *"OMAMAC_VM_MAX_PASSWORDS must be a whole number, not 'two'"* ]]
  [[ "$output" != *"Password:"* ]]
  OMAMAC_VM_TIMEOUT=10m vm_exp
  [ "$status" -eq 2 ]
  [[ "$output" == *"OMAMAC_VM_TIMEOUT must be a whole number, not '10m'"* ]]
}

@test "a command killed by a signal fails" {
  T_KILL=1 vm_exp
  [ "$status" -eq 1 ]
}

@test "the terminal has a size, so gum draws" {
  T_SIZE=1 vm_exp
  [ "$status" -eq 0 ]
  [[ "$output" == *"size:50 120"* ]]
}

@test "Install? is answered with one y, redraws ignored" {
  T_INSTALL=2 vm_exp
  [ "$status" -eq 0 ]
  [[ "$output" == *"got:y"* ]]
  [[ "$output" != *"extra:"* ]]
}

@test "any other y/n prompt still fails" {
  T_ASK='Continue? (y/n)' vm_exp
  [ "$status" -eq 1 ]
  [[ "$output" == *"unexpected prompt"* ]]
}

@test "each Remove …? prompt is answered once" {
  T_REMOVE='Remove Go?|Remove Go?|Remove Rust?' vm_exp
  [ "$status" -eq 0 ]
  [ "$(grep -c 'got:y' <<< "$output")" -eq 2 ]
  [[ "$output" != *"extra:"* ]]
}

@test "each take-over and settings-and-data prompt is answered once" {
  T_REMOVE="Let Homebrew take over VLC?|Let Homebrew take over VLC?|Also remove VLC's settings and data?|Remove VLC?" vm_exp
  [ "$status" -eq 0 ]
  [ "$(grep -c 'got:y' <<< "$output")" -eq 3 ]
  [[ "$output" != *"extra:"* ]]
}
