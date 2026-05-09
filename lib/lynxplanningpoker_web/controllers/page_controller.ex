defmodule LynxplanningpokerWeb.PageController do
  use LynxplanningpokerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
