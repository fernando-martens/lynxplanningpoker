defmodule LynxplanningpokerWeb.Router do
  use LynxplanningpokerWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {LynxplanningpokerWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(LynxplanningpokerWeb.Plugs.ContentSecurityPolicy)
    plug(LynxplanningpokerWeb.Plugs.Locale)

    plug(LynxplanningpokerWeb.Plugs.RateLimit,
      bucket: :global,
      config: :global
    )

    plug(LynxplanningpokerWeb.Plugs.CountVisit)
  end

  pipeline :rate_limit_room_create do
    plug(LynxplanningpokerWeb.Plugs.RateLimit,
      bucket: :room_create,
      config: :room_create
    )
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Default-locale (pt_BR) public pages, served prefix-free at the URL root.
  scope "/", LynxplanningpokerWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    get("/how-it-works", PageController, :how_it_works)
    get("/pricing", PageController, :pricing)
    get("/privacy", PageController, :privacy)
    get("/security", PageController, :security)
    get("/rooms/new", RoomController, :new)

    get("/locale/:locale", LocaleController, :update)

    scope "/rooms" do
      get("/invite/:id", RoomController, :show)
      post("/invite/:id", RoomController, :accept_invite)
      get("/leave", RoomController, :leave)

      live_session :default, on_mount: LynxplanningpokerWeb.LiveHooks.Locale do
        live("/:id", RoomLive.Show, :show)
      end
    end
  end

  # Locale-prefixed copies of the public pages and the room-entry flow
  # (`/pt-br`, `/fr`, `/es`). Each non-default language gets a distinct,
  # crawlable URL so search engines can index every version, and the
  # room-creation/invite pages render in the locale of the URL the visitor
  # actually came through. The `Plugs.Locale` plug picks the locale up from the
  # path segment. The live room (`/rooms/:id`) stays prefix-free — its link is
  # shared, so it follows the session locale instead.
  for segment <- LynxplanningpokerWeb.Locales.url_segments() do
    scope "/#{segment}", LynxplanningpokerWeb do
      pipe_through(:browser)

      get("/", PageController, :home)
      get("/how-it-works", PageController, :how_it_works)
      get("/pricing", PageController, :pricing)
      get("/privacy", PageController, :privacy)
      get("/security", PageController, :security)

      get("/rooms/new", RoomController, :new)
      get("/rooms/invite/:id", RoomController, :show)
      post("/rooms/invite/:id", RoomController, :accept_invite)
    end

    scope "/#{segment}", LynxplanningpokerWeb do
      pipe_through([:browser, :rate_limit_room_create])

      post("/rooms", RoomController, :create)
    end
  end

  # XML sitemap. Kept out of the :browser pipeline so the `.xml` path doesn't
  # trip the `accepts ["html"]` content negotiation; the controller sets the
  # content type and body itself.
  scope "/", LynxplanningpokerWeb do
    get("/sitemap.xml", SitemapController, :index)
  end

  scope "/", LynxplanningpokerWeb do
    pipe_through([:browser, :rate_limit_room_create])

    post("/rooms", RoomController, :create)
  end

  # Other scopes may use custom stacks.
  # scope "/api", LynxplanningpokerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:lynxplanningpoker, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: LynxplanningpokerWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
