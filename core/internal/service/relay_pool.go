package service

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"math/rand/v2"
	"net/http"
	"net/url"
	"sort"
	"strings"

	"github.com/armanlife/arman-vpn-client/core/internal/evasion"
)

// Relay kinds. A kind says how to talk to an endpoint, not who runs it.
const (
	// relayKindWorker forwards the request as it is and answers with the
	// target's own response and headers.
	relayKindWorker = "worker"
	// relayKindEnvelope is for an endpoint that can neither carry request
	// headers nor set response headers, and accepts only GET and POST: the
	// upstream method travels in a parameter and both directions are
	// wrapped in JSON. Google Apps Script is the reason it exists.
	relayKindEnvelope = "appsscript"
)

const maxRelayNodes = 100

// relayNode is one endpoint from the manifest.
type relayNode struct {
	id     string
	kind   string
	url    *url.URL
	weight int
}

// envelope reports whether this node needs the wrapped shape.
func (n relayNode) envelope() bool { return n.kind == relayKindEnvelope }

// parseRelayNodes reads the manifest's relay section. An unreadable or
// unknown entry is skipped rather than failing the rest, so a new kind can
// be published before every client understands it. An absent node is a
// disabled node: there is no enabled flag to keep in sync.
func parseRelayNodes(raw json.RawMessage) []relayNode {
	var section struct {
		Nodes []struct {
			ID     string `json:"id"`
			Kind   string `json:"kind"`
			URL    string `json:"url"`
			Weight int    `json:"weight"`
		} `json:"nodes"`
	}
	if len(raw) == 0 || json.Unmarshal(raw, &section) != nil {
		return nil
	}
	var out []relayNode
	seen := map[string]bool{}
	for _, entry := range section.Nodes {
		switch entry.Kind {
		case relayKindWorker, relayKindEnvelope:
		default:
			continue
		}
		u, err := url.Parse(strings.TrimSpace(entry.URL))
		if err != nil || u.Scheme != "https" || u.Hostname() == "" || u.User != nil || u.Fragment != "" {
			continue
		}
		// The client owns these parameters; a manifest must not preset them.
		q := u.Query()
		if q.Has("url") || q.Has("health") || q.Has("ts") || q.Has("t") || q.Has("e") || q.Has("m") {
			continue
		}
		node := relayNode{id: entry.ID, kind: entry.Kind, url: u, weight: entry.Weight}
		if node.weight <= 0 {
			node.weight = 1
		}
		if node.id == "" {
			node.id = u.Hostname()
		}
		if seen[u.String()] {
			continue
		}
		seen[u.String()] = true
		out = append(out, node)
		if len(out) >= maxRelayNodes {
			break
		}
	}
	return out
}

// weightedOrder shuffles nodes so a heavier weight is likelier to come
// first, without ever excluding a lighter one (Efraimidis-Spirakis): each
// node draws a key from its weight and they are sorted by it. A Worker can
// then be preferred over a slower fronted endpoint while that endpoint
// still gets used when the Worker is unreachable.
func weightedOrder(nodes []relayNode, random func() float64) []relayNode {
	out := append([]relayNode(nil), nodes...)
	keys := make(map[string]float64, len(out))
	for _, node := range out {
		r := random()
		if r <= 0 {
			r = math.SmallestNonzeroFloat64
		}
		keys[node.id] = math.Pow(r, 1/float64(node.weight))
	}
	sort.SliceStable(out, func(i, j int) bool { return keys[out[i].id] > keys[out[j].id] })
	return out
}

func defaultRandom() float64 { return rand.Float64() }

// relayPoolTransport sends one request through a pooled relay. The profile
// authorizes it (evasion.Authorize); a build with nothing to offer never
// reaches here, because the pool is skipped.
type relayPoolTransport struct {
	node relayNode
	base http.RoundTripper
}

// probeTarget is the pseudo-target a health probe is authorized for, so a
// probe's proof cannot be reused for a real request.
const probeTarget = "health"

// authorized adds the profile's parameters for method and target. It
// reports false when this build cannot authorize anything.
func authorizedQuery(q url.Values, method, target string) bool {
	auth := evasion.Authorize(method, target)
	if auth == nil {
		return false
	}
	for name, values := range auth {
		if len(values) > 0 {
			q.Set(name, values[0])
		}
	}
	return true
}

// probeURL is the node's health address, authorized for this moment.
func (t *relayPoolTransport) probeURL() (string, bool) {
	u := *t.node.url
	q := u.Query()
	q.Set("health", "1")
	if !authorizedQuery(q, http.MethodGet, probeTarget) {
		return "", false
	}
	u.RawQuery = q.Encode()
	return u.String(), true
}

