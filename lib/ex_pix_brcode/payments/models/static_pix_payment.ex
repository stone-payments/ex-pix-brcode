defmodule ExPixBRCode.Payments.Models.StaticPixPayment do
  @moduledoc """
  A static Pix payment model.

  Static payments are those meant to be used many times. Normally a merchant will print a QRCode to
  a sign and direct his/her customers to scan it. It MUST contain AT LEAST the DICT key for the
  target account.
  """

  use ExPixBRCode.ValueObject

  @required [:key]
  @optional [:transaction_amount, :transaction_id, :additional_information, :key_type]
  @transaction_amount_format ~r/^[0-9]+\.[0-9]{2}$|^[0-9]+\.[0-9]{1}$|^[1-9]{1}[0-9]*\.?$|^\.[0-9]{2}$/

  embedded_schema do
    field :key, :string
    field :key_type, :string
    field :additional_information, :string
    field :transaction_amount, :string
    field :transaction_id, :string
  end

  @doc false
  def changeset(model \\ %__MODULE__{}, params) do
    model
    |> cast(params, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:transaction_amount, @transaction_amount_format)
    |> validate_format(:transaction_id, ~r(^[a-zA-Z0-9]{1,25}$|^\*\*\*$))
    |> validate_random_key_format()
  end

  defp validate_random_key_format(changeset) do
    key_type = get_change(changeset, :key_type)
    key = get_change(changeset, :key)

    cond do
      key_type == "random_key" and key == String.downcase(key) -> changeset
      key_type == "random_key" -> add_error(changeset, :key, "has invalid format")
      true -> changeset
    end
  end
end
