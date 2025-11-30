defmodule EarthScannerWeb.PageControllerTest do
  use EarthScannerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Explore upcoming trips"
  end

  # FR-19: Account access links visible to all users
  test "GET / shows account section with login and register for unauthenticated users", %{
    conn: conn
  } do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Log In"
    assert html =~ "Register"
    assert html =~ "Account"
  end

  # FR-19: Account access links adapt to logged-in state
  test "GET / shows profile and logout links in header for authenticated users", %{conn: conn} do
    # Create a real user in the database
    {:ok, user} =
      EarthScanner.Accounts.register_user(%{
        "username" => "testuser",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Test",
        "last_name" => "User",
        "email" => "test@example.com",
        "birthdate" => "1990-01-01",
        "nationality" => "US",
        "residence_address" => "123 Main St",
        "phone_number" => "+1234567890"
      })

    conn =
      conn
      |> init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> EarthScannerWeb.FetchCurrentUser.call([])
      |> get(~p"/")

    html = html_response(conn, 200)
    # The header should show Profile link and logout button for logged-in users
    assert html =~ "Profile"
    assert html =~ "Log out"
  end

  # FR-19: Negative test - unauthenticated users should NOT see Profile or logout
  test "GET / does not show profile or logout for unauthenticated users", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    refute html =~ "Profile"
    refute html =~ "Log out"
  end

  # FR-19: Negative test - authenticated users should NOT see login/register in account section
  test "GET / does not show login/register in account section for authenticated users", %{
    conn: conn
  } do
    {:ok, user} =
      EarthScanner.Accounts.register_user(%{
        "username" => "authenticateduser",
        "password" => "Password123!",
        "password_confirmation" => "Password123!",
        "name" => "Auth",
        "last_name" => "User",
        "email" => "auth@example.com",
        "birthdate" => "1990-01-01",
        "nationality" => "US",
        "residence_address" => "456 Oak Ave",
        "phone_number" => "+0987654321"
      })

    conn =
      conn
      |> init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> EarthScannerWeb.FetchCurrentUser.call([])
      |> get(~p"/")

    html = html_response(conn, 200)

    # For authenticated users, should see Account Details and Log Out, NOT Log In or Register in account section
    assert html =~ "Account"
    assert html =~ "Account Details"
    assert html =~ "Log Out"
    # Should NOT see Log In or Register in the account section (they appear elsewhere)
    refute html =~ "Log In" or html =~ "Register"
  end

  # FR-19: Negative test - ensure the page returns 200 OK in all cases
  test "GET / always returns 200 status code", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert conn.status == 200
  end
end
