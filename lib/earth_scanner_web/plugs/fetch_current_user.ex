defmodule EarthScannerWeb.FetchCurrentUser do
  @moduledoc false
  import Plug.Conn
  alias EarthScanner.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user =
      conn
      |> get_session(:user_id)
      |> case do
        nil -> nil
        id -> Accounts.get_user_by_id(id)
      end

    assign(conn, :current_user, user)
  end
end
