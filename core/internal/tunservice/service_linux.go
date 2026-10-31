package tunservice

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/tunapi"
)

// InstallDir is the installed service's folder.
const InstallDir = "/opt/firefox-vpn-tun"

const unitName = tunapi.ServiceName + ".service"

// unit is the service's systemd unit. Restart=always starts it again after
// a crash and after an update (which ends it); an uninstall stops it for
// good (stopForGood). The unit is never enabled, so systemd never starts
// it with the computer: it runs only when the app starts it, on the TUN
// mode being chosen (StartInstalled). The [Install] section stays, so a
// person who wants the old behavior can still enable it by hand — the
// app's own starts take that enablement off again (register,
// StartInstalled, MakeManual).
const unit = `[Unit]
Description=Firefox VPN TUN
Documentation=https://github.com/armanlife/firefox-vpn-client
After=network.target

[Service]
Type=simple
ExecStart=%s service
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
`

// initSystemPresent: the service needs systemd as the init system.
func initSystemPresent() error {
	if _, err := os.Stat("/run/systemd/system"); err != nil {
		return errors.New("the TUN mode needs systemd, which does not run this system")
	}
	if _, err := exec.LookPath("systemctl"); err != nil {
		return errors.New("the TUN mode needs systemd's systemctl, which is not found")
	}
	return nil
}

// register writes the unit for the executable exe, then starts it. The
// unit is not enabled — no start with the computer — and an enablement
// an earlier version left is taken off.
func register(exe string) error {
	if err := replaceFile(tunapi.ServiceFile, []byte(fmt.Sprintf(unit, systemdQuote(exe))), 0o644); err != nil {
		return err
	}
	if err := run("systemctl", "daemon-reload"); err != nil {
		return err
	}
	if err := run("systemctl", "disable", unitName); err != nil {
		return err
	}
	return run("systemctl", "restart", unitName)
}

// StartInstalled starts the installed service and waits until it
// answers, taking any start-at-boot enablement off first. It needs
// root.
func StartInstalled() error {
	if err := run("systemctl", "disable", unitName); err != nil {
		return err
	}
	if err := run("systemctl", "start", unitName); err != nil {
		return err
	}
	return waitForService(15 * time.Second)
}

// MakeManual takes the unit out of the start-at-boot list and stops the
// service, so it no longer runs from the computer's start on. It needs
// root.
func MakeManual() error {
	if err := run("systemctl", "disable", unitName); err != nil {
		return err
	}
	return stopInstalled()
}

// unregister disables the unit and removes it; it does not stop the
// service, which may be the caller.
func unregister() error {
	if installed, _ := tunapi.Installed(); !installed {
		return nil
	}
	_ = run("systemctl", "disable", unitName)
	if err := os.Remove(tunapi.ServiceFile); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return run("systemctl", "daemon-reload")
}

// stopInstalled stops the installed service and waits for it.
func stopInstalled() error {
	if installed, _ := tunapi.Installed(); !installed {
		return nil
	}
	return run("systemctl", "stop", unitName)
}

// stopForGood has systemd stop the service, whose unit is removed, so it is
// not started again when this process ends.
func stopForGood() {
	_ = run("systemctl", "--no-block", "stop", unitName)
}

// systemdQuote quotes a path for ExecStart: in double quotes, with
// backslash and double quote escaped, and the specifier and variable signs
// doubled.
func systemdQuote(path string) string {
	out := []byte{'"'}
	for i := 0; i < len(path); i++ {
		switch c := path[i]; c {
		case '\\', '"':
			out = append(out, '\\', c)
		case '%', '$':
			out = append(out, c, c)
		default:
			out = append(out, c)
		}
	}
	return string(append(out, '"'))
}
