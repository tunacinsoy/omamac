# shellcheck shell=bash # it runs in zsh; shellcheck has no zsh mode
# Runs in the VM before the first run (test/vm.sh), in zsh with -eux and no
# Homebrew yet. It installs VLC by hand, as a user would, from the disk image
# Homebrew's own cask points to.
[[ -x /usr/bin/jq ]]
cask=$(curl -fsSL https://formulae.brew.sh/api/cask/vlc.json)
url=$(/usr/bin/jq -r '.url // empty' <<< "$cask")
sha=$(/usr/bin/jq -r '.sha256 // empty' <<< "$cask")
[[ -n $url && -n $sha ]]
dir=$(mktemp -d)
curl -fsSL "$url" -o "$dir/vlc.dmg"
echo "$sha  $dir/vlc.dmg" | shasum -a 256 -c
mkdir "$dir/mnt"
hdiutil attach -nobrowse -readonly -mountpoint "$dir/mnt" "$dir/vlc.dmg"
ditto "$dir/mnt/VLC.app" /Applications/VLC.app
hdiutil detach "$dir/mnt"
# Test-only: a quarantine like a browser's, so it looks like a real download.
xattr -w com.apple.quarantine "0081;$(printf %x "$(date +%s)");Safari;" /Applications/VLC.app
# The steps check that Homebrew took over this same app, not a new copy.
stat -f %i /Applications/VLC.app > ~/vlc-inode
