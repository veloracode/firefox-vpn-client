package fxa

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/armanlife/firefox-vpn-client/core/internal/controlplane"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func useFxaFixture(t *testing.T, handler func(r *http.Request, body map[string]any) (int, string)) {
	t.Helper()
	previous := controlplane.Transport()
	t.Cleanup(func() { controlplane.SetTransport(previous) })
	controlplane.SetTransport(roundTripFunc(func(r *http.Request) (*http.Response, error) {
		var body map[string]any
		if r.Body != nil {
			_ = json.NewDecoder(r.Body).Decode(&body)
		}
		status, text := handler(r, body)
		return &http.Response{StatusCode: status, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(text)), Request: r}, nil
	}))
}

// The login request is the phone app's: the same endpoint and body fields
// (email, authPW, and verificationMethod "email-2fa" — no keys, metrics,
// or reason fields), sent under the Mozilla VPN client's identity (the
// User-Agent and Accept the phone sends), not desktop Firefox's.
func TestLoginSendsThePhoneAppsRequest(t *testing.T) {
	var gotUA, gotAccept, gotPath string
	var gotBody map[string]any
	useFxaFixture(t, func(r *http.Request, body map[string]any) (int, string) {
		gotUA = r.Header.Get("User-Agent")
		gotAccept = r.Header.Get("Accept")
		gotPath = r.URL.Path
		gotBody = body
		return 200, `{"sessionToken":"00","uid":"u","verified":true}`
	})
	resp, err := Login(context.Background(), "user@example.com", "secret")
	if err != nil || !resp.Verified {
		t.Fatalf("expected a verified login, got %+v %v", resp, err)
	}
	if gotPath != "/v1/account/login" {
		t.Fatalf("login path %q", gotPath)
	}
	if gotUA != controlplane.MozillaVPNUserAgent {
		t.Fatalf("login user agent %q, want the VPN client's %q", gotUA, controlplane.MozillaVPNUserAgent)
	}
	if gotAccept != "application/json" {
		t.Fatalf("login accept %q", gotAccept)
	}
	if len(gotBody) != 3 || gotBody["email"] != "user@example.com" || gotBody["verificationMethod"] != "email-2fa" {
		t.Fatalf("login body %v", gotBody)
	}
	if authPW, ok := gotBody["authPW"].(string); !ok || len(authPW) != 64 {
		t.Fatalf("login authPW %v", gotBody["authPW"])
	}
}

// The session-verification poll is a HAWK-signed GET on
// /recovery_email/status under the same VPN-client identity as login,
// and it reads whichever of the verified fields FxA answers with.
func TestRecoveryEmailStatusReadsTheSessionState(t *testing.T) {
	session := strings.Repeat("ab", 32)
	var gotPath, gotAuth, gotUA string
	useFxaFixture(t, func(r *http.Request, body map[string]any) (int, string) {
		gotPath, gotAuth, gotUA = r.URL.Path, r.Header.Get("Authorization"), r.Header.Get("User-Agent")
		if r.Method != http.MethodGet {
			return 500, "unexpected method"
		}
		return 200, `{"email":"user@example.com","verified":false,"sessionVerified":true}`
	})
	status, err := RecoveryEmailStatus(context.Background(), session)
	if err != nil {
		t.Fatalf("status: %v", err)
	}
	if gotPath != "/v1/recovery_email/status" || !strings.HasPrefix(gotAuth, "Hawk ") {
		t.Fatalf("status request: %q auth %q", gotPath, gotAuth)
	}
	if gotUA != controlplane.MozillaVPNUserAgent {
		t.Fatalf("status user agent %q", gotUA)
	}
	if status.Email != "user@example.com" || status.Verified || !status.SessionVerified || !status.SessionUsable() {
		t.Fatalf("status parsed wrong: %+v", status)
	}

	useFxaFixture(t, func(r *http.Request, body map[string]any) (int, string) {
		return 200, `{"email":"user@example.com","verified":false,"sessionVerified":false}`
	})
	status, err = RecoveryEmailStatus(context.Background(), session)
	if err != nil || status.SessionUsable() {
		t.Fatalf("an unverified session must not read usable: %+v %v", status, err)
	}
}

func TestErrnoAndMessageReadFxaErrors(t *testing.T) {
	err := error(newFxaAPIError(400, []byte(`{"errno":125,"message":"Request blocked"}`)))
	if Errno(err) != ErrnoRequestBlocked || Message(err) != "Request blocked" {
		t.Fatalf("unexpected errno/message: %d %q", Errno(err), Message(err))
	}
	if Errno(errors.New("plain")) != 0 || Message(errors.New("plain")) != "plain" {
		t.Fatal("plain errors must fall back to their text")
	}
}

