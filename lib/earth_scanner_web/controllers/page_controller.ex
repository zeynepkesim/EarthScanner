defmodule EarthScannerWeb.PageController do
  use EarthScannerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
