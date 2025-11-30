defmodule EarthScannerWeb.NFR07SecureAuthenticationTest do
  use EarthScannerWeb.ConnCase, async: true

  alias EarthScanner.Accounts
  import Plug.Conn

  @moduletag :nfr07

  defp register_user(_) do
    email = "nfr07_" <> Integer.to_string(:erlang.unique_integer([:positive])) <> "@test.com"
    password = "Password123!"

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "nfr07_user",
        "password" => password,
        "password_confirmation" => password,
        "name" => "Test",
        "last_name" => "User",
        "email" => email,
        "birthdate" => "2000-01-01",
        "nationality" => "ID",
        "residence_address" => "Somewhere",
        "phone_number" => "+62000000000"
      })

    %{user: user, email: email, password: password}
  end

  # ---------------------------------------------------------
  # POSITIVE: Successful login rotates session
  # ---------------------------------------------------------
  test "successful login rotates the session ID", %{conn: conn} do
    %{email: email, password: password} = register_user(nil)

    # Initial session cookie before login
    conn = get(conn, "/users/login")
    before = get_session_cookie(conn)

    # Perform login
    conn =
      post(conn, "/users/login", session: %{"email" => email, "password" => password})

    after_login = get_session_cookie(conn)

    # Cookie must change
    refute before == after_login
  end

  # ---------------------------------------------------------
  # NEGATIVE: Wrong password → no session created
  # ---------------------------------------------------------
  test "wrong password does not authenticate", %{conn: conn} do
    %{email: email} = register_user(nil)

    conn =
      post(conn, "/users/login", session: %{"email" => email, "password" => "Wrong123!"})

    assert html_response(conn, 200) =~ "Invalid email or password"
    refute get_session(conn, :user_id)
  end

  # ---------------------------------------------------------
  # NEGATIVE: Unknown email rejected
  # ---------------------------------------------------------
  test "unknown email is rejected", %{conn: conn} do
    conn =
      post(conn, "/users/login",
        session: %{"email" => "nope@example.com", "password" => "Whatever123!"}
      )

    assert html_response(conn, 200) =~ "Invalid email or password"
  end

  # ---------------------------------------------------------
  # POSITIVE: Logout rotates session
  # ---------------------------------------------------------
  test "logout rotates the session", %{conn: conn} do
    %{email: email, password: password} = register_user(nil)

    # login
    conn =
      post(build_conn(), "/users/login", session: %{"email" => email, "password" => password})

    cookie_after_login = get_session_cookie(conn)

    conn = delete(conn, "/users/logout")
    cookie_after_logout = get_session_cookie(conn)

    refute cookie_after_login == cookie_after_logout
  end

  # ---------------------------------------------------------
  # POSITIVE: Session cookie is encrypted and signed
  # This ensures Phoenix encodes it properly (string, not nil)
  # ---------------------------------------------------------
  test "session cookie is present and properly formatted after login" do
    %{email: email, password: password} = register_user(nil)

    conn =
      post(build_conn(), "/users/login", session: %{"email" => email, "password" => password})

    cookie = get_session_cookie(conn)
    assert is_binary(cookie)
    refute cookie =~ "_earth_scanner_key"
  end

  # ---------------------------------------------------------
  # NEGATIVE: Invalid registration rejected
  # ---------------------------------------------------------
  test "invalid registration is rejected", %{conn: conn} do
    conn =
      post(conn, "/users/register",
        user: %{
          "username" => "",
          "email" => "bad",
          "password" => "short",
          "password_confirmation" => "nomatch"
        }
      )

    body = html_response(conn, 200)
    assert body =~ "errors"
    assert body =~ "fix"
  end

  # ---------------------------------------------------------
  # NEGATIVE: Registration with mismatched pwd rejected
  # ---------------------------------------------------------
  test "registration fails when passwords mismatch", %{conn: conn} do
    conn =
      post(conn, "/users/register",
        user: %{
          "username" => "abc",
          "email" => "abc@test.com",
          "password" => "Password123!",
          "password_confirmation" => "xxx"
        }
      )

    assert html_response(conn, 200) =~ "does not match"
  end

  # ---------------------------------------------------------
  # HELPERS
  # ---------------------------------------------------------

  defp get_session_cookie(conn) do
    conn.resp_cookies["_earth_scanner_key"][:value]
  rescue
    _ -> nil
  end
end
