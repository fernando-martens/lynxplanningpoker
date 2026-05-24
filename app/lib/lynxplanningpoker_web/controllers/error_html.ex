defmodule LynxplanningpokerWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use LynxplanningpokerWeb, :html

  embed_templates("error_html/*")

  # Fallback for templates we don't define explicitly: render a plain text
  # page based on the template name (e.g. "404.html" -> "Not Found").
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
