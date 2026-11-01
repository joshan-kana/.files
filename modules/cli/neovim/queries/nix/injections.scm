; extends

((apply_expression
   (apply_expression
     (select_expression
       (attrpath (identifier) @builder))
     (string_expression))
   (indented_string_expression
     (string_fragment) @injection.content))
 (#any-of? @builder "writeShellScript" "writeShellScriptBin")
 (#set! injection.language "bash"))

((apply_expression
   (apply_expression
     (select_expression
       (attrpath (identifier) @builder))
     (string_expression
       (string_fragment) @injection.filename))
   (indented_string_expression
     (string_fragment) @injection.content))
 (#eq? @builder "writeText"))

((binding
   (attrpath (identifier) @shell_field)
   (indented_string_expression
     (string_fragment) @injection.content))
 (#any-of? @shell_field "script" "preStart" "postStart" "preStop" "postStop")
 (#set! injection.language "bash"))

((apply_expression
   (select_expression
     (attrpath (identifier) @shell_builder))
   (attrset_expression
     (binding_set
       (binding
         (attrpath (identifier) @text_field)
         (indented_string_expression
           (string_fragment) @injection.content)))))
 (#eq? @shell_builder "writeShellApplication")
 (#eq? @text_field "text")
 (#set! injection.language "bash"))
