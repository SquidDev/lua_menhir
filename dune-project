(lang dune 3.6)
(implicit_transitive_deps false)
(generate_opam_files true)
(using menhir 2.1)

(name lua_menhir)
(version 1.0.0)
(authors "SquidDev")
(license MPL-2.0)
(maintainers "Jonathan Coates <git@squiddev.cc>")

(package
 (name lua_menhir)
 (synopsis "Parser tools for Menhir and Lua")
 (description "description")
 (depends
   (ocaml (>= 4.14))
   (ocamlformat :dev)

   cmon
   fix
   menhir))
