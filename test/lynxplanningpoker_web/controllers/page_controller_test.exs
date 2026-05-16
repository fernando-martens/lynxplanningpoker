defmodule LynxplanningpokerWeb.PageControllerTest do
  use LynxplanningpokerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Lynx planning poker"
  end

  test "GET /how-it-works renders the three steps", %{conn: conn} do
    conn = get(conn, ~p"/how-it-works")
    response = html_response(conn, 200)
    assert response =~ "How it works"
    assert response =~ "Create a room"
    assert response =~ "Invite your team"
    assert response =~ "Vote and reveal"
  end
end
