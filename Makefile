PYPREFIX_PATH=/usr
PYTHONLIBS=LD_LIBRARY_PATH=/usr/lib
PYTHONPATH=$(PYPREFIX_PATH)/bin/python
FIRST_EASYINSTALL=$(PYTHONLIBS) easy_install
PIP=pip
PYTHON=bin/python
EASYINSTALL=bin/easy_install
VIRTUALENV=virtualenv
SOURCE_ACTIVATE=$(PYTHONLIBS) . bin/activate; 
PROXY = http://proxy.unlu.edu.ar:8080/
PROXYENV=export http_proxy=$(PROXY); export HTTP_PROXY=$(PROXY); export https_proxy=$(PROXY); export HTTPS_PROXY=$(PROXY); export PATH=$(PATH):/usr/local/cuda/bin; 

unattended:
	@ (sudo ls 2>&1) >> tracking.log

$(LIBSQLITE3):
	$(call install,sqlite-autoconf-3080701,sqlite-autoconf-3080701.tar.gz,http://www.sqlite.org/2014)

bin/activate: requirements.txt
	@ echo "[ using        ] $(PYTHONPATH)"
	@ echo "[ installing   ] $(VIRTUALENV)"
	@ (sudo $(FIRST_EASYINSTALL) virtualenv 2>&1) >> tracking.log
	@ echo "[ creating     ] $(VIRTUALENV) with no site packages"
	@ ($(PYTHONLIBS) $(VIRTUALENV) --python=$(PYTHONPATH) --no-site-packages . 2>&1) >> tracking.log
	@ echo "[ installing   ] $(PIP) inside $(VIRTUALENV)"
	@ ($(SOURCE_ACTIVATE) $(EASYINSTALL) pip 2>&1) >> tracking.log
	@ echo "[ installing   ] $(PIP) requirements"
	@ $(SOURCE_ACTIVATE) $(PIP) install pip
	@ $(SOURCE_ACTIVATE) $(PIP) install distribute
	@ $(SOURCE_ACTIVATE) $(PIP) install -e  .
	@ $(SOURCE_ACTIVATE) $(PIP) install --default-timeout=100 -r requirements.development.txt
	@ touch bin/activate

deploy: bin/activate
	@ echo "[ deployed     ] the system was completly deployed"

show-version:
	@ $(SOURCE_ACTIVATE) $(PYTHON) --version

run:
	@ $(SOURCE_ACTIVATE) $(PYTHON) -c "from models import runner; runner.run()"

ra_run:
	@ ($(PROXYENV) $(SOURCE_ACTIVATE) $(PYTHON) -c "from models import runner; runner.run()" 2>&1) >> status.txt

test:
	@ $(SOURCE_ACTIVATE) $(PYTHON) tests

test-coverage-travis-ci:
	@ $(SOURCE_ACTIVATE) coverage run --source='models/' tests/__main__.py

test-coveralls:
	@ $(SOURCE_ACTIVATE) coveralls

test-coverage: test-coverage-travis-ci test-coveralls

shell:
	@ $(SOURCE_ACTIVATE) ipython

pypi-register: test
	@ echo "[ record       ] package to pypi servers"
	@ ($(SOURCE_ACTIVATE) $(PYTHON) setup.py register -r pypi 2>&1) >> tracking.log
	@ echo "[ registered   ] the new version was successfully registered"

pypi-upload: test
	@ echo "[ uploading    ] package to pypi servers"
	@ ($(SOURCE_ACTIVATE) $(PYTHON) setup.py sdist upload -r https://pypi.python.org/pypi 2>&1) >> tracking.log
	@ echo "[ uploaded     ] the new version was successfully uploaded"

pypitest-register: test
	@ echo "[ record       ] package to pypi servers"
	@ $(SOURCE_ACTIVATE) $(PYTHON) setup.py register -r testpypi
	@ echo "[ registered   ] the new version was successfully registered"

pypitest-upload: test
	@ echo "[ uploading    ] package to pypi servers"
	$(SOURCE_ACTIVATE) $(PYTHON) setup.py sdist upload -r https://testpypi.python.org/pypi
	@ echo "[ uploaded     ] the new version was successfully uploaded"

clean:
	@ echo "[ cleaning     ] remove deployment generated files that doesn't exists in the git repository"
	@ rm -rf pip-*.json local/ python-aspects* virtualenv* bin/ lib/ *.egg-info/ lib64 include/ build/ share Python-* .Python get-pip.py tracking.log subversion
