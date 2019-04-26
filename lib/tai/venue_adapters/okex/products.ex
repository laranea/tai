defmodule Tai.VenueAdapters.OkEx.Products do
  alias Tai.Utils

  def products(venue_id) do
    with {:ok, future_instruments} <- ExOkex.Futures.Public.instruments(),
         {:ok, swap_instruments} <- ExOkex.Swap.Public.instruments() do
      future_products = future_instruments |> Enum.map(&build_future(&1, venue_id))
      swap_products = swap_instruments |> Enum.map(&build_swap(&1, venue_id))
      products = future_products ++ swap_products
      {:ok, products}
    end
  end

  defp build_future(
         %{
           "instrument_id" => instrument_id,
           "tick_size" => tick_size,
           "trade_increment" => trade_increment
         },
         venue_id
       ) do
    symbol = instrument_id |> to_symbol()
    size_increment = trade_increment |> Utils.Decimal.from()
    price_increment = tick_size |> Utils.Decimal.from()

    %Tai.Venues.Product{
      venue_id: venue_id,
      symbol: symbol,
      venue_symbol: instrument_id,
      status: :trading,
      type: :future,
      price_increment: price_increment,
      size_increment: size_increment,
      min_price: price_increment,
      min_size: size_increment
    }
  end

  defp build_swap(
         %{
           "instrument_id" => instrument_id,
           "tick_size" => tick_size,
           "size_increment" => raw_size_increment
         },
         venue_id
       ) do
    symbol = instrument_id |> to_symbol()
    size_increment = raw_size_increment |> Utils.Decimal.from()
    price_increment = tick_size |> Utils.Decimal.from()

    %Tai.Venues.Product{
      venue_id: venue_id,
      symbol: symbol,
      venue_symbol: instrument_id,
      status: :trading,
      type: :swap,
      price_increment: price_increment,
      size_increment: size_increment,
      min_price: price_increment,
      min_size: size_increment
    }
  end

  def to_symbol(instrument_id),
    do: instrument_id |> String.replace("-", "_") |> String.downcase() |> String.to_atom()

  def from_symbol(symbol),
    do: symbol |> Atom.to_string() |> String.replace("_", "-") |> String.upcase()
end
