package service

import (
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/armanlife/arman-vpn-client/core/internal/evasion"
)

func TestParseRelayNodesKeepsOnlyUsableEntries(t *testing.T) {
	raw := json.RawMessage(`{"nodes":[
		{"id":"ok","kind":"worker","url":"https://good.example/","weight":7},
		{"id":"front","kind":"appsscript","url":"https://script.google.com/macros/s/X/exec"},
		{"id":"plain","kind":"worker","url":"http://plain.example/"},
		{"id":"creds","kind":"worker","url":"https://u:p@bad.example/"},
		{"id":"frag","kind":"worker","url":"https://bad.example/#x"},
		{"id":"preset-url","kind":"worker","url":"https://bad.example/?url=x"},
		{"id":"preset-token","kind":"worker","url":"https://bad.example/?t=x"},
		{"id":"preset-stamp","kind":"worker","url":"https://bad.example/?ts=1"},
		{"id":"preset-envelope","kind":"worker","url":"https://bad.example/?e=1"},
		{"id":"unknown-kind","kind":"carrier-pigeon","url":"https://bad.example/"},
		{"id":"dup","kind":"worker","url":"https://good.example/"},
		{"kind":"worker","url":"https://named-after-host.example/"}
	]}`)
	nodes := parseRelayNodes(raw)
	var ids []string
	for _, node := range nodes {
		ids = append(ids, node.id)
	}
	want := []string{"ok", "front", "named-after-host.example"}
	if strings.Join(ids, ",") != strings.Join(want, ",") {
		t.Fatalf("nodes %v, want %v", ids, want)
	}
	if nodes[0].weight != 7 || nodes[1].weight != 1 {
		t.Fatalf("weights %d/%d", nodes[0].weight, nodes[1].weight)
	}
	if nodes[0].envelope() || !nodes[1].envelope() {
		t.Fatal("the kind must decide the shape")
	}
	for _, empty := range []json.RawMessage{nil, json.RawMessage(`"text"`), json.RawMessage(`{}`)} {
		if got := parseRelayNodes(empty); got != nil {
			t.Fatalf("%s produced %v", empty, got)
		}
	}
}

// A fronted node cannot carry headers or a status code, so everything the
// target said has to survive inside the envelope instead.
func TestEnvelopeNodeCarriesTheTargetThroughAFront(t *testing.T) {
	evasion.Register(stubProfile{})
	t.Cleanup(func() { evasion.Register(nil) })

	var sawMethod, sawTarget, sawToken, sawAuth string
	var redirected bool
	var answer []byte
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Mimics Apps Script: the script reads the body and does the work,
		// then answers 302 to its content host, which only serves the
		// result. So the client must follow the redirect, and the body is
		// consumed before it rather than resent.
		if r.URL.Path == "/exec" {
			sawMethod = r.URL.Query().Get("m")
			sawTarget = r.URL.Query().Get("url")
			sawToken = r.URL.Query().Get("t")
			var sent struct {
				Headers map[string]string `json:"h"`
				Body    string            `json:"b"`
			}
			if err := json.NewDecoder(r.Body).Decode(&sent); err != nil {
				t.Errorf("request envelope: %v", err)
			}
			sawAuth = sent.Headers["authorization"]
			body, _ := base64.StdEncoding.DecodeString(sent.Body)
			if string(body) != `{"ask":1}` {
				t.Errorf("upstream body lost: %q", body)
			}
			answer, _ = json.Marshal(map[string]any{
				"s": 200,
				"h": map[string]string{"content-type": "application/json", "x-quota-remaining": "4000"},
				"b": base64.StdEncoding.EncodeToString([]byte(`{"token":"through-the-front"}`)),
			})
			redirected = true
			http.Redirect(w, r, "/echo", http.StatusFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write(answer)
	}))
	t.Cleanup(server.Close)

	node := relayNode{id: "front", kind: relayKindEnvelope, url: mustURL(t, server.URL+"/exec"), weight: 1}
	transport := &relayPoolTransport{node: node, base: server.Client().Transport}

	target := "https://vpn.mozilla.org/api/v1/fpn/token"
	req, err := http.NewRequest(http.MethodPost, target, strings.NewReader(`{"ask":1}`))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Authorization", "Bearer fixture")
	resp, err := transport.RoundTrip(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	if !redirected {
		t.Fatal("the front's redirect was not exercised")
	}
	if sawMethod != http.MethodPost || sawTarget != target {
		t.Fatalf("method/target %q %q", sawMethod, sawTarget)
	}
	if sawToken != stubToken(http.MethodPost, target) {
		t.Fatal("the proof was not bound to the real method and target")
	}
	if sawAuth != "Bearer fixture" {
		t.Fatalf("the account credential did not reach the target: %q", sawAuth)
	}
	if resp.StatusCode != 200 || resp.Header.Get("X-Quota-Remaining") != "4000" {
		t.Fatalf("unwrapped %d quota=%q", resp.StatusCode, resp.Header.Get("X-Quota-Remaining"))
	}
	// The envelope itself proves the origin, so the same check serves both
	// shapes further up.
	if resp.Header.Get("X-Arman-Relay") != "1" {
		t.Fatal("the unwrapped response was not marked as relayed")
	}
	body, _ := io.ReadAll(resp.Body)
	if string(body) != `{"token":"through-the-front"}` {
		t.Fatalf("body %q", body)
	}
	if !usableGuardianRelayResponse(req, resp) {
		t.Fatal("the unwrapped response should be usable")
	}
}

