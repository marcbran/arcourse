package server

import (
	"net/http"
	"net/url"

	"github.com/google/uuid"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

const (
	sessionCookieName = "arcourse_session"
	fromCookieName    = "arcourse_from"
	fromCookieMaxAge  = 60
)

func browseOrigin(w http.ResponseWriter, r *http.Request) pkg.Origin {
	return pkg.Origin{
		Session:  sessionFromCookie(w, r),
		From:     fromFromCookie(w, r),
		FromPath: refererPath(r),
	}
}

func setFromCookie(w http.ResponseWriter, from pkg.EntryID) {
	http.SetCookie(w, &http.Cookie{
		Name:     fromCookieName,
		Value:    string(from),
		Path:     "/",
		MaxAge:   fromCookieMaxAge,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})
}

func fromFromCookie(w http.ResponseWriter, r *http.Request) pkg.EntryID {
	cookie, err := r.Cookie(fromCookieName)
	if err != nil || cookie.Value == "" {
		return ""
	}
	http.SetCookie(w, &http.Cookie{
		Name:     fromCookieName,
		Path:     "/",
		MaxAge:   -1,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})
	return pkg.EntryID(cookie.Value)
}

func sessionFromCookie(w http.ResponseWriter, r *http.Request) pkg.SessionID {
	cookie, err := r.Cookie(sessionCookieName)
	if err == nil && cookie.Value != "" {
		return pkg.SessionID(cookie.Value)
	}
	session := uuid.Must(uuid.NewV7()).String()
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    session,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})
	return pkg.SessionID(session)
}

func refererPath(r *http.Request) pkg.QueryPath {
	referer := r.Header.Get("Referer")
	if referer == "" {
		return ""
	}
	parsed, err := url.Parse(referer)
	if err != nil {
		return ""
	}
	if parsed.Host != "" && r.Host != "" && parsed.Host != r.Host {
		return ""
	}
	return pkg.NewQueryPath(parsed.EscapedPath())
}

func requestOrigin(r *http.Request) pkg.Origin {
	query := r.URL.Query()
	return pkg.Origin{
		Session:  pkg.SessionID(query.Get("session")),
		From:     pkg.EntryID(query.Get("from")),
		FromPath: pkg.NewQueryPath(query.Get("fromPath")),
	}
}
