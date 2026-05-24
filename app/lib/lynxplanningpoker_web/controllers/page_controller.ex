defmodule LynxplanningpokerWeb.PageController do
  use LynxplanningpokerWeb, :controller

  alias LynxplanningpokerWeb.PageHTML
  alias LynxplanningpokerWeb.SEO

  def home(conn, _params) do
    conn
    |> assign(:page_title, gettext("Planning poker for agile teams · Lynx planning poker"))
    |> assign(
      :meta_description,
      gettext(
        "Run free, real-time planning poker with your agile team. No sign-up, no install — just create a room, share the link, and estimate user stories in seconds."
      )
    )
    |> assign(:structured_data, [
      SEO.web_application(
        gettext(
          "A free, real-time planning poker tool for agile and scrum teams. Create a room, invite your team and estimate user stories together — no sign-up required."
        )
      )
    ])
    |> render(:home)
  end

  def how_it_works(conn, _params) do
    conn
    |> assign(:page_title, gettext("How Planning Poker Works · Lynx Poker"))
    |> assign(
      :meta_description,
      gettext(
        "Learn to run a planning poker session in under a minute: create a room, invite your team, vote on a user story and reveal the estimate together."
      )
    )
    |> assign(:structured_data, [SEO.faq_page(PageHTML.faqs())])
    |> render(:how_it_works)
  end

  def pricing(conn, _params) do
    conn
    |> assign(:page_title, gettext("Pricing · Lynx Poker"))
    |> assign(
      :meta_description,
      gettext(
        "Lynx Planning Poker is free forever: unlimited rooms, up to 15 players and real-time voting. No credit card, no ads, no catch."
      )
    )
    |> render(:pricing)
  end

  def privacy(conn, _params) do
    conn
    |> assign(:page_title, gettext("Privacy & Data Protection · Lynx Poker"))
    |> assign(
      :meta_description,
      gettext(
        "How Lynx Planning Poker handles your data under the GDPR and the LGPD. Rooms are ephemeral and deleted automatically — no ads and no data selling."
      )
    )
    |> render(:privacy)
  end

  def security(conn, _params) do
    conn
    |> assign(:page_title, gettext("Security · Lynx Poker"))
    |> assign(
      :meta_description,
      gettext(
        "How Lynx Planning Poker keeps your planning sessions secure: HTTPS everywhere, a strict Content-Security-Policy, hardened sessions, unguessable room links and abuse protection."
      )
    )
    |> render(:security)
  end
end
