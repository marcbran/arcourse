//go:build e2e

package tests

import (
	"context"
	"time"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

const subscribeSettleDelay = 200 * time.Millisecond

func (s *Stage) an_observer_is_subscribed(format pkg.Format) *Stage {
	ch, unsubscribe := s.facade.Observe(context.Background(), format)
	s.observeCh = ch
	s.observeUnsubscribe = unsubscribe
	time.Sleep(subscribeSettleDelay)
	return s
}

func (s *Stage) the_observation_is_received() *Stage {
	defer s.observeUnsubscribe()
	select {
	case result := <-s.observeCh:
		s.LastOutput = result.Output
		s.LastError = ""
	case <-time.After(2 * time.Second):
		s.LastOutput = ""
		s.LastError = "timed out waiting for an observation"
	}
	return s
}

func (s *Stage) no_observation_is_received() *Stage {
	defer s.observeUnsubscribe()
	s.LastOutput = ""
	s.LastError = ""
	select {
	case result, ok := <-s.observeCh:
		if ok {
			s.LastOutput = result.Output
		}
	case <-time.After(300 * time.Millisecond):
	}
	return s
}

func (s *Stage) the_observer_unsubscribes() *Stage {
	s.observeUnsubscribe()
	return s
}
