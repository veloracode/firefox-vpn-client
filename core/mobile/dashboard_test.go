package mobile

import (
	"net"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/armanlife/arman-vpn-client/core/internal/config"
	"github.com/armanlife/arman-vpn-client/core/internal/service"
)

func TestDashboardStartsWithConfiguredPortTaken(t *testing.T) {
	// Model another profile already holding the configured loopback port.
	other, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer other.Close()

	paths, err := service.ResolveDataPaths(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	cfg := config.Default()
	cfg.Dashboard.Listen = other.Addr().String()
	if err := config.Save(filepath.Join(paths.Dir, config.FileName), cfg); err != nil {
		t.Fatal(err)
	}
	if err := Start(paths.Dir, false); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(Stop)

	var addr string
	for deadline := time.Now().Add(5 * time.Second); time.Now().Before(deadline); {
		if addr = DashboardAddress(); addr != "" || !Running() {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	host, port, err := net.SplitHostPort(addr)
	if err != nil || host != "127.0.0.1" || port == "0" || addr == cfg.Dashboard.Listen {
		t.Fatalf("got dashboard address %q, error %v; last startup error: %s", addr, err, LastError())
	}

	token, err := os.ReadFile(paths.LocalToken)
	if err != nil {
		t.Fatal(err)
	}
	client := &http.Client{Timeout: 2 * time.Second, Transport: &http.Transport{}}
	defer client.CloseIdleConnections()
	for _, want := range []int{http.StatusUnauthorized, http.StatusOK} {
		req, err := http.NewRequest(http.MethodGet, "http://"+addr+"/api/status", nil)
		if err != nil {
			t.Fatal(err)
		}
		if want == http.StatusOK {
			req.Header.Set("X-Local-Token", string(token))
		}
		res, err := client.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
		if res.StatusCode != want {
			t.Fatalf("status %d, want %d", res.StatusCode, want)
		}
	}
}
