defmodule EarthScannerWeb.UserRegistrationControllerTest do
  use EarthScannerWeb.ConnCase, async: true

  @moduletag :registration

  describe "GET /users/register" do
    test "renders registration page with expected fields", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      html = html_response(conn, 200)

      assert html =~ "Register"
      assert html =~ ~s/name=\"user[email]\"/
      assert html =~ ~s/name=\"user[password]\"/
      assert html =~ to_string(~p"/users/log-in")
    end
  end

  describe "POST /users/register" do
    test "with valid data redirects to log in and does not log in immediately", %{conn: conn} do
      email = "user" <> Integer.to_string(System.unique_integer([:positive])) <> "@example.com"

      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{
            "email" => email,
            "password" => "verylongpassword"
          }
        })

  assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "with invalid data re-renders page with errors", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{
            "email" => "with spaces",
            "password" => "short"
          }
        })

      html = html_response(conn, 200)
      assert html =~ "Register"
      assert html =~ "error"
    end
  end
end
