package main

import (
	"io"
	"net/http"
	"os"
	"strings"
)

func main() {
	originPort := os.Getenv("PERL_API_PORT")

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		res, err := http.Get("http://127.0.0.1:" + originPort + "/internal/a")
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		retA, err := readerToStr(res.Body)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}

		res, err = http.Get("http://127.0.0.1:" + originPort + "/internal/b")
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		retB, err := readerToStr(res.Body)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}

		w.WriteHeader(http.StatusOK)
		_, _ = io.WriteString(w, "a:"+retA+"\n")
		_, _ = io.WriteString(w, "b:"+retB+"\n")
	})
	http.ListenAndServe("127.0.0.1:"+os.Getenv("GO_APP_PORT"), nil)
}

func readerToStr(rc io.ReadCloser) (string, error) {
	defer rc.Close()
	var b strings.Builder
	if _, err := io.Copy(&b, rc); err != nil {
		return "", err
	}
	return b.String(), nil
}
