package config

import (
	"os"
	"path/filepath"
	"testing"
)

// This fork kept the program's name across upstream 1.0.9, so the data
// folder of the fork's 1.0.8-based builds and of this build are the same
// folder: MoveLegacyDataDir must leave an existing data folder, with its
// accounts and settings, exactly where and how it is, and must not create
// or move anything when there is no folder.
func TestTheForkDataFolderStaysInPlace(t *testing.T) {
	for _, name := range []string{AppFolder, linuxDataFolder} {
		base := t.TempDir()
		dir := filepath.Join(base, name)
		os.MkdirAll(filepath.Join(dir, "accounts"), 0o700)
		os.WriteFile(filepath.Join(dir, "config.json"), []byte("{}"), 0o600)
		MoveLegacyDataDir(dir)
		if got, err := os.ReadFile(filepath.Join(dir, "config.json")); err != nil || string(got) != "{}" {
			t.Fatalf("%s: data folder changed: %v %q", name, err, got)
		}
		if _, err := os.Stat(filepath.Join(dir, "accounts")); err != nil {
			t.Fatalf("%s: accounts folder gone: %v", name, err)
		}
		// No folder yet: nothing is made or moved.
		empty := t.TempDir()
		MoveLegacyDataDir(filepath.Join(empty, name))
		if _, err := os.Stat(filepath.Join(empty, name)); !os.IsNotExist(err) {
			t.Fatalf("%s: folder made from nothing: %v", name, err)
		}
	}
	// A folder the map does not name (a portable copy's user-data beside
	// the app) is never touched.
	base := t.TempDir()
	os.MkdirAll(filepath.Join(base, AppFolder), 0o700)
	MoveLegacyDataDir(filepath.Join(base, DataDirName))
	if _, err := os.Stat(filepath.Join(base, DataDirName)); !os.IsNotExist(err) {
		t.Fatalf("user-data was made: %v", err)
	}
	if _, err := os.Stat(filepath.Join(base, AppFolder)); err != nil {
		t.Fatalf("the other folder was moved: %v", err)
	}
}
