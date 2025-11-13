defmodule EarthScannerWeb.AdminUserControllerTest do
  use EarthScannerWeb.ConnCase

  alias EarthScanner.Accounts

  @valid_attrs %{
    "username" => "newadmin",
    "email" => "newadmin@example.com",
    "phone_number" => "+12345678",
    "password" => "Password123!",
    "password_confirmation" => "Password123!"
  }

  @invalid_attrs %{
    "username" => "",
    "email" => "",
    "phone_number" => "",
    "password" => "",
    "password_confirmation" => ""
  }

  #
  # TEST 1:
  # Non-admin users should be redirected away from /admin/users/new
  #
  test "GET /admin/users/new redirects non-admin user to /users/login", %{conn: conn} do
    conn = get(conn, "/admin/users/new")
    assert redirected_to(conn) == "/users/login"
  end

  #
  # TEST 2:
  # Non-admin posting admin creation also redirected
  #
  test "POST /admin/users non-admin cannot create admin", %{conn: conn} do
    conn = post(conn, "/admin/users", %{"user" => @valid_attrs})
    assert redirected_to(conn) == "/users/login"
  end

  #
  # TEST 3:
  # Non-admin submitting invalid data also redirected
  #
  test "POST /admin/users invalid data still redirects non-admin", %{conn: conn} do
    conn = post(conn, "/admin/users", %{"user" => @invalid_attrs})
    assert redirected_to(conn) == "/users/login"
  end
end
