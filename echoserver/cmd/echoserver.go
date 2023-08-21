package main

import (
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"net/http/httputil"
	"os"
	"strconv"
	"time"
)

const (
	listenAddress = ":8080"
)

var (
	randomStatusCodes = []int{200, 200, 200, 200, 200, 400, 500, 502, 503}
)

func Response(w http.ResponseWriter, r *http.Request) {
	log.Printf("host: %s, address: %s, method: %s, requestURI: %s, proto: %s, useragent: %s", r.Host, r.RemoteAddr, r.Method, r.RequestURI, r.Proto, r.UserAgent())

	dump, err := httputil.DumpRequest(r, true)
	if err != nil {
		http.Error(w, fmt.Sprint(err), http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, `
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
     "http://www.w3.org/TR/html4/transitional.dtd">
<html>
<head>
<title>%s</title>
</head>
<body>
<h1> %s
<font color="%s">
<pre>
%s
</pre>
</font>
</body>
</html>
`, title, title, color, string(dump))
}

func Status(w http.ResponseWriter, r *http.Request) {
	log.Printf("host: %s, address: %s, method: %s, requestURI: %s, proto: %s, useragent: %s", r.Host, r.RemoteAddr, r.Method, r.RequestURI, r.Proto, r.UserAgent())

	statusString := r.URL.Query().Get("status")
	if statusString == "" || statusString == "random" {
		index := rand.Intn(len(randomStatusCodes))
		w.WriteHeader(randomStatusCodes[index])
		return
	}

	status, err := strconv.Atoi(statusString)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(status)
}

func Timeout(w http.ResponseWriter, r *http.Request) {
	log.Printf("host: %s, address: %s, method: %s, requestURI: %s, proto: %s, useragent: %s", r.Host, r.RemoteAddr, r.Method, r.RequestURI, r.Proto, r.UserAgent())

	timeoutString := r.URL.Query().Get("timeout")
	if timeoutString == "" {
		http.Error(w, "timout parameter is missing", http.StatusBadRequest)
		return
	}

	timeout, err := time.ParseDuration(timeoutString)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	time.Sleep(timeout)
	w.WriteHeader(200)
}

var color = "#000000"
var title = "Request Information"

func CheckArgs(i int, msg string) {
	if i >= len(os.Args) {
		fmt.Fprintf(os.Stderr, "argument expected for %s", msg)
		os.Exit(1)
	}
}

func main() {
	fmt.Printf("echo server %s\n", Get())
	for i := 1; i < len(os.Args); i++ {
		switch os.Args[i] {
		case "--color":
			CheckArgs(i+1, os.Args[i])
			color = os.Args[i+1]
			i++
		case "--title":
			CheckArgs(i+1, os.Args[i])
			title = os.Args[i+1]
			i++
		default:
			fmt.Fprintf(os.Stderr, "unexpected argument %q", os.Args[i])
			os.Exit(1)
		}
	}
	router := http.NewServeMux()

	router.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "OK")
	})
	router.HandleFunc("/", Response)
	router.HandleFunc("/status", Status)

	server := &http.Server{
		Addr:    listenAddress,
		Handler: router,
	}

	log.Printf("Server listen on: %s", listenAddress)

	if err := server.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("HTTP server died unexpected: %s", err.Error())
	}
}
