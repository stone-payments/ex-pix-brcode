defmodule Mix.Tasks.Pix.ReadBrcode do
  @moduledoc """
  Reads a BRCode decoding and validating it.

  It accepts the raw BRCode. Beware of valid spaces in its values! When using the command line,
  wrap it with single quotes. Example:

      mix pix.read_br_code '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D'

  Command line options:

    `--citycode` - payer city code who will pay dynamic pix payment with due date
    `--paymentdate` - payment date of dynamic pix payment with due date
  """
  @shortdoc "Reads a BRCode decoding and validating it."
  @acceptable_args [citycode: :string, paymentdate: :string]

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

  def run([brcode | args]) do
    Mix.Tasks.App.Start.run([])

    with {:parsed_args, {args, [], []}} <- {:parsed_args, OptionParser.parse(args, strict: @acceptable_args)},
         {:ok, opts} <- build_from_code_opts(args),
         {:ok, brcode} <- BRCodes.decode_to(brcode),
         {:ok, payment} <- Payments.from_brcode(@client, brcode, opts) do
      Mix.shell().info("""
      Got a valid BRCode of type: #{brcode.type}
      Decoded BRCode:

      #{inspect(brcode, pretty: true)}

      Loaded payment:

      #{inspect(payment, pretty: true)}
      """)
    else
      {:parsed_args, {_args, [], unknown_args}} ->
        for {unknown_arg, _} <- unknown_args do
          Mix.shell().error("#{unknown_arg}: Not allowed argument")
        end

      err ->
        Mix.shell().error("Got error! #{inspect(err)}")
    end
  end

  defp build_from_code_opts([]), do: []

  defp build_from_code_opts(args) do
    {:ok, [codemun: Keyword.get(args, :citycode), ddp: Keyword.get(args, :paymentdate)]}
  end
end
