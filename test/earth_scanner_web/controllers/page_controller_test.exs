defmodule EarthScannerWeb.PageControllerTest do
  use EarthScannerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Explore upcoming trips"
  end
end
