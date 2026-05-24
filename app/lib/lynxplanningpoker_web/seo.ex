defmodule LynxplanningpokerWeb.SEO do
  @moduledoc """
  Builds the schema.org structured data (JSON-LD) embedded in page heads.

  Rich, machine-readable metadata helps search engines understand the site and
  unlocks rich results — notably the FAQ accordion rendered straight in Google
  search for the "how it works" page.
  """

  alias LynxplanningpokerWeb.Endpoint

  @doc "Absolute base URL of the canonical site, e.g. `https://lynxplanningpoker.com`."
  def base_url, do: Endpoint.url()

  @doc """
  Turns an absolute path (`/`, `/en/pricing`, ...) into a fully-qualified URL on
  the canonical host. Used for `canonical`, `hreflang` and `og:url` tags.
  """
  def absolute_url("/" <> _ = path), do: base_url() <> path

  @doc """
  `WebApplication` document describing the product itself. Emitted on the home
  page so the whole site has a single canonical entity for search engines.
  """
  def web_application(description) do
    %{
      "@context" => "https://schema.org",
      "@type" => "WebApplication",
      "name" => "Lynx Planning Poker",
      "alternateName" => "Lynx Poker",
      "url" => base_url() <> "/",
      "description" => description,
      "applicationCategory" => "BusinessApplication",
      "operatingSystem" => "Any (modern web browser)",
      "browserRequirements" => "Requires JavaScript and a modern web browser.",
      "inLanguage" => ["pt-BR", "en", "fr", "es"],
      "isAccessibleForFree" => true,
      "offers" => %{
        "@type" => "Offer",
        "price" => "0",
        "priceCurrency" => "USD"
      }
    }
  end

  @doc """
  `FAQPage` document built from a list of `%{question: _, answer: _}` maps.
  Eligible for the FAQ rich result in search.
  """
  def faq_page(faqs) when is_list(faqs) do
    %{
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" =>
        Enum.map(faqs, fn %{question: question, answer: answer} ->
          %{
            "@type" => "Question",
            "name" => question,
            "acceptedAnswer" => %{
              "@type" => "Answer",
              "text" => answer
            }
          }
        end)
    }
  end
end
