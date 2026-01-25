#!/usr/bin/env just --justfile

default:
  @just --list

LOVE := "/usr/bin/love"
MON := "nodemon"
PRODUCT_NAME := "Compy"
PRODUCT_NAME_SC := "compy"
FAVI := "favicon.ico"

DIST := "dist"
WEBDIST := "./dist/web"
WEBDIST-c := "./dist/web-c"

# run unit tests on file change
unit_test:
  @{{MON}} -e 'lua' --exec 'echo -en "\n\n\n\n------------- BUSTED -------------\n"; busted tests'
unit_test_brief:
  @{{MON}} -e 'lua' --exec 'echo -en "\n\n\n\n------------- BUSTED -------------\n"; busted tests -o tests/brief_output.lua'
unit_test_tag TAG:
  @{{MON}} -e lua \
    --exec 'echo -en "\n\n\n\n------------- BUSTED -------------\n" ; busted tests --defer-print --tags="{{TAG}}"'
unit_test_ast:
  @just unit_test_tag ast
unit_test_src:
  @SHOW_CODE=1 just unit_test_tag src
unit_test_parser:
  @PARSER_DEBUG=1 just unit_test_tag parser
unit_test_analyzer:
  @ANA_DEBUG=1 just unit_test_tag analyzer

# run unit tests of this tag once
ut TAG:
  @busted tests --tags {{TAG}}
ut_all:
  @busted tests

# run app on file change
dev:
  @{{MON}} --exec '{{LOVE}} src' -e 'lua'

dev-atest:
  @{{MON}} --exec 'clear; {{LOVE}} src test --auto' -e 'lua'
dev-atest-dbg:
  @DEBUG=1 just dev-atest
dev-autotest: dev-atest
dev-playtest game: (dev-ptest game)
dev-dtest:
  @{{MON}} --exec 'clear; {{LOVE}} src test --draw' -e 'lua'
dev-drawtest: dev-dtest
dev-size:
  @{{MON}} --exec '{{LOVE}} src test --size' -e 'lua'
dev-allt:
  @{{MON}} --exec 'clear; {{LOVE}} src test --all' -e 'lua'

dev-ptest game:
  @{{MON}} --exec 'clear; {{LOVE}} src play {{game}}' -e 'lua'

dev-harmony:
  @{{MON}} --exec '{{LOVE}} src harmony' -e 'lua'

# install examples to projects folder (same as in-app)
deploy-examples:
  #!/usr/bin/env -S bash
  PROJ_PATH="$HOME/Documents/{{PRODUCT_NAME_SC}}/projects"
  EX_PATH="src/examples"

  for i in "$EX_PATH"/*/main.lua
  do
    P="$(basename $(dirname $i))"
    # du -sh "$PROJ_PATH/$P"
    cp -r "$EX_PATH/$P" "$PROJ_PATH/"
  done

# copy examples from project folder to dist and examples folder
snap-examples:
  #!/usr/bin/env -S bash
  PROJ_PATH="$HOME/Documents/{{PRODUCT_NAME_SC}}/projects"
  EX_PATH="src/examples"

  TS="$(date +"%F_%T")"
  TS=${TS//:/-}
  DIR="dist/examples/$TS"
  mkdir -p "$DIR"

  for i in "$EX_PATH"/*/{main.lua,README}
  do
    P="$(basename $(dirname $i))"
    # du -sh "$PROJ_PATH/$P"
    rsync -r --checksum "$PROJ_PATH/$P/" "$EX_PATH/$P/"
    cp -r "$PROJ_PATH/$P" "$DIR"/
  done

dev-dogfood-examples:
  @{{MON}} --verbose \
    --exec 'just one-atest; just snap-examples' \
    -e 'lua' -w 'src'

# run webserver on 8080 with hot reload
dev-js:
  #!/usr/bin/env -S bash
  {{MON}} --exec 'just package-js' -e lua &
  cd web
  node server.js
  wait
# run webserver on 8080 with hot reload (compat mode)
dev-js-c:
  #!/usr/bin/env -S bash
  {{MON}} --exec 'just package-js-c' -e lua &
  cd {{WEBDIST-c}}
  live-server --no-browser
  wait

# install prerequisites for running/packaging js verison
setup-web-dev:
  cd web ; npm install

one:
  @{{LOVE}} src
one-atest:
  @{{LOVE}} src test --auto
one-dtest:
  @{{LOVE}} src test --draw
one-ptest game:
  @{{LOVE}} src play {{game}}
one-allt:
  @{{LOVE}} src test --draw --auto
one-size:
  @{{LOVE}} src test --size
one-harmony:
  @{{LOVE}} src harmony

VERSION := `git describe --tags --long --always`

package: version
  @7z a {{DIST}}/game.love ./src/* > /dev/null
  @echo packaged:
  @ls -lh {{DIST}}/game.love

package-web: package-js
  @rm -f {{DIST}}/{{PRODUCT_NAME}}-web.zip
  @7z a {{DIST}}/{{PRODUCT_NAME}}-web.zip {{WEBDIST}}/* \
    > /dev/null
  @echo packaged:
  @ls -lh {{DIST}}/{{PRODUCT_NAME}}-web.zip
package-web-c: package-js-c
  @rm -f {{DIST}}/{{PRODUCT_NAME}}-web-compat.zip
  @7z a {{DIST}}/{{PRODUCT_NAME}}-web-compat.zip {{WEBDIST}}/* \
    > /dev/null
  @echo packaged:
  @ls -lh {{DIST}}/{{PRODUCT_NAME}}-web-compat.zip

# package an example to a .compy
zip-example name:
  #!/usr/bin/env -S bash
  PKG="dist/{{name}}.compy"
  7z -tzip a "$PKG" \
     ./src/examples/{{name}}/* &> /dev/null \
      && ls "$PKG" \
      || echo 'ENOENT'

zip-examples-all:
  #!/usr/bin/env -S bash
  for e in ./src/examples/*
  do
    just zip-example $(basename $e)
  done

package-js-dir DT: version
  #!/usr/bin/env -S bash
  WEB={{DT}}
  unset C
  [[ $WEB =~ "-c" ]] && C='-c'
  pushd web &> /dev/null
  npx love.js $C ../src ../$WEB \
    --title "{{PRODUCT_NAME}}" --memory 67108864
  popd &> /dev/null
  test -f $WEB/{{FAVI}} || \
    cp -f res/"{{PRODUCT_NAME_SC}}".ico $WEB/{{FAVI}}
  mkdir -p $WEB/doc
  cp -r doc/interface $WEB/doc/
  cd web
  node render_md.js
  rm ../$WEB/theme/bg.png
  # cp index.html ../$WEB
  sed -e 's/%%VERSION%%/{{VERSION}}/' index.html \
      > ../$WEB/index.html
  cat head.html ../{{DIST}}/_readme.html \
      >  ../$WEB/readme.html
  sed -e 's/%%VERSION%%/{{VERSION}}/' tail.html \
      >> ../$WEB/readme.html
  cp love.css ../$WEB/theme/

package-js: (package-js-dir WEBDIST)
# compat mode
package-js-c: (package-js-dir WEBDIST-c)

import? 'local.just'

# Create git hooks
setup-hooks:
  #!/usr/bin/env -S bash
  HDIR=.git/hooks
  cat > $HDIR/pre-commit << EOF
  #!/bin/sh
  just ut_all
  EOF
  chmod +x $HDIR/pre-commit

version:
  @echo {{VERSION}} | tee src/ver.txt
