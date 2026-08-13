defmodule EcommerceChallengeWeb.ProductLive.Show do
  use EcommerceChallengeWeb, :live_view

  alias EcommerceChallenge.Catalog
  alias EcommerceChallenge.Sales

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Product {@product.id}
        <:subtitle>This is a product record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/products"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/products/#{@product}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit product
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@product.name}</:item>
        <:item title="Sku">{@product.sku}</:item>
        <:item title="Description">{@product.description}</:item>
        <:item title="Category">{@product.category}</:item>
        <:item title="Price">{@product.price}</:item>
        <:item title="Stock">{@product.stock}</:item>
        <:item title="Weight kg">{@product.weight_kg}</:item>
      </.list>

      <div class="card bg-base-200 mt-6 p-4 max-w-sm">
        <h2 class="font-semibold mb-2">Purchase</h2>
        <p :if={@product.stock == 0} class="text-error">Out of stock.</p>
        <.form
          :if={@product.stock > 0}
          for={%{}}
          id="buy-form"
          phx-submit="buy"
          class="flex gap-3 items-end"
        >
          <div>
            <label for="quantity" class="text-sm">Quantity</label>
            <input
              type="number"
              id="quantity"
              name="quantity"
              value="1"
              min="1"
              max={@product.stock}
              class="input input-bordered w-24"
            />
          </div>
          <.button phx-disable-with="Processing…" variant="primary">Buy Now</.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Product")
     |> assign(:product, Catalog.get_product!(id))}
  end

  @impl true
  def handle_event("buy", %{"quantity" => quantity}, socket) do
    case Integer.parse(quantity) do
      {quantity, _rest} when quantity > 0 -> buy(socket, quantity)
      _ -> {:noreply, put_flash(socket, :error, "Enter a valid quantity.")}
    end
  end

  defp buy(socket, quantity) do
    case Sales.purchase(socket.assigns.product.id, quantity) do
      {:ok, order} ->
        {:noreply, push_navigate(socket, to: ~p"/orders/#{order}")}

      {:error, :insufficient_stock} ->
        {:noreply, put_flash(socket, :error, "Not enough stock available for that quantity.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to complete purchase. Please try again.")}
    end
  end
end