func TestLoginWithUnblockCodeSendsCode(t *testing.T) {
	useFxaFixture(t, func(r *http.Request, body map[string]any) (int, string) {
		if r.URL.Path != "/v1/account/login" || body["unblockCode"] != "ABC123" || body["email"] != "user@example.com" {
			return 500, "unexpected request"
		}
		return 200, `{"sessionToken":"00","uid":"u","verified":true}`
	})
	resp, err := LoginWithUnblockCode(context.Background(), "user@example.com", "secret", " abc123 ")
	if err != nil || !resp.Verified {
		t.Fatalf("expected a verified login, got %+v %v", resp, err)
	}
}

// An email typed in another letter case than the account's: FxA refuses it
// with the account's own spelling (errno 120), and the sign-in is repeated
// once with that spelling, its own password hash, and the typed email as
// originalLoginEmail, as Firefox does.
func TestLoginCorrectsTheEmailCase(t *testing.T) {
	const stored, typed = "Asra@example.com", "asra@example.com"
	wantAuthPW, err := deriveAuthPW(stored, "secret")
	if err != nil {
		t.Fatal(err)
	}
	var emails []any
	useFxaFixture(t, func(r *http.Request, body map[string]any) (int, string) {
		emails = append(emails, body["email"])
		if body["email"] != stored {
			return 400, `{"code":400,"errno":120,"message":"Incorrect email case","email":"` + stored + `"}`
		}
		if body["originalLoginEmail"] != typed || body["authPW"] != hex.EncodeToString(wantAuthPW) {
			return 500, "unexpected request"
		}
		return 200, `{"sessionToken":"00","uid":"u","verified":true}`
	})
	resp, err := Login(context.Background(), typed, "secret")
	if err != nil || resp.Email != stored || SignedInEmail(typed, resp, err) != stored {
		t.Fatalf("login %+v %v; want it signed in as %s", resp, err, stored)
	}
	if len(emails) != 2 {
		t.Fatalf("emails sent %v; want the typed one, then the account's", emails)
	}

	// The corrected sign-in is blocked: the error keeps the account's
	// spelling, for the unblock code and the next attempt.
	useFxaFixture(t, func(r *http.Request, body map[string]any) (int, string) {
		if body["email"] != stored {
			return 400, `{"errno":120,"email":"` + stored + `"}`
		}
		return 400, `{"errno":125,"message":"Request blocked"}`
	})
	resp, err = Login(context.Background(), typed, "secret")
	if Errno(err) != ErrnoRequestBlocked || SignedInEmail(typed, resp, err) != stored {
		t.Fatalf("blocked login: %v, email %q", err, SignedInEmail(typed, resp, err))
	}

	// A wrong password in the right case is an ordinary failure, not
	// repeated.
	calls := 0
	useFxaFixture(t, func(r *http.Request, body map[string]any) (int, string) {
		calls++
		return 400, `{"errno":103,"message":"Incorrect password","email":"` + stored + `"}`
	})
	_, err = Login(context.Background(), stored, "wrong")
	if Errno(err) != 103 || calls != 1 || SignedInEmail(stored, nil, err) != stored {
		t.Fatalf("wrong password: %v after %d calls", err, calls)
	}
}

func TestVerifyTOTPReportsRejectedCode(t *testing.T) {
	accept := false
	useFxaFixture(t, func(r *http.Request, body map[string]any) (int, string) {
		if r.URL.Path != "/v1/session/verify/totp" || !strings.HasPrefix(r.Header.Get("Authorization"), "Hawk ") || body["code"] != "123456" {
			return 500, "unexpected request"
		}
		if accept {
			return 200, `{"success":true}`
		}
		return 200, `{"success":false}`
	})
	session := strings.Repeat("ab", 32)
	if err := VerifyTOTP(context.Background(), session, "123456"); err == nil {
		t.Fatal("expected a rejected code to fail")
	}
	accept = true
	if err := VerifyTOTP(context.Background(), session, " 123456 "); err != nil {
		t.Fatalf("expected success, got %v", err)
	}
}

func TestAnswerChallengeAsksCaptchaSolver(t *testing.T) {
	ch := fastlyChallenge{Ty: "captcha", Data: json.RawMessage(`{"image_b64":"data:image/png;base64,AAAA"}`)}
	if _, err := answerChallenge(context.Background(), nil, "", "", ch); err == nil {
		t.Fatal("expected an error without a CAPTCHA solver")
	}
	var shown string
	ctx := WithCaptchaSolver(context.Background(), func(_ context.Context, image string) (string, error) {
		shown = image
		return " x7Kp2 ", nil
	})
	answer, err := answerChallenge(ctx, nil, "", "", ch)
	if err != nil {
		t.Fatal(err)
	}
	got := answer.(map[string]interface{})
	if got["ty"] != "captcha" || got["answer"] != "x7Kp2" || shown != "data:image/png;base64,AAAA" {
		t.Fatalf("unexpected CAPTCHA answer %v (shown %q)", got, shown)
	}
}
