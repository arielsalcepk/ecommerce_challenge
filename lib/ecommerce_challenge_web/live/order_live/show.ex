defmodule EcommerceChallengeWeb.OrderLive.Show do
  use EcommerceChallengeWeb, :live_view

  alias EcommerceChallenge.Sales

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Order confirmed
        <:subtitle>Order #{@order.id} - {@order.status}</:subtitle>
        <:actions>
          <.button variant="primary" navigate={~p"/products"}>Continue shopping</.button>
        </:actions>
      </.header>

      <.table id="order-items" rows={@order.order_items}>
        <:col :let={item} label="Product">{item.product.name}</:col>
        <:col :let={item} label="Quantity">{item.quantity}</:col>
        <:col :let={item} label="Unit price">{item.unit_price}</:col>
        <:col :let={item} label="Subtotal">{item.subtotal}</:col>
      </.table>

      <.list>
        <:item title="Total">{@order.total_amount}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Order confirmed")
     |> assign(:order, Sales.get_order!(id))}
  end
end
