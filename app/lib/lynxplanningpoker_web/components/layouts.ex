defmodule LynxplanningpokerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LynxplanningpokerWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
              Get Started <span aria-hidden="true">&rarr;</span>
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders the settings button (cog icon) with a dropdown panel that exposes
  the theme toggle and the language switcher. Sits in place of the bare
  controls in the public and room headers.
  """
  def settings_menu(assigns) do
    ~H"""
    <div class="relative" phx-click-away={JS.hide(to: "#settings-panel")}>
      <button
        type="button"
        class="btn btn-ghost btn-circle"
        phx-click={JS.toggle(to: "#settings-panel")}
        aria-label={gettext("Settings")}
      >
        <.icon name="hero-cog-6-tooth" class="size-5" />
      </button>
      <div
        id="settings-panel"
        class="hidden absolute right-0 top-full mt-2 z-50 w-64 rounded-2xl border border-base-300 bg-base-100 shadow-xl p-4 space-y-4"
        role="menu"
      >
        <div class="flex items-center justify-between gap-3">
          <span class="text-xs font-semibold uppercase tracking-wide text-base-content/70">
            {gettext("Theme")}
          </span>
          <.theme_toggle />
        </div>
        <div class="flex items-center justify-between gap-3">
          <span class="text-xs font-semibold uppercase tracking-wide text-base-content/70">
            {gettext("Language")}
          </span>
          <.language_switcher />
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the language switcher as a dropdown.

  The trigger shows the current locale's flag and code; clicking reveals the
  other two options. Each option is a regular link to `/locale/:locale` which
  sets the session locale via `LocaleController` and bounces back via the
  `Referer` header.
  """
  def language_switcher(assigns) do
    locale = Gettext.get_locale(LynxplanningpokerWeb.Gettext)
    others = LynxplanningpokerWeb.Gettext.locales() -- [locale]

    assigns =
      assigns
      |> assign(:locale, locale)
      |> assign(:others, others)

    ~H"""
    <div class="relative" phx-click-away={JS.hide(to: "#language-options")}>
      <button
        type="button"
        class="flex items-center gap-2 rounded-full border border-base-300 bg-base-100 px-3 py-1.5 text-xs font-semibold uppercase tracking-wide cursor-pointer hover:brightness-95"
        phx-click={JS.toggle(to: "#language-options")}
        aria-haspopup="listbox"
        aria-label={gettext("Language")}
      >
        <.flag locale={@locale} class="h-3 w-5 rounded-sm overflow-hidden" />
        <span>{locale_label(@locale)}</span>
        <.icon name="hero-chevron-down-micro" class="size-3 opacity-70" />
      </button>
      <ul
        id="language-options"
        class="hidden absolute right-0 top-full mt-2 z-50 w-32 rounded-xl border border-base-300 bg-base-100 shadow-lg overflow-hidden text-xs font-semibold uppercase tracking-wide"
        role="listbox"
      >
        <li :for={other <- @others}>
          <.link
            href={~p"/locale/#{other}"}
            class="flex items-center gap-2 px-3 py-2 hover:bg-base-200"
            role="option"
          >
            <.flag locale={other} class="h-3 w-5 rounded-sm overflow-hidden" />
            <span>{locale_label(other)}</span>
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  defp locale_label("pt_BR"), do: "PT"
  defp locale_label("en"), do: "EN"
  defp locale_label("fr"), do: "FR"
  defp locale_label(_), do: "?"

  attr :locale, :string, required: true
  attr :class, :any, default: nil

  defp flag(%{locale: "pt_BR"} = assigns) do
    ~H"""
    <svg viewBox="0 0 28 20" xmlns="http://www.w3.org/2000/svg" class={@class}>
      <rect width="28" height="20" fill="#009c3b" />
      <polygon points="14,3 25,10 14,17 3,10" fill="#ffdf00" />
      <circle cx="14" cy="10" r="3.5" fill="#002776" />
    </svg>
    """
  end

  defp flag(%{locale: "en"} = assigns) do
    ~H"""
    <svg viewBox="0 0 28 20" xmlns="http://www.w3.org/2000/svg" class={@class}>
      <rect width="28" height="20" fill="#fff" />
      <rect y="0" width="28" height="2.86" fill="#b22234" />
      <rect y="5.71" width="28" height="2.86" fill="#b22234" />
      <rect y="11.43" width="28" height="2.86" fill="#b22234" />
      <rect y="17.14" width="28" height="2.86" fill="#b22234" />
      <rect width="11" height="11.43" fill="#3c3b6e" />
    </svg>
    """
  end

  defp flag(%{locale: "fr"} = assigns) do
    ~H"""
    <svg viewBox="0 0 28 20" xmlns="http://www.w3.org/2000/svg" class={@class}>
      <rect width="9.33" height="20" fill="#002654" />
      <rect x="9.33" width="9.33" height="20" fill="#fff" />
      <rect x="18.66" width="9.33" height="20" fill="#ce1126" />
    </svg>
    """
  end

  defp flag(assigns), do: ~H""

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  @doc """
  Renders the shared application header used on public pages.
  """
  attr :class, :string, default: nil

  def app_header(assigns) do
    assigns = assign(assigns, :class, assigns.class || "")

    ~H"""
    <header class={[
      "sticky top-0 z-50 border-b border-base-200/60 backdrop-blur",
      @class
    ]}>
      <div class="max-w-6xl mx-auto w-full px-6 py-6 flex justify-between items-center">
        <.link navigate="/" class="flex items-center gap-2">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="32"
            height="32"
            fill="var(--color-base-content)"
            viewBox="0 0 256 256"
          >
            <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,152a48,48,0,1,1,48-48A48.05,48.05,0,0,1,128,176Zm39.21-98.53a63.66,63.66,0,0,0-31.21-13V40.37a87.6,87.6,0,0,1,48.28,20ZM120,64.52a63.66,63.66,0,0,0-31.21,13L71.72,60.4a87.6,87.6,0,0,1,48.28-20ZM77.47,88.79a63.66,63.66,0,0,0-13,31.21H40.37a87.6,87.6,0,0,1,20-48.28ZM64.52,136a63.66,63.66,0,0,0,13,31.21L60.4,184.28a87.6,87.6,0,0,1-20-48.28Zm24.27,42.53A63.66,63.66,0,0,0,120,191.48v24.15a87.6,87.6,0,0,1-48.28-20ZM136,191.48a63.66,63.66,0,0,0,31.21-12.95l17.07,17.07a87.6,87.6,0,0,1-48.28,20Zm42.53-24.27A63.66,63.66,0,0,0,191.48,136h24.15a87.6,87.6,0,0,1-20,48.28ZM191.48,120a63.66,63.66,0,0,0-12.95-31.21L195.6,71.72a87.6,87.6,0,0,1,20,48.28Z" />
          </svg>
          <span class="text-xl font-bold tracking-tight">Lynx planning poker</span>
        </.link>

        <nav class="hidden md:flex items-center gap-2 font-semibold">
          <.button navigate={~p"/how-it-works"}>
            <.icon name="hero-book-open" class="size-5" /> {gettext("Features")}
          </.button>
          <.button navigate={~p"/pricing"}>
            <.icon name="hero-currency-dollar" class="size-5" /> {gettext("Pricing")}
          </.button>
          <.link href="#" class="flex items-center gap-2 hover:opacity-70 transition">
            <img
              src="/images/bmc.png"
              alt="Buy me a coffee"
              class="relative w-32"
            />
          </.link>
          <.settings_menu />
        </nav>
      </div>
    </header>
    """
  end

  @doc """
  Renders the shared application header used on public pages.
  """
  attr :class, :string, default: nil
  attr :is_host, :boolean, default: false

  def room_header(assigns) do
    assigns = assign(assigns, :class, assigns.class || "")

    ~H"""
    <header class={[
      "absolute top-0 left-0 right-0 z-50 border-b border-base-200/60 pointer-events-none",
      @class
    ]}>
      <div class="max-w-6xl mx-auto w-full px-3 py-3 md:px-6 md:py-6 flex justify-between items-center gap-2">
        <div class="flex items-center gap-2 min-w-0 pointer-events-auto">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="32"
            height="32"
            fill="var(--color-base-content)"
            viewBox="0 0 256 256"
            class="shrink-0"
          >
            <path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,152a48,48,0,1,1,48-48A48.05,48.05,0,0,1,128,176Zm39.21-98.53a63.66,63.66,0,0,0-31.21-13V40.37a87.6,87.6,0,0,1,48.28,20ZM120,64.52a63.66,63.66,0,0,0-31.21,13L71.72,60.4a87.6,87.6,0,0,1,48.28-20ZM77.47,88.79a63.66,63.66,0,0,0-13,31.21H40.37a87.6,87.6,0,0,1,20-48.28ZM64.52,136a63.66,63.66,0,0,0,13,31.21L60.4,184.28a87.6,87.6,0,0,1-20-48.28Zm24.27,42.53A63.66,63.66,0,0,0,120,191.48v24.15a87.6,87.6,0,0,1-48.28-20ZM136,191.48a63.66,63.66,0,0,0,31.21-12.95l17.07,17.07a87.6,87.6,0,0,1-48.28,20Zm42.53-24.27A63.66,63.66,0,0,0,191.48,136h24.15a87.6,87.6,0,0,1-20,48.28ZM191.48,120a63.66,63.66,0,0,0-12.95-31.21L195.6,71.72a87.6,87.6,0,0,1,20,48.28Z" />
          </svg>
          <span class="hidden sm:inline text-xl font-bold tracking-tight truncate">
            Lynx planning poker
          </span>
        </div>

        <nav class="flex items-center gap-1 md:gap-2 font-semibold pointer-events-auto">
          <.button phx-click="reset" class="room-header-btn" aria-label={gettext("Restart")}>
            <.icon name="hero-arrow-path" class="size-5" />
            <span class="hidden md:inline">{gettext("Restart")}</span>
          </.button>
          <.button
            phx-click={show_modal("invite-modal")}
            class="room-header-btn"
            aria-label={gettext("Invite")}
          >
            <.icon name="hero-user-plus" class="size-5" />
            <span class="hidden md:inline">{gettext("Invite")}</span>
          </.button>
          <%= if @is_host do %>
            <.button
              phx-click="end_planning"
              variant="red"
              class="room-header-btn"
              aria-label={gettext("End planning")}
            >
              <.icon name="hero-x-circle" class="size-5" />
              <span class="hidden md:inline">{gettext("End planning")}</span>
            </.button>
          <% else %>
            <.button
              phx-click="leave_room"
              variant="red"
              class="room-header-btn"
              aria-label={gettext("Leave")}
            >
              <.icon name="hero-x-circle" class="size-5" />
              <span class="hidden md:inline">{gettext("Leave")}</span>
            </.button>
          <% end %>
          <.settings_menu />
        </nav>
      </div>
    </header>
    """
  end
end
