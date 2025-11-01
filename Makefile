.PHONY: build-lambdas clean

build-lambdas:
	cd lambdas/ingest-go && GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o bootstrap .
	cd lambdas/dq-check-go && GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o bootstrap .

test:
	# Go tests (data-generator only to avoid AWS deps)
	cd data-generator && go test -v .
	# Python tests (Flask)
	python3 -m venv .venv && . .venv/bin/activate && pip install -q -r flask-dashboard/requirements.txt && pip install -q -r flask-dashboard/requirements-dev.txt && pytest -q flask-dashboard/tests/test_app.py

clean:
	rm -f lambdas/ingest-go/bootstrap lambdas/dq-check-go/bootstrap
	rm -rf terraform/.build

