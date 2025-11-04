defmodule EarthScannerWeb.SessionController do
  use EarthScannerWeb, :controller

  def new(conn, _params) do
    render(conn, :new)
  end
end
