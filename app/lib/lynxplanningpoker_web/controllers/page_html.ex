defmodule LynxplanningpokerWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use LynxplanningpokerWeb, :html

  embed_templates "page_html/*"

  @doc """
  The "frequently asked questions" shown on the *how it works* page.

  Single source of truth: the `how_it_works` template renders this list and
  `PageController` feeds the very same entries into the `FAQPage` JSON-LD, so
  the on-page copy and the structured data can never drift apart.

  Each entry is a `%{question: _, answer: _}` map of already-translated text;
  callers must run inside a request so the active locale is set.
  """
  def faqs do
    [
      %{
        question: gettext("Is it really free?"),
        answer:
          gettext(
            "Yes. The core planning poker experience — creating rooms, inviting your team, voting, revealing — is free forever. We have no paid tier today; if we add one in the future, it will only cover advanced features and the basic flow will remain free."
          )
      },
      %{
        question: gettext("Do my teammates need to sign up?"),
        answer:
          gettext(
            "No accounts, no passwords. Anyone with the room link types a name and they're in. The name is only kept while they are in the room."
          )
      },
      %{
        question: gettext("How many people can join a room?"),
        answer:
          gettext(
            "Up to 15 participants per room, which covers the vast majority of planning sessions. If you need bigger groups, get in touch."
          )
      },
      %{
        question: gettext("What happens to my data?"),
        answer:
          gettext(
            "Rooms are ephemeral: everything is deleted when the host leaves or after two hours of inactivity. We don't sell data and we don't run ads."
          )
      },
      %{
        question: gettext("Can I use it in my language?"),
        answer:
          gettext(
            "The interface is available in Portuguese (Brazil), English, French and Spanish. Switch from the header menu — your choice sticks across sessions."
          )
      }
    ]
  end
end
