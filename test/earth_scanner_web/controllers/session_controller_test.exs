defmodule EarthScannerWeb.SessionControllerTest do
  # nfr-04: TDD - login tests rely on hashed passwords created during registration
  use EarthScannerWeb.ConnCase, async: true

  alias EarthScanner.Accounts

  describe "GET /users/login" do
    test "renders login page with form fields", %{conn: conn} do
      conn = get(conn, ~p"/users/login")
      html = html_response(conn, 200)

      assert html =~ "Log in"
      assert html =~ ~s/name=\"session[email]\"/
      assert html =~ ~s/name=\"session[password]\"/
      assert html =~ ~s/id=\"login-form\"/
      assert html =~ to_string(~p"/users/login")
    end
  end

  describe "POST /users/login" do
    setup do
      uniq = Integer.to_string(System.unique_integer([:positive]))
      email = "login" <> uniq <> "@example.com"

      {:ok, _user} =
        Accounts.register_user(%{
          "username" => "login_user_" <> uniq,
          "password" => "verylongpassword",
          "password_confirmation" => "verylongpassword",
          "name" => "Test",
          "last_name" => "User",
          "email" => email,
          "birthdate" => "1990-01-01",
          "nationality" => "ID",
          "residence_address" => "Jl. Test 123",
          "phone_number" => "+620000000000"
        })

      {:ok, email: email}
    end

    test "with valid credentials redirects to home and sets session", %{conn: conn, email: email} do
      conn =
        post(conn, ~p"/users/login", %{
          "session" => %{"email" => email, "password" => "verylongpassword"}
        })

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_id)
    end

    test "with invalid credentials re-renders with error", %{conn: conn, email: email} do
      conn =
        post(conn, ~p"/users/login", %{
          "session" => %{"email" => email, "password" => "wrongpass"}
        })

      html = html_response(conn, 200)
      assert html =~ "Log in"
      assert html =~ "Invalid email or password"
    end

    test "with unknown email re-renders with error", %{conn: conn} do
      conn =
        post(conn, ~p"/users/login", %{
          "session" => %{"email" => "nobody@example.com", "password" => "whateverlong"}
        })

      html = html_response(conn, 200)
      assert html =~ "Log in"
      assert html =~ "Invalid email or password"
    end
  end

  describe "DELETE /users/logout" do
    test "clears session and redirects to login", %{conn: conn} do
      # log in first
      uniq = Integer.to_string(System.unique_integer([:positive]))
      email = "logout" <> uniq <> "@example.com"

      {:ok, _} =
        Accounts.register_user(%{
          "username" => "logout_user_" <> uniq,
          "password" => "verylongpassword",
          "password_confirmation" => "verylongpassword",
          "name" => "Out",
          "last_name" => "User",
          "email" => email,
          "birthdate" => "1990-01-01",
          "nationality" => "ID",
          "residence_address" => "Jl. Test 999",
          "phone_number" => "+620000000001"
        })

      conn =
        conn
        |> post(~p"/users/login", %{
          "session" => %{"email" => email, "password" => "verylongpassword"}
        })

      assert get_session(conn, :user_id)

      conn = delete(recycle(conn), ~p"/users/logout")
      assert redirected_to(conn) == ~p"/users/login"
      # session cleared in a renewed session
      refute get_session(conn, :user_id)
    end
  end
end
