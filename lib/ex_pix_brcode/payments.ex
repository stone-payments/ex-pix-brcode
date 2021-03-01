defmodule ExPixBRCode.Payments do
  @moduledoc """
  Payment utilities.
  """

  alias ExPixBRCode.BRCodes.Models.BRCode

  alias ExPixBRCode.Payments.DynamicPixLoader

  alias ExPixBRCode.Payments.Models.{
    DynamicImmediatePixPayment,
    DynamicPixPaymentWithDueDate,
    StaticPixPayment
  }

  @valid_query_params [:DDP, :codMun]

  @doc """
  Turn a `t:ExPixBRCode.Models.BRCode` into a payment representation according
  to its type.

  It might use the `t:Tesla.Client` for dynamically loading it from PSPs.

  For `t:ExPixBRCode.Models.BRCode` with `:dynamic_payment_with_due_date` type
  the city code and the payment date must be passed through the opts argument.
  In this situation, the city code must be the value of :cod_mun key and the
  payment date must be the value of :dpp key.
  """
  @spec from_brcode(Tesla.Client.t(), BRCode.t(), Keyword.t()) ::
          {:ok,
           StaticPixPayment.t()
           | DynamicImmediatePixPayment.t()
           | DynamicPixPaymentWithDueDate.t()}
          | {:error, reason :: atom()}
  def from_brcode(client, brcode, opts \\ [])

  def from_brcode(_client, %BRCode{type: :static} = brcode, _opts) do
    with key_type when is_binary(key_type) <- key_type(brcode.merchant_account_information.chave) do
      {:ok,
       %StaticPixPayment{
         key: brcode.merchant_account_information.chave,
         key_type: key_type,
         additional_information: brcode.merchant_account_information.info_adicional,
         transaction_amount: brcode.transaction_amount,
         transaction_id: brcode.additional_data_field_template.reference_label
       }}
    end
  end

  def from_brcode(client, %BRCode{type: :dynamic_payment_immediate} = brcode, opts) do
    DynamicPixLoader.load_pix(client, "https://" <> brcode.merchant_account_information.url, opts)
  end

  def from_brcode(client, %BRCode{type: :dynamic_payment_with_due_date} = brcode, opts) do
    opts_with_query_params = query_params_from_opts(opts)

    DynamicPixLoader.load_pix(client, "https://" <> brcode.merchant_account_information.url, opts_with_query_params)
  end

  defp key_type(key) do
    cond do
      String.match?(key, ~r/^[0-9]{11}$/) -> "cpf"
      String.match?(key, ~r/^[0-9]{14}$/) -> "cnpj"
      String.match?(key, ~r/^\+55[0-9]{11}$/) -> "phone"
      String.match?(key, ~r/@/) -> "email"
      Ecto.UUID.cast(key) != :error -> "random_key"
      true -> {:error, :unknown_key_type}
    end
  end

  defp query_params_from_opts(opts) do
    query_params = opts
    |> Enum.filter(fn {opt, value} -> opt in @valid_query_params and not is_nil(value) end)
    |> Enum.map(fn
      {:cod_mun, value} -> {:codMun, value}
      {:dpp, value} -> {:DDP, value}
    end)

    Keyword.put_new(opts, :query_params, query_params)
  end
end
