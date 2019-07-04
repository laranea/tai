defmodule Tai.VenueAdapters.Bitmex.CreateOrder do
  @moduledoc """
  Create orders for the Bitmex adapter
  """

  alias Tai.VenueAdapters.Bitmex.{ClientId, Products}
  import Tai.VenueAdapters.Bitmex.OrderStatus

  @type credentials :: Tai.Venues.Adapter.credentials()
  @type order :: Tai.Trading.Order.t()
  @type response :: Tai.Trading.OrderResponses.Create.t()
  @type reason ::
          :timeout
          | :connect_timeout
          | :overloaded
          | :insufficient_balance
          | {:nonce_not_increasing, msg :: String.t()}
          | {:unhandled, term}

  @spec create_order(order, credentials) :: {:ok, response} | {:error, reason}
  def create_order(%Tai.Trading.Order{} = order, credentials) do
    params = build_params(order)

    credentials
    |> to_venue_credentials
    |> send_to_venue(params)
    |> parse_response(order)
  end

  @limit "Limit"
  defp build_params(order) do
    venue_client_order_id = ClientId.to_venue(order.client_id, order.time_in_force)

    params = %{
      clOrdID: venue_client_order_id,
      side: order.side |> to_venue_side,
      ordType: @limit,
      symbol: order.product_symbol |> to_venue_symbol,
      orderQty: order.qty,
      price: order.price,
      timeInForce: order.time_in_force |> to_venue_time_in_force
    }

    if order.post_only do
      params |> Map.put("execInst", "ParticipateDoNotInitiate")
    else
      params
    end
  end

  defdelegate send_to_venue(credentials, params),
    to: ExBitmex.Rest.Orders,
    as: :create

  defdelegate to_venue_credentials(credentials),
    to: Tai.VenueAdapters.Bitmex.Credentials,
    as: :from

  @buy "Buy"
  @sell "Sell"
  defp to_venue_side(:buy), do: @buy
  defp to_venue_side(:sell), do: @sell

  defdelegate to_venue_symbol(symbol), to: Products, as: :from_symbol

  defp to_venue_time_in_force(:gtc), do: "GoodTillCancel"
  defp to_venue_time_in_force(:ioc), do: "ImmediateOrCancel"
  defp to_venue_time_in_force(:fok), do: "FillOrKill"

  @format "{ISO:Extended}"
  defp parse_response(
         {:ok, %ExBitmex.Order{} = venue_order, %ExBitmex.RateLimit{}},
         order
       ) do
    received_at = Timex.now()
    avg_price = (venue_order.avg_px && Decimal.cast(venue_order.avg_px)) || Decimal.new(0)

    response = %Tai.Trading.OrderResponses.Create{
      id: venue_order.order_id,
      status: venue_order.ord_status |> from_venue_status(order),
      avg_price: avg_price,
      original_size: Decimal.new(venue_order.order_qty),
      leaves_qty: Decimal.new(venue_order.leaves_qty),
      cumulative_qty: Decimal.new(venue_order.cum_qty),
      venue_timestamp: Timex.parse!(venue_order.timestamp, @format),
      received_at: received_at
    }

    {:ok, response}
  end

  defp parse_response({:error, :timeout, nil}, _), do: {:error, :timeout}
  defp parse_response({:error, :connect_timeout, nil}, _), do: {:error, :connect_timeout}
  defp parse_response({:error, :overloaded, _}, _), do: {:error, :overloaded}
  defp parse_response({:error, :rate_limited, _}, _), do: {:error, :rate_limited}
  defp parse_response({:error, {:nonce_not_increasing, _} = reason, _}, _), do: {:error, reason}

  defp parse_response({:error, {:insufficient_balance, _}, _}, _),
    do: {:error, :insufficient_balance}

  defp parse_response({:error, reason, _}, _), do: {:error, {:unhandled, reason}}
end
