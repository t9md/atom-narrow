#!/bin/bash
decaffeinate\
  --keep-commonjs\
  --prefer-const\
  --loose-default-params $1

# decaffeinate [OPTIONS] PATH [PATH …]
# decaffeinate [OPTIONS] < INPUT
#
# Move your CoffeeScript source to JavaScript using modern syntax.
#
# OPTIONS
#
#   -h, --help               Display this help message.
#   --modernize-js           Treat the input as JavaScript and only run the
#                            JavaScript-to-JavaScript transforms, modifying the file(s)
#                            in-place.
#   --literate               Treat the input file as Literate CoffeeScript.
#   --keep-commonjs          Do not convert require and module.exports to import and export.
#   --force-default-export   When converting to export, use a single "export default" rather
#                            than trying to generate named imports where possible.
#   --safe-import-function-identifiers
#                            Comma-separated list of function names that may safely be in the
#                            import/require section of the file. All other function calls
#                            will disqualify later requires from being converted to imports.
#   --prefer-const           Use the const keyword for variables when possible.
#   --loose-default-params   Convert CS default params to JS default params.
#   --loose-for-expressions  Do not wrap expression loop targets in Array.from.
#   --loose-for-of           Do not wrap JS for...of loop targets in Array.from.
#   --loose-includes         Do not wrap in Array.from when converting in to includes.
#   --loose-comparison-negation
#                            Allow unsafe simplifications like `!(a > b)` to `a <= b`.
#   --allow-invalid-constructors
#                            Don't error when constructors use this before super or omit
#                            the super call in a subclass.
#   --enable-babel-constructor-workaround
#                            Use a hacky Babel-specific workaround to allow this before
#                            super in constructors. Also works when using TypeScript.
#
# EXAMPLES
#
#   # Convert a .coffee file to a .js file.
#   $ decaffeinate index.coffee
#
#   # Pipe an example from the command-line.
#   $ echo "a = 1" | decaffeinate
#
#   # On OS X this may come in handy:
#   $ pbpaste | decaffeinate | pbcopy
#
#   # Process everything in a directory.
#   $ decaffeinate src/
#
#   # Redirect input from a file.
#   $ decaffeinate < index.coffee
