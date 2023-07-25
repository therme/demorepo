package main

import (
	"context"
	"fmt"
	"log"
	"net/http"

	"github.com/ServiceWeaver/weaver"
)

func main() {
	if err := weaver.Run(context.Background(), serve); err != nil {
		log.Fatal(err)
	}
}

// app is the main component of the application. weaver.Run creates
// it and calls its Main method.
type app struct {
	weaver.Implements[weaver.Main]
	reverser weaver.Ref[Reverser]
	hello    weaver.Listener
}

// Main is called by weaver.Run and contains the body of the application.
func serve(ctx context.Context, app *app) error {

	fmt.Printf("app listening on %v\n", app.hello)

	// srv /hello endpoint
	http.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
		name := r.URL.Query().Get("name")
		if name == "" {
			name = "World!"
		}
		fmt.Fprintf(w, "Hello %s!\n", name)
	})
	http.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintf(w, "{\"status\": \"OK\"}")
	})
	return http.Serve(app.hello, nil)
}
