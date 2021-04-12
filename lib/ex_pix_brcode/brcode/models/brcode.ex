defmodule ExPixBRCode.BRCodes.Models.BRCode do
  @moduledoc """
  Schema for BRCode representation.

  For a better understating of the EMV®-QRCPS fields specification, used by BRCode, is recommended
  to consult [EMV® QR Code Specification for Payment Systems (EMV® QRCPS) Merchant-Presented Mode](https://www.emvco.com/emv-technologies/qrcodes/)
  """

  use ExPixBRCode.ValueObject

  @required [
    :payload_format_indicator,
    :merchant_name,
    :merchant_city,
    :merchant_category_code,
    :transaction_currency,
    :country_code,
    :crc
  ]
  @optional [
    :point_of_initiation_method,
    :transaction_amount,
    :postal_code
  ]

  @alphanumeric_special_format ~r/^[\x20-\x7E]+$/

  embedded_schema do
    field :payload_format_indicator, :string, default: "01"
    field :point_of_initiation_method, :string

    embeds_one :merchant_account_information, MerchantAccountInfo, primary_key: false do
      field :gui, :string, default: "br.gov.bcb.pix"

      # Static fields
      field :chave, :string
      field :info_adicional, :string

      # Dynamic fields
      field :url, :string
    end

    field :merchant_category_code, :string, default: "0000"

    field :transaction_currency, :string, default: "986"
    field :transaction_amount, :string
    field :country_code, :string, default: "BR"
    field :merchant_name, :string
    field :merchant_city, :string
    field :postal_code, :string

    embeds_one :additional_data_field_template, AdditionalDataField, primary_key: false do
      field :reference_label, :string
    end

    # Fields that are NOT "castable"
    field :crc, :string

    field :type, Ecto.Enum,
      values: [
        :static,
        :dynamic_payment_immediate,
        :dynamic_payment_with_due_date
      ]
  end

  @doc false
  def changeset(model \\ %__MODULE__{}, params) do
    model
    |> cast(params, @required ++ @optional)
    |> cast_embed(:merchant_account_information,
      with: &validate_merchant_acc_info/2,
      required: true
    )
    |> cast_embed(:additional_data_field_template,
      with: &validate_additional_data_field_template/2,
      required: true
    )
    |> validate_required(@required)
    |> validate_inclusion(:payload_format_indicator, ~w(01))
    |> validate_inclusion(:point_of_initiation_method, ~w(11 12))
    |> validate_format(:merchant_category_code, ~r/^[0-9]{4}$/)
    |> validate_inclusion(:transaction_currency, ~w(986))
    |> validate_length(:transaction_amount, max: 13)
    # Formats accept: "0.10", ".10", "1.", "1", "123.9","123.99", "123456789.23"
    |> validate_format(
      :transaction_amount,
      ~r/^[0-9]+\.[0-9]{2}$|^[0-9]+\.[0-9]{1}$|^[1-9]{1}[0-9]*\.?$|^\.[0-9]{2}$/
    )
    |> validate_inclusion(:country_code, ~w(BR))
    |> validate_length(:postal_code, is: 8)
    |> validate_length(:merchant_name, max: 25)
    |> validate_format(:merchant_name, @alphanumeric_special_format)
    |> validate_length(:merchant_city, max: 15)
    |> validate_format(:merchant_city, @alphanumeric_special_format)
    |> put_type()
  end

  defp put_type(%{valid?: false} = c), do: c

  defp put_type(changeset) do
    mai = get_field(changeset, :merchant_account_information)

    cond do
      not is_nil(mai.chave) ->
        put_change(changeset, :type, :static)

      not is_nil(mai.url) and Regex.match?(~r/cobv/, String.downcase(mai.url)) ->
        put_change(changeset, :type, :dynamic_payment_with_due_date)

      not is_nil(mai.url) ->
        put_change(changeset, :type, :dynamic_payment_immediate)
    end
  end

  defp validate_merchant_acc_info(model, params) do
    model
    |> cast(params, [:gui, :chave, :url, :info_adicional])
    |> validate_required([:gui])
    |> validate_inclusion(:gui, ["br.gov.bcb.pix", "BR.GOV.BCB.PIX"])
    |> validate_length(:chave, min: 1, max: 77)
    |> validate_length(:info_adicional, min: 1, max: 72)
    |> validate_length(:url, min: 1, max: 77)
    |> validate_per_type()
  end

  defp validate_additional_data_field_template(model, params) do
    model
    |> cast(params, [:reference_label])
    |> validate_required([:reference_label])
    |> validate_format(:reference_label, ~r(^[a-zA-Z0-9]{1,25}$|^\*\*\*$))
  end

  defp validate_per_type(%{valid?: false} = c), do: c

  defp validate_per_type(changeset) do
    chave = get_field(changeset, :chave)
    info_adicional = get_field(changeset, :info_adicional)
    url = get_field(changeset, :url)

    cond do
      is_nil(chave) and is_nil(url) ->
        add_error(changeset, :chave_or_url, ":chave or :url must be present")

      not is_nil(chave) and not is_nil(url) ->
        add_error(changeset, :chave_or_url, ":chave and :url are present")

      not is_nil(chave) ->
        validate_chave_and_info_adicional_length(changeset, chave, info_adicional)

      not is_nil(info_adicional) ->
        add_error(changeset, :url_and_info_adicional, ":url and :info_adicional are present")

      true ->
        validate_url(changeset, url)
    end
  end

  defp validate_chave_and_info_adicional_length(changeset, chave, info_adicional) do
    [chave, info_adicional]
    |> Enum.join()
    |> String.length()
    |> case do
      length when length > 99 ->
        add_error(
          changeset,
          :chave_and_info_adicional_length,
          "The full size of merchant_account_information cannot exceed 99 characters"
        )

      _ ->
        changeset
    end
  end

  defp validate_url(changeset, url) do
    with {:validate_has_web_protocol, false} <-
           {:validate_has_web_protocol, Regex.match?(~r{^https?://\w+}, url)},
         %{path: path} when is_binary(path) <- URI.parse("https://" <> url) do
      validate_pix_path(changeset, Path.split(path))
    else
      {:validate_has_web_protocol, true} -> add_error(changeset, :url, "URL with protocol")
      _ -> add_error(changeset, :url, "malformed URL")
    end
  end

  defp validate_pix_path(changeset, ["/" | path]) when length(path) > 1, do: changeset
  defp validate_pix_path(changeset, _), do: add_error(changeset, :url, "Invalid Pix path")
end
