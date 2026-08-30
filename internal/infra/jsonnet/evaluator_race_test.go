package jsonnet

import (
	"fmt"
	"strings"
	"sync"
	"testing"
	"testing/fstest"
)

func TestEvaluatorConcurrentWarmAndEvaluate(t *testing.T) {
	e := NewEvaluator(fstest.MapFS{}, nil, nil)

	const goroutines = 100
	const iterations = 50

	var wg sync.WaitGroup
	errs := make(chan error, goroutines*iterations)
	for g := 0; g < goroutines; g++ {
		g := g
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := 0; i < iterations; i++ {
				err := e.Warm(map[string]string{"root": "{ value: 1 }"})
				if err != nil {
					errs <- err
					continue
				}
				snippet := fmt.Sprintf(`local root = import 'root'; root.value + %d`, g)
				out, err := e.Evaluate(snippet)
				if err != nil {
					errs <- err
					continue
				}
				expected := fmt.Sprintf("%d", g+1)
				if strings.TrimSpace(out) != expected {
					errs <- fmt.Errorf("goroutine %d: expected %q, got %q", g, expected, out)
				}
			}
		}()
	}
	wg.Wait()
	close(errs)

	for err := range errs {
		t.Error(err)
	}
}
