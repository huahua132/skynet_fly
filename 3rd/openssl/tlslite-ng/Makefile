# Authors: 
#   Trevor Perrin
#   Hubert Kario - test and test-dev
#
PYTHON2 := $(shell which python2 2>/dev/null)
PYTHON3 := $(shell which python3 2>/dev/null)
COVERAGE := $(shell which coverage 2>/dev/null)
COVERAGE2 := $(shell which coverage2 2>/dev/null)
COVERAGE3 := $(shell which coverage3 2>/dev/null)

.PHONY : default
default:
	@echo To install tlslite run \"./setup.py install\" or \"make install\"

.PHONY: install
install:
	./setup.py install

.PHONY : clean
clean:
	rm -rf tlslite/__pycache__
	rm -rf tlslite/integration/__pycache__
	rm -rf tlslite/utils/__pycache__
	rm -rf tlslite/*.pyc
	rm -rf tlslite/utils/*.pyc
	rm -rf tlslite/integration/*.pyc
	rm -rf unit_tests/*.pyc
	rm -rf unit_tests/__pycache__
	rm -rf dist
	rm -rf build
	rm -f MANIFEST
	$(MAKE) -C docs clean

.PHONY : docs
docs:
	$(MAKE) -C docs html

dist: docs
	./setup.py sdist

.PHONY : test
test:
	python tests/tlstest.py server localhost:4433 tests & sleep 4
	python tests/tlstest.py client localhost:4433 tests

.PHONY : test-utils
test-utils:
	PYTHONPATH=. python scripts/tls.py server -c tests/serverX509Cert.pem -k tests/serverX509Key.pem localhost:4433 & echo "$$!" > server.pid & sleep 4
	PYTHONPATH=. python scripts/tls.py client localhost:4433
	kill `cat server.pid`
	wait `cat server.pid` || :

.PHONY : test-local
test-local: test-utils
	PYTHONPATH=. COVERAGE_FILE=.coverage.server coverage run --branch --source tlslite tests/tlstest.py server localhost:4433 tests & sleep 4
	PYTHONPATH=. COVERAGE_FILE=.coverage.client coverage run --branch --source tlslite tests/tlstest.py client localhost:4433 tests

test-dev:
ifdef PYTHON2
	@echo "Running test suite with Python 2"
ifndef COVERAGE2
	python2 -m unittest discover -v
else
	coverage2 run --branch --source tlslite -m unittest discover
endif
	PYTHONPATH=. COVERAGE_FILE=.coverage.2.server coverage2 run --branch --source tlslite tests/tlstest.py server localhost:4433 tests & sleep 4
	PYTHONPATH=. COVERAGE_FILE=.coverage.2.client coverage2 run --branch --source tlslite tests/tlstest.py client localhost:4433 tests
endif
ifdef PYTHON3
	@echo "Running test suite with Python 3"
ifndef COVERAGE2
	python3 -m unittest discover -v
else
	coverage3 run --append --branch --source tlslite -m unittest discover
endif
	PYTHONPATH=. COVERAGE_FILE=.coverage.3.server coverage3 run --branch --source tlslite tests/tlstest.py server localhost:4433 tests & sleep 4
	PYTHONPATH=. COVERAGE_FILE=.coverage.3.client coverage3 run --branch --source tlslite tests/tlstest.py client localhost:4433 tests
endif
ifndef PYTHON2
ifndef PYTHON3
	@echo "Running test suite with default Python"
ifndef COVERAGE
	python -m unittest discover -v
else
	coverage run --branch --source tlslite -m unittest discover
endif
	PYTHONPATH=. COVERAGE_FILE=.coverage.server coverage run --branch --source tlslite tests/tlstest.py server localhost:4433 tests & sleep 4
	PYTHONPATH=. COVERAGE_FILE=.coverage.client coverage run --branch --source tlslite tests/tlstest.py client localhost:4433 tests
endif
endif
	$(MAKE) -C docs dummy
	pylint --msg-template="{path}:{line}: [{msg_id}({symbol}), {obj}] {msg}" tlslite > pylint_report.txt || :
	diff-quality --violations=pylint --fail-under=90 pylint_report.txt
ifdef COVERAGE2
	coverage2 combine --append .coverage .coverage.2.server .coverage.2.client
	coverage2 report -m
	coverage2 xml
	diff-cover --fail-under=90 coverage.xml
endif
ifdef COVERAGE3
	coverage2 combine --append .coverage .coverage.3.server .coverage.3.client
	coverage3 report -m
	coverage3 xml
	diff-cover --fail-under=90 coverage.xml
endif
ifndef COVERAGE2
ifndef COVERAGE3
ifdef COVERAGE
	coverage combine --append .coverage .coverage.server .coverage.client
	coverage report -m
	coverage xml
	diff-cover --fail-under=90 coverage.xml
endif
endif
endif

tests/TACK_Key1.pem:
	tack genkey -x -p test -o tests/TACK_Key1.pem

tests/TACK_Key2.pem:
	tack genkey -x -p test -o tests/TACK_Key2.pem

# the following needs to be used only when the server certificate gets recreated
gen-tacks: tests/TACK_Key1.pem tests/TACK_Key2.pem
	tack sign -x -k tests/TACK_Key1.pem -p test -c tests/serverX509Cert.pem -o tests/TACK1.pem
	tack sign -x -k tests/TACK_Key2.pem -p test -c tests/serverX509Cert.pem -o tests/TACK2.pem
