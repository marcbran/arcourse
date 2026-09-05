//go:build e2e

package tests

import (
	"context"
	"time"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/stretchr/testify/require"
)

func (s *Stage) a_watcher_subscribes_to(path string, format pkg.Format) *Stage {
	ch, unsubscribe, err := s.facade.Watch(context.Background(), path, nil, format)
	require.NoError(s.t, err)
	s.watchCh = ch
	s.watchUnsubscribe = unsubscribe
	time.Sleep(subscribeSettleDelay)
	return s
}

func (s *Stage) the_watch_event_is_received() *Stage {
	defer s.watchUnsubscribe()
	select {
	case result := <-s.watchCh:
		s.LastOutput = result.Output
		s.LastError = ""
	case <-time.After(2 * time.Second):
		s.LastOutput = ""
		s.LastError = "timed out waiting for a watch event"
	}
	return s
}

func (s *Stage) the_watch_event_is_received_and_watcher_stays_subscribed() *Stage {
	select {
	case result := <-s.watchCh:
		s.LastOutput = result.Output
		s.LastError = ""
	case <-time.After(2 * time.Second):
		s.LastOutput = ""
		s.LastError = "timed out waiting for a watch event"
	}
	return s
}

func (s *Stage) no_watch_event_is_received() *Stage {
	defer s.watchUnsubscribe()
	s.LastOutput = ""
	s.LastError = ""
	select {
	case result, ok := <-s.watchCh:
		if ok {
			s.LastOutput = result.Output
		}
	case <-time.After(300 * time.Millisecond):
	}
	return s
}

func (s *Stage) the_watcher_unsubscribes() *Stage {
	s.watchUnsubscribe()
	return s
}
