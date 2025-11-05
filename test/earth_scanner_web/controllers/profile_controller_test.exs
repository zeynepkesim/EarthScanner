defmodule EarthScannerWeb.ProfileControllerTest do
  use EarthScannerWeb.ConnCase, async: true

  alias EarthScanner.Accounts

  test "redirects to login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/profile")
    assert redirected_to(conn) == ~p"/users/login"
    assert get_flash(conn, :error) =~ "Please log in"
  end

  test "renders profile with user info when logged in", %{conn: conn} do
    uniq = Integer.to_string(System.unique_integer([:positive]))
    email = "profile" <> uniq <> "@example.com"

    {:ok, _user} =
      Accounts.register_user(%{
        "username" => "prof_user_" <> uniq,
        "password" => "verylongpassword",
        "password_confirmation" => "verylongpassword",
        "name" => "Eve",
        "last_name" => "Ada",
        "email" => email,
        "birthdate" => "1992-02-02",
        "nationality" => "ID",
        "residence_address" => "Jl. Profile 1",
        "phone_number" => "+620000000002"
      })

    conn =
      conn
      |> post(~p"/users/login", %{
        "session" => %{"email" => email, "password" => "verylongpassword"}
      })

    conn = get(recycle(conn), ~p"/profile")
    html = html_response(conn, 200)
    assert html =~ "Your profile"
    assert html =~ email
    assert html =~ "Eve"
    assert html =~ "Ada"
  end
end
