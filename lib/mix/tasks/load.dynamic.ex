defmodule Mix.Tasks.Pix.LoadDynamic do
  @moduledoc """
  Loads a Pix payment from a PSP API.

  It accepts the URL as given in the BRCode.
  """
  @shortdoc "Loads a Pix payment from a PSP API."

  use Mix.Task

  alias ExPixBRCode.Payments.DynamicPixLoader

  @client Tesla.client(
            [],
            {Tesla.Adapter.Hackney, ssl_options: [versions: [:"tlsv1.2", :"tlsv1.3"]]}
          )

  @impl Mix.Task
  def run([]) do
    Mix.shell().error("Missing URL argument")
  end

  def run([url | _]) do
    Mix.Tasks.App.Start.run([])

    case DynamicPixLoader.load_pix(@client, url) do
      {:ok, payment} ->
        Mix.shell().info("""
        Loaded payment:

        #{inspect(payment, pretty: true)}
        """)

      err ->
        Mix.shell().error("Got error! #{inspect(err)}")
    end
  end
end
