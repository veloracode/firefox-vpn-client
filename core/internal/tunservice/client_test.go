package tunservice

import (
	"testing"

	"github.com/armanlife/firefox-vpn-client/core/internal/tunapi"
)

// TestManualForUserWithoutAService: with no service installed, taking it
// out of the start-at-boot list (what Setup runs after an update) is
// done at once — in particular it asks for no administrator rights,
// which running this test unprivileged proves: an elevated copy would
// fail or prompt here.
func TestManualForUserWithoutAService(t *testing.T) {
	if installed, err := tunapi.Installed(); err != nil || installed {
		t.Skip("a TUN service is installed on this computer")
	}
	if err := ManualForUser(""); err != nil {
		t.Fatalf("ManualForUser with no service installed: %v", err)
	}
	if serviceRunning() {
		t.Fatal("the service answers, but no service is installed")
	}
}
