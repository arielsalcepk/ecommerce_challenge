defmodule EcommerceChallengeWeb.ProductLive.Index do
  use EcommerceChallengeWeb, :live_view

  alias EcommerceChallenge.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Products
        <:actions>
          <.button variant="primary" navigate={~p"/products/new"}>
            <.icon name="hero-plus" /> New Product
          </.button>
        </:actions>
      </.header>

      <div class="card bg-base-200 mt-6 p-4">
        <h2 class="font-semibold mb-2">Import products from CSV</h2>
        <form
          id="csv-import-form"
          phx-submit="import_csv"
          phx-change="validate_upload"
          class="flex items-center gap-3"
        >
          <.live_file_input upload={@uploads.csv} />
          <.button phx-disable-with="Importing…">Import CSV</.button>
        </form>

        <div :for={entry <- @uploads.csv.entries} class="mt-2 text-sm">
          <p>{entry.client_name} - {entry.progress}%</p>
          <p :for={err <- upload_errors(@uploads.csv, entry)} class="text-error">
            {upload_error_to_string(err)}
          </p>
        </div>

        <div :if={@import_report} id="import-report" class="mt-4">
          <div class="alert alert-success">
            {@import_report.inserted} inserted, {@import_report.updated} updated, {length(
              @import_report.skipped
            )} skipped.
          </div>
          <ul :if={@import_report.skipped != []} class="mt-2 text-sm space-y-1">
            <li :for={row <- @import_report.skipped}>
              Line {row.line} (sku: {row.sku || "n/a"}): {Enum.join(row.reasons, "; ")}
            </li>
          </ul>
        </div>
      </div>

      <.form for={%{}} id="search-form" phx-change="search" class="mt-6">
        <input
          type="text"
          name="search"
          value={@search}
          placeholder="Search by name, sku, or description"
          phx-debounce="300"
          class="input input-bordered w-full max-w-md"
        />
      </.form>

      <.table
        id="products"
        rows={@streams.products}
        row_click={fn {_id, product} -> JS.navigate(~p"/products/#{product}") end}
      >
        <:col :let={{_id, product}} label="Name">{product.name}</:col>
        <:col :let={{_id, product}} label="Sku">{product.sku}</:col>
        <:col :let={{_id, product}} label="Description">{product.description}</:col>
        <:col :let={{_id, product}} label="Category">{product.category}</:col>
        <:col :let={{_id, product}} label="Price">{product.price}</:col>
        <:col :let={{_id, product}} label="Stock">{product.stock}</:col>
        <:col :let={{_id, product}} label="Weight kg">{product.weight_kg}</:col>
        <:action :let={{_id, product}}>
          <div class="sr-only">
            <.link navigate={~p"/products/#{product}"}>Show</.link>
          </div>
          <.link navigate={~p"/products/#{product}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, product}}>
          <.link
            phx-click={JS.push("delete", value: %{id: product.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <div :if={@total_pages > 1} class="flex gap-2 items-center mt-4">
        <.link
          :if={@page > 1}
          patch={~p"/products?#{[search: @search, page: @page - 1]}"}
          class="btn btn-sm"
        >
          Previous
        </.link>
        <span class="text-sm">Page {@page} of {@total_pages}</span>
        <.link
          :if={@page < @total_pages}
          patch={~p"/products?#{[search: @search, page: @page + 1]}"}
          class="btn btn-sm"
        >
          Next
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Products")
     |> assign(:import_report, nil)
     |> allow_upload(:csv, accept: ~w(.csv), max_entries: 1, max_file_size: 5_000_000)
     |> stream(:products, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    search = params["search"] || ""
    page = Catalog.normalize_page(params["page"])
    query_params = %{"search" => search, "page" => page}

    {:noreply,
     socket
     |> assign(:search, search)
     |> assign(:page, page)
     |> assign(:total_pages, Catalog.total_pages(query_params))
     |> stream(:products, Catalog.list_products(query_params), reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    product = Catalog.get_product!(id)
    {:ok, _} = Catalog.delete_product(product)

    {:noreply, stream_delete(socket, :products, product)}
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, push_patch(socket, to: ~p"/products?#{[search: search, page: 1]}")}
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("import_csv", _params, socket) do
    case consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
           {:ok, Catalog.import_csv(path)}
         end) do
      [report] ->
        query_params = %{"search" => socket.assigns.search, "page" => socket.assigns.page}

        {:noreply,
         socket
         |> assign(:import_report, report)
         |> assign(:total_pages, Catalog.total_pages(query_params))
         |> stream(:products, Catalog.list_products(query_params), reset: true)}

      [] ->
        {:noreply, put_flash(socket, :error, "Choose a CSV file before importing.")}
    end
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 5MB)."
  defp upload_error_to_string(:not_accepted), do: "Only .csv files are accepted."
  defp upload_error_to_string(:too_many_files), do: "Only one file can be imported at a time."
end
