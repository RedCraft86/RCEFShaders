# Rider section highlighting compatibility patch

The active migoto-ini 0.11.1 grammar has been patched for Rider's line-by-line TextMate lexer. The end-of-input alternative `|\z` was removed from the seven section-ending expressions: constants, present, hunting, key, preset, setting, and commandlist. Sections now end at the next section header; reaching the document's end requires no explicit terminator.

Only those seven section endings were changed. Other end-of-input alternatives, token rules, themes, extension associations, and game scripts were preserved.

The following file was adjusted: `syntaxes/migoto.tmLanguage.json`.
