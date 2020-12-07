defmodule Mix.Tasks.Pix.ReadBrcode do
  @moduledoc """
  Reads a BRCode decoding and validating it. 

  It accepts the raw BRCode. Beware of valid spaces in its values! When using the command line, 
  wrap it with single quotes. Example:

      mix pix.read_br_code '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D'
  """
  @shortdoc "Reads a BRCode decoding and validating it."

  use Mix.Task

  alias ExPixBRCode.{BRCodes, Payments}

  @client Tesla.client(
            [],
            {Tesla.Adapter.Hackney, ssl_options: [versions: [:"tlsv1.2", :"tlsv1.3"]]}
          )

  @impl Mix.Task
  def run([]) do
    Mix.shell().info("Missing argument of a BRCode")
  end

  def run([brcode | _]) do
    Mix.Tasks.App.Start.run([])

    with {:ok, brcode} <- BRCodes.decode_to(brcode),
         {:ok, payment} <- Payments.from_brcode(@client, brcode) do
      Mix.shell().info("""
      Got a valid BRCode of type: #{brcode.type}
      Decoded BRCode: 

      #{inspect(brcode, pretty: true)}

      Loaded payment:

      #{inspect(payment, pretty: true)}
      """)
    else
      err -> Mix.shell().error("Got error! #{inspect(err)}")
    end
  end
end
