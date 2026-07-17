package broadcast

import (
	"sync"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type LastQuery struct {
	mu          sync.Mutex
	subscribers map[chan pkg.Result]pkg.Format
}

func NewLastQuery() *LastQuery {
	return &LastQuery{
		subscribers: map[chan pkg.Result]pkg.Format{},
	}
}

func (q *LastQuery) Publish(format pkg.Format, result pkg.Result) {
	q.mu.Lock()
	defer q.mu.Unlock()
	for ch, f := range q.subscribers {
		if f != format {
			continue
		}
		select {
		case ch <- result:
		default:
			select {
			case <-ch:
			default:
			}
			select {
			case ch <- result:
			default:
			}
		}
	}
}

func (q *LastQuery) Subscribe(format pkg.Format) (<-chan pkg.Result, func()) {
	ch := make(chan pkg.Result, 1)
	q.mu.Lock()
	q.subscribers[ch] = format
	q.mu.Unlock()

	unsubscribe := func() {
		q.mu.Lock()
		delete(q.subscribers, ch)
		q.mu.Unlock()
	}
	return ch, unsubscribe
}

func (q *LastQuery) ObservedFormats() []pkg.Format {
	q.mu.Lock()
	defer q.mu.Unlock()
	seen := map[pkg.Format]bool{}
	var formats []pkg.Format
	for _, f := range q.subscribers {
		if seen[f] {
			continue
		}
		seen[f] = true
		formats = append(formats, f)
	}
	return formats
}
