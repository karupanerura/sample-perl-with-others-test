# sample-perl-with-others-test

## Perl only test

```bash
perl test.pl
```

## Go with Perl test

```bash
export GO_APP_PORT=8080
export PERL_API_PORT=8081

# launch go app
cd go
go run main.go &
cd ..

# test to go app
USE_GO_APP=1 perl test.pl
```

