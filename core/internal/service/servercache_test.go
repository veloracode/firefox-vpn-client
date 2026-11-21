package service

import (
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/armanlife/arman-vpn-client/core/internal/serverlist"
)

// The server list is saved when it is fetched, shown at once on the next
// start, and used when Mozilla's settings server does not answer.
func TestServerListIsSavedAndUsedOffline(t *testing.T) {
	paths, err := ResolveDataPaths(filepath.Join(t.TempDir(), "data"))
	if err != nil {
		t.Fatal(err)
	}
	online := true
	fetches := 0
	setCoreControlPlane(t, func(r *http.Request) (*http.Response, error) {
		if strings.Contains(r.URL.String(), "vpn-serverlist") {
			fetches++
			if online {
				return coreResponse(r, http.StatusOK, `{"data":[{"name":"Netherlands","code":"NL","cities":[{"name":"Amsterdam","code":"ams","servers":[{"hostname":"nl.example","port":443}]}]}]}`, nil), nil
			}
		}
		return nil, errors.New("offline")
	})

	d, err := NewDaemon(paths, false)
	if err != nil {
		t.Fatal(err)
	}
	if len(d.countries) != 0 {
		t.Fatal("no list saved yet")
	}
	if got := d.refreshLocations(d.config()); len(got) != 1 {
		t.Fatalf("fetched %+v", got)
	}
	cached, _, err := serverlist.LoadCache(paths.ServerList)
	if err != nil {
		t.Fatalf("the fetched list is saved: %v", err)
	}

	// Next start, no network: the saved list, at once and for connecting.
	online = false
	d, err = NewDaemon(paths, false)
	if err != nil {
		t.Fatal(err)
	}
	if len(d.countries) != 1 || d.countries[0].Code != "NL" {
		t.Fatalf("shown at start: %+v", d.countries)
	}
	if got := d.refreshLocations(d.config()); len(got) != 1 || got[0].Cities[0].Servers[0].Hostname != "nl.example" {
		t.Fatalf("offline: %+v", got)
	}
	if fetches != 1 {
		t.Fatalf("fresh cache caused another fetch: %d", fetches)
	}

	stale, err := json.Marshal(struct {
		SavedAt   time.Time            `json:"saved_at"`
		Countries []serverlist.Country `json:"countries"`
	}{time.Now().Add(-serverListFreshFor - time.Second), cached})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(paths.ServerList, stale, 0600); err != nil {
		t.Fatal(err)
	}
	if got := d.refreshLocations(d.config()); len(got) != 1 || fetches != 2 {
		t.Fatalf("stale list not retained after refresh failed: %v, %d fetches", got, fetches)
	}
}
