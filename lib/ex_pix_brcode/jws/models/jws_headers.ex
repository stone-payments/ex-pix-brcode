defmodule ExPixBRCode.JWS.Models.JWSHeaders do
  @moduledoc """
  Mandatory JWS headers we MUST validate according to the spec.
  """

  use ExPixBRCode.ValueObject

  @required [:jku, :kid, :x5t, :alg]

  embedded_schema do
    field :jku, :string
    field :kid, :string
    field :x5t, :string
    field :alg, :string
  end

  @doc false
  def changeset(model \\ %__MODULE__{}, params) do
    model
    |> cast(params, @required)
    |> validate_required(@required)
    |> validate_exclusion(:alg, ~w(none HS256 HS384 HS512))
    |> validate_length(:alg, is: 5)
    |> ensure_jku_https()
    |> validate_change(:jku, &validate_jku/2)
  end

  defp ensure_jku_https(%{valid?: false} = c), do: c

  defp ensure_jku_https(changeset) do
    case get_field(changeset, :jku) do
      "https://" <> _ ->
        changeset

      jku ->
        put_change(changeset, :jku, "https://" <> jku)
    end
  end

  defp validate_jku(_, jku) do
    case URI.parse(jku) do
      %{scheme: "https"} -> []
      %{} -> ["Invalid jku URL scheme (not https)"]
    end
  end
end