// A front answers 200 with nothing when the Worker refused, because it can
// pass neither a status nor a header through. That must read as a dead node.
func TestEnvelopeNodeTreatsAnUnusableAnswerAsFailure(t *testing.T) {
	evasion.Register(stubProfile{})
	t.Cleanup(func() { evasion.Register(nil) })

	for _, answer := range []struct {
		name string
		body string
	}{
		{"empty", ""},
		{"whitespace", "   \n"},
		{"not json", "<html>sorry</html>"},
		{"no status", `{"h":{},"b":""}`},
		{"absurd status", `{"s":7,"h":{},"b":""}`},
		{"unreadable body", `{"s":200,"h":{},"b":"!!!not base64!!!"}`},
	} {
		t.Run(answer.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				io.WriteString(w, answer.body)
			}))
			defer server.Close()
			node := relayNode{id: "front", kind: relayKindEnvelope, url: mustURL(t, server.URL), weight: 1}
			req, _ := http.NewRequest(http.MethodGet, "https://vpn.mozilla.org/api/v1/fpn/token", nil)
			resp, err := (&relayPoolTransport{node: node, base: server.Client().Transport}).RoundTrip(req)
			if err == nil {
				resp.Body.Close()
				t.Fatal("an unusable answer must be an error, not a response")
			}
		})
	}
}

// Without a profile that can authorize, nothing may be sent at all.
func TestRelayPoolRefusesWhenTheBuildCannotAuthorize(t *testing.T) {
	evasion.Register(nil)
	var reached bool
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { reached = true }))
	t.Cleanup(server.Close)
	for _, kind := range []string{relayKindWorker, relayKindEnvelope} {
		node := relayNode{id: "n", kind: kind, url: mustURL(t, server.URL), weight: 1}
		transport := &relayPoolTransport{node: node, base: server.Client().Transport}
		if _, ok := transport.probeURL(); ok {
			t.Fatalf("%s: a probe was authorized without a profile", kind)
		}
		req, _ := http.NewRequest(http.MethodGet, "https://vpn.mozilla.org/api/v1/fpn/token", nil)
		if _, err := transport.RoundTrip(req); err == nil {
			t.Fatalf("%s: a request was sent without a profile", kind)
		}
	}
	if reached {
		t.Fatal("an unauthorized build still reached the relay")
	}
}

func mustURL(t *testing.T, raw string) *url.URL {
	t.Helper()
	u, err := url.Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	return u
}
