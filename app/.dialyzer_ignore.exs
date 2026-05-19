[
  # Add `{file_path, warning_type}` tuples here to silence specific Dialyzer
  # warnings that you have triaged and decided to accept. Keep this list short
  # — each entry is a piece of debt that won't be re-evaluated automatically.

  # `use Gettext.Backend` expands into code that calls `Gettext.Plural.plural/2`
  # with a tuple whose second element is an `%Expo.PluralForms{}` (opaque type).
  # The macro has access to the struct internals at compile time, but Dialyzer
  # only sees the resulting AST and treats it as a violation. Not actionable
  # from our side — upstream issue in Gettext/Expo.
  {"lib/lynxplanningpoker_web/gettext.ex", :call_without_opaque}
]
