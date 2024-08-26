package main

import (
	"context"
	"fmt"
	"log"
	"net/http"

	"github.com/ServiceWeaver/weaver"
	_ "golang.org/x/crypto/x509roots/fallback" // CA bundle for FROM Scratch
)

// This is a template of a simple Service Weaver application. You can run the
// application by running `go run .`.
//
//     $ go run .
//
// To use a config file, first update the binary name in weaver.toml to be the
// name of the binary that's produced when you run `go build .`. Then, you can
// run the app in a single process or in multiple processes.
//
//     $ weaver single deploy weaver.toml
//     $ weaver multi deploy weaver.toml
//
// See https://serviceweaver.dev/docs for more information on writing Service
// Weaver applications.

//go:generate weaver generate ./...

func main() {
	// weaver.Run runs a Service Weaver application. It creates and initializes
	// all components, and then passes a pointer to the main component to the
	// serve function.
	if err := weaver.Run(context.Background(), serve); err != nil {
		log.Fatal(err)
	}
}

// app is the main component of the application. weaver.Run creates
// it and calls its Main method, which is the entrypoint to a Service Weaver app
type app struct {
	weaver.Implements[weaver.Main]
	reverser weaver.Ref[Reverser]
	// lis is the network listener on which this app serves HTTP traffic. By
	// default, the name of the listener is the same as the name of the field,
	// but you can override the name using a `weaver:"NAME"` annotation.
	lis weaver.Listener `weaver:"lis"`
}

// serve is called by weaver.Run and contains the body of the application. It serves HTTP traffic
func serve(ctx context.Context, app *app) error {

	fmt.Printf("app listening on %v\n", app.lis)

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
	app.Logger(ctx).Info("Listening on...", "address", app.lis)
	return http.Serve(app.lis, nil)
}
