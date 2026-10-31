package tunservice

import (
	"bytes"
	"encoding/xml"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/tunapi"
)

// InstallDir is the installed service's folder.
const InstallDir = "/Library/Application Support/Firefox VPN TUN"

// jobTarget is the service in launchctl's commands.
const jobTarget = "system/" + tunapi.LaunchdLabel

// job is the service's launchd job: loaded at boot but NOT started then
// (RunAtLoad is false) — it starts only when the app asks, on the TUN
// mode being chosen (StartInstalled, a launchctl kickstart) — and from
// then on again whenever it ends (after a crash, and after an update,
// which ends it); an uninstall boots it out (stopForGood).
const job = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>%s</string>
	<key>ProgramArguments</key>
	<array>
		<string>%s</string>
		<string>service</string>
	</array>
	<key>RunAtLoad</key>
	<false/>
	<key>KeepAlive</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>2</integer>
</dict>
</plist>
`

func initSystemPresent() error { return nil }

// register writes the job for the executable exe, loads it, and starts
// it: loading does not start it (the job does not run at load), so it is
// kicked off here, which installing it was asked for.
func register(exe string) error {
	if err := replaceFile(tunapi.ServiceFile, []byte(fmt.Sprintf(job, tunapi.LaunchdLabel, xmlText(exe))), 0o644); err != nil {
		return err
	}
	// A job that was disabled (launchctl disable) does not load.
	_ = run("launchctl", "enable", jobTarget)
	var err error
	for range 5 {
		if err = run("launchctl", "bootstrap", "system", tunapi.ServiceFile); err == nil || loaded() {
			break
		}
		time.Sleep(time.Second)
	}
	if !loaded() {
		return err
	}
	return run("launchctl", "kickstart", jobTarget)
}

// StartInstalled starts the installed service and waits until it
// answers: it loads the job first when launchd does not have it, then
// kicks it off. It needs root.
func StartInstalled() error {
	if !loaded() {
		if err := run("launchctl", "bootstrap", "system", tunapi.ServiceFile); err != nil && !loaded() {
			return err
		}
	}
	if err := run("launchctl", "kickstart", jobTarget); err != nil {
		return err
	}
	return waitForService(15 * time.Second)
}

// MakeManual rewrites the job's file as this version writes it — not
// started at load, where an earlier version started it at boot — and
// unloads the job, which stops the service. It needs root.
func MakeManual() error {
	exe := filepath.Join(InstallDir, tunapi.ExeName)
	if err := replaceFile(tunapi.ServiceFile, []byte(fmt.Sprintf(job, tunapi.LaunchdLabel, xmlText(exe))), 0o644); err != nil {
		return err
	}
	return stopInstalled()
}

// unregister removes the job's file; it does not stop the service, which
// may be the caller.
func unregister() error {
	if err := os.Remove(tunapi.ServiceFile); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

// stopInstalled unloads the job, which stops the service, and waits for it.
func stopInstalled() error {
	if !loaded() {
		return nil
	}
	err := run("launchctl", "bootout", jobTarget)
	deadline := time.Now().Add(30 * time.Second)
	for loaded() {
		if time.Now().After(deadline) {
			if err == nil {
				err = errors.New("the service does not stop")
			}
			return err
		}
		time.Sleep(200 * time.Millisecond)
	}
	return nil
}

// stopForGood unloads the job, whose file is removed, so launchd does not
// start it again; launchd ends this process meanwhile (SIGTERM, no longer
// caught).
func stopForGood() {
	signal.Reset(syscall.SIGTERM, syscall.SIGINT)
	_ = run("launchctl", "bootout", jobTarget)
}

// loaded reports whether launchd has the job.
func loaded() bool {
	return exec.Command("launchctl", "print", jobTarget).Run() == nil
}

// xmlText escapes s for a plist's string.
func xmlText(s string) string {
	var b bytes.Buffer
	_ = xml.EscapeText(&b, []byte(s))
	return b.String()
}
