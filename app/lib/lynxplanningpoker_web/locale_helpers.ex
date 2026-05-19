defmodule LynxplanningpokerWeb.LocaleHelpers do
  @moduledoc """
  Locale-aware view helpers. Imported into templates via `html_helpers/0` in
  `LynxplanningpokerWeb`.
  """

  @doc """
  Formats a `Date` according to the user's current locale.

      iex> format_date(~D[2026-05-19], "pt_BR")
      "19/05/2026"

      iex> format_date(~D[2026-05-19], "fr")
      "19/05/2026"

      iex> format_date(~D[2026-05-19], "en")
      "2026-05-19"
  """
  @spec format_date(Date.t(), String.t()) :: String.t()
  def format_date(%Date{} = date, "pt_BR"), do: Calendar.strftime(date, "%d/%m/%Y")
  def format_date(%Date{} = date, "fr"), do: Calendar.strftime(date, "%d/%m/%Y")
  def format_date(%Date{} = date, _locale), do: Calendar.strftime(date, "%Y-%m-%d")
end
