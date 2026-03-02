.PHONY: check lint libs package clean

check: lint package

lint:
	luacheck .

libs:
	bash libs.sh

package:
	bash package.sh

clean:
	rm -rf dist/
