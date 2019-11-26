defmodule TeslaMateWeb.ChargeController do
  use TeslaMateWeb, :controller

  require Logger

  alias TeslaMate.Api, warn: false
  alias TeslaMate.{Log, Vehicles}

  plug :fetch_signed_in when action in [:index]
  plug :redirect_unless_signed_in when action in [:index]

  action_fallback TeslaMateWeb.FallbackController

  def get_charge_cost(conn, %{"id" => id}) do
  end

  def get_charge_processes(conn) do
  end

  def set_charge_cost(conn, %{"id" => id}) do
  end

  case Mix.env() do
    :test -> defp fetch_signed_in(conn, _opts), do: conn
    _____ -> defp fetch_signed_in(conn, _opts), do: assign(conn, :signed_in?, Api.signed_in?())
  end

  defp redirect_unless_signed_in(%Plug.Conn{assigns: %{signed_in?: true}} = conn, _), do: conn
  defp redirect_unless_signed_in(conn, _opts), do: conn |> redirect(to: sign_in(conn)) |> halt()

  defp sign_in(conn), do: Routes.live_path(conn, TeslaMateWeb.SignInLive.Index)
end
