defmodule ExPixBRCode.Payments.Models.DynamicPixPaymentWithDueDate do
  @moduledoc """
  A dynamic Pix payment with due date.

  This has extra complexity when dealing with interests and due dates.
  """

  use ExPixBRCode.ValueObject

  embedded_schema do
    field :revisao, :integer
  end

  @doc false
  def changeset(model \\ %__MODULE__{}, params) do
    model
    |> cast(params, [])
  end
end
