defmodule EarthScanner.Accounts.UserNfr04Test do
  use EarthScanner.DataCase, async: true

  alias EarthScanner.Accounts

  @moduletag :nfr04

  test "registration stores a hashed password and verification succeeds" do
    raw_password = "SuperSecret!123"
    unique = Integer.to_string(System.unique_integer([:positive]))
    email = "nfr04_#{unique}@example.com"

    attrs = %{
      "username" => "nfr04_user_#{unique}",
      "email" => email,
      "password" => raw_password,
      "password_confirmation" => raw_password,
      "name" => "NFR",
      "last_name" => "Test",
      "birthdate" => "1990-01-01",
      "nationality" => "EE",
      "residence_address" => "Test St 1",
      "phone_number" => "+37255500000"
    }

    {:ok, user} = Accounts.register_user(attrs)

    # TDD for nfr-04: password_hash must be present and must not equal the raw password
    assert user.password_hash != nil
    refute user.password_hash == raw_password

    # Verify the hashed password actually matches the raw password
    assert Pbkdf2.verify_pass(raw_password, user.password_hash)
  end
end
