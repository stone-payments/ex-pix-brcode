defmodule ExPixBRCode.JWS.Models.JWKS do
  @moduledoc """
  A JWKS result following RFC https://tools.ietf.org/html/rfc7517
  """

  use ExPixBRCode.ValueObject

  @key_required [:kty, :kid, :x5t, :x5c, :key_ops]
  @key_optional [:use, :alg, :"x5t#S256", :x5u, :n, :e, :crv, :x, :y]

  @supported_algs JOSE.JWA.supports()
                  |> Keyword.get(:jws)
                  |> elem(1)
                  |> Enum.reject(&(String.starts_with?(&1, "HS") or &1 == "none"))

  embedded_schema do
    embeds_many :keys, Key do
      field :kty, :string
      field :use, :string
      field :key_ops, {:array, :string}
      field :alg, :string
      field :kid, :string
      field :x5u, :string
      field :x5t, :string
      field :"x5t#S256", :string
      field :x5c, {:array, :string}

      # RSA fields
      field :n, :string
      field :e, :string

      # EC fields
      field :crv, :string
      field :x, :string
      field :y, :string
    end
  end

  @doc false
  def changeset(model \\ %__MODULE__{}, params) do
    model
    |> cast(params, [])
    |> cast_embed(:keys, with: &key_changeset/2, required: true)
  end

  defp key_changeset(model, params) do
    model
    |> cast(params, @key_required ++ @key_optional)
    |> validate_required(@key_required)
    |> validate_inclusion(:alg, @supported_algs)
    |> validate_inclusion(:kty, ["EC", "RSA"])
    |> validate_subset(:key_ops, ["verify"])
    |> validate_length(:x5c, min: 1)
    |> validate_per_kty()
  end

  defp validate_per_kty(%{valid?: false} = c), do: c

  defp validate_per_kty(changeset) do
    case get_field(changeset, :kty) do
      "EC" ->
        crv = get_field(changeset, :crv)
        x = get_field(changeset, :x)
        y = get_field(changeset, :y)
        validate_curve_key(changeset, crv, x, y)

      "RSA" ->
        n = get_field(changeset, :n)
        e = get_field(changeset, :e)
        validate_rsa_key(changeset, n, e)
    end
  end

  defp validate_curve_key(changeset, crv, x, y)
       when is_nil(crv) or is_nil(x) or is_nil(y),
       do: add_error(changeset, :kty, "Missing EC params `crv`, `x` or `y`")

  defp validate_curve_key(changeset, _, _, _), do: changeset

  defp validate_rsa_key(changeset, n, e)
       when is_nil(n) or is_nil(e),
       do: add_error(changeset, :kty, "Missing RSA params `e` or `n`")

  defp validate_rsa_key(changeset, _, _), do: changeset
end
