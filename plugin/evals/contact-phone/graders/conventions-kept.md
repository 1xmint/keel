---
type: regex
target: { source: file, path: app.py }
pattern: '<(form|input|label)\b'
match: not_contains
---
