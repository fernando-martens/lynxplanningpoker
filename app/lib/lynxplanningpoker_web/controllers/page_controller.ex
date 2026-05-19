defmodule LynxplanningpokerWeb.PageController do
  use LynxplanningpokerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def how_it_works(conn, _params) do
    render(conn, :how_it_works)
  end

  def pricing(conn, _params) do
    render(conn, :pricing)
  end

  def privacy(conn, _params) do
    render(conn, :privacy)
  end
end