// RoundTrip sends req to the target through this node. The response keeps
// the original request, so cookies and redirects resolve against the
// target, exactly as the personal relay does.
func (t *relayPoolTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	target := req.URL.String()
	u := *t.node.url
	q := u.Query()
	q.Set("url", target)
	if !authorizedQuery(q, req.Method, target) {
		return nil, fmt.Errorf("relay %s: this build cannot authorize pooled requests", t.node.id)
	}

	if !t.node.envelope() {
		u.RawQuery = q.Encode()
		out := req.Clone(req.Context())
		out.URL = &u
		out.Host = ""
		resp, err := t.base.RoundTrip(out)
		if err != nil {
			return nil, fmt.Errorf("relay %s: %w", t.node.id, err)
		}
		if reason := resp.Header.Get("X-Relay-Error"); reason != "" {
			resp.Body.Close()
			return nil, fmt.Errorf("relay %s refused %s: %s", t.node.id, req.URL.Host, reason)
		}
		resp.Request = req
		return resp, nil
	}

	// Wrapped shape: the method travels in a parameter and the upstream
	// headers and body travel in the request body, because this endpoint
	// cannot carry them as headers.
	q.Set("e", "1")
	q.Set("m", req.Method)
	u.RawQuery = q.Encode()
	body, err := requestEnvelope(req)
	if err != nil {
		return nil, fmt.Errorf("relay %s: %w", t.node.id, err)
	}
	out, err := http.NewRequestWithContext(req.Context(), http.MethodPost, u.String(), bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("relay %s: %w", t.node.id, err)
	}
	out.Header.Set("Content-Type", "application/json")
	// A fronted endpoint always redirects to its content host, so unlike a
	// Worker this one is followed. The wrapped answer carries the target's
	// own status, so nothing about the target's redirects is lost.
	client := &http.Client{Transport: t.base}
	resp, err := client.Do(out)
	if err != nil {
		return nil, fmt.Errorf("relay %s: %w", t.node.id, err)
	}
	defer resp.Body.Close()
	answer, err := responseEnvelope(resp, req)
	if err != nil {
		return nil, fmt.Errorf("relay %s: %w", t.node.id, err)
	}
	return answer, nil
}

// requestEnvelope is the JSON body that carries the upstream request's
// headers and body across a header-limited hop.
func requestEnvelope(req *http.Request) ([]byte, error) {
	sent := struct {
		Headers map[string]string `json:"h"`
		Body    string            `json:"b,omitempty"`
	}{Headers: map[string]string{}}
	for name, values := range req.Header {
		if len(values) > 0 {
			sent.Headers[strings.ToLower(name)] = values[0]
		}
	}
	if req.Body != nil && req.Method != http.MethodGet && req.Method != http.MethodHead {
		if req.GetBody == nil {
			return nil, fmt.Errorf("the request body cannot be replayed")
		}
		body, err := req.GetBody()
		if err != nil {
			return nil, err
		}
		defer body.Close()
		raw, err := io.ReadAll(io.LimitReader(body, maxRelayEnvelopeBody))
		if err != nil {
			return nil, err
		}
		sent.Body = base64.StdEncoding.EncodeToString(raw)
	}
	return json.Marshal(sent)
}

const maxRelayEnvelopeBody = 1 << 20

// responseEnvelope turns a wrapped answer back into the target's response.
// An empty or unreadable body means the relay refused or failed: a fronted
// endpoint cannot pass a status code or a header through, so there is
// nothing else to read it from. X-Arman-Relay is set because the envelope
// itself is the proof of origin, which keeps one check for both shapes.
func responseEnvelope(resp *http.Response, original *http.Request) (*http.Response, error) {
	raw, err := io.ReadAll(io.LimitReader(resp.Body, maxRelayEnvelopeBody+1))
	if err != nil {
		return nil, err
	}
	if len(bytes.TrimSpace(raw)) == 0 {
		return nil, fmt.Errorf("the relay returned nothing")
	}
	var answer struct {
		Status  int               `json:"s"`
		Headers map[string]string `json:"h"`
		Body    string            `json:"b"`
	}
	if err := json.Unmarshal(raw, &answer); err != nil {
		return nil, fmt.Errorf("the relay's answer is not readable")
	}
	if answer.Status < 100 || answer.Status > 599 {
		return nil, fmt.Errorf("the relay reported no usable status")
	}
	body, err := base64.StdEncoding.DecodeString(answer.Body)
	if err != nil {
		return nil, fmt.Errorf("the relay's answer is not readable")
	}
	head := http.Header{}
	for name, value := range answer.Headers {
		head.Set(name, value)
	}
	head.Set("X-Arman-Relay", "1")
	return &http.Response{
		Status:        fmt.Sprintf("%d %s", answer.Status, http.StatusText(answer.Status)),
		StatusCode:    answer.Status,
		Proto:         "HTTP/1.1",
		ProtoMajor:    1,
		ProtoMinor:    1,
		Header:        head,
		Body:          io.NopCloser(bytes.NewReader(body)),
		ContentLength: int64(len(body)),
		Request:       original,
	}, nil
}
