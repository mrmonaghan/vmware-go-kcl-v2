#!/usr/bin/env bash

function local_go_pkgs() {
    find './clientlibrary' -name '*.go' | \
        grep -Fv '/vendor/' | \
        grep -Fv '/go/' | \
        grep -Fv '/gen/' | \
        grep -Fv '/tmp/' | \
        grep -Fv '/run/' | \
        grep -Fv '/tests/' | \
        sed -r 's|(.+)/[^/]+\.go$|\1|g' | \
        sort -u
}

function checkfmt() {
    local files=""
    files="$(find . -type f -iname "*.go" -exec gofmt -l {} \;)"

    if [ -n "$files" ]; then
        echo "You need to run \"gofmt -w ./\" to fix your formatting."
        echo "$files" >&2
        return 1
    fi
}

function go_format() {
    echo "go formatting..."
    gofmt -w ./
    echo "done"
}

function lint() {
  #	golangci-lint run --enable-all -D forbidigo -D gochecknoglobals -D gofumpt -D gofmt -D nlreturn
    golangci-lint run \
        --skip-files=_mock.go \
        --disable=golint \
        --skip-dirs=test \
        --fast \
        --timeout=600s \
        --verbose \
        "$(local_go_pkgs)"
}

function test() {
  	go list ./... | grep -v /test | \
   	xargs -L 1 -I% bash -c 'echo -e "\n**************** Package: % ****************" && go test % -v -cover -race ./...'
}

function scanast() {
    gosec version
    gosec ./... > security.log 2>&1

    local issues=""
    issues=$(grep -c 'Severity: MEDIUM' security.log | grep -v deaggregator | grep -c _)
    if [ -n "$issues" ] && [ "$issues" -gt 0 ]; then
        echo ""
        echo "Medium Severity Issues:"
        grep -e "Severity: MEDIUM" -A 1 security.log
        echo "$issues" "medium severity issues found."
    fi

    local issues=""
    local issues_count=""
    issues="$(grep -E 'Severity: HIGH' security.log | grep -v vendor)"
    issues_count="$(grep -E 'Severity: HIGH' security.log | grep -v vendor | grep -c _)"
    if [ -n "$issues_count" ] && [ "$issues_count" -gt 0 ]; then
        echo ""
        echo "High Severity Issues:"
        grep -E "Severity: HIGH" -A 1 security.log
        echo "$issues_count" "high severity issues found."
        echo "$issues"
        echo "You need to resolve the high severity issues at the least."
        exit 1
    fi

    local issues=""
    local issues_count=""
    issues="$(grep -E 'Errors unhandled' security.log | grep -v vendor | grep -v /src/go/src)"
    issues_count="$(grep -E 'Errors unhandled' security.log | grep -v vendor | grep -v /src/go/src | grep -c _)"
    if [ -n "$issues_count" ] && [ "$issues_count" -gt 0 ]; then
        echo ""
        echo "Unhandled errors:"
        grep -E "Errors unhandled" security.log
        echo "$issues_count" "unhandled errors, please indicate with the right comment that this case is ok, or handle the error."
        echo "$issues"
        echo "You need to resolve the all unhandled errors."
        exit 1
    fi

    rm -f security.log
}

function usage() {
    echo "check.sh fmt|lint" >&2
    exit 2
}

case "$1" in
    fmtcheck) checkfmt ;;
    format) go_format ;;
    lint) lint ;;
    unittest) test ;;
    scan) scanast ;;
    *) usage ;;
esac
