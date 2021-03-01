defmodule ExPixBRCode.JWS.Models.JWSHeaders do
  @moduledoc """
  Mandatory JWS headers we MUST validate according to the spec.
  """

  use ExPixBRCode.ValueObject

  @required [:jku, :kid, :alg]
  @optional [:x5t, :"x5t#S256"]

  embedded_schema do
    field :jku, :string
    field :kid, :string
    field :x5t, :string
    field :"x5t#S256", :string
    field :alg, :string
  end

  @doc false
  def changeset(model \\ %__MODULE__{}, params) do
    model
    |> cast(params, @required ++ @optional)
    |> validate_required(@required)
    |> validate_at_least_one_thumbprint()
    |> validate_exclusion(:alg, ~w(none HS256 HS384 HS512))
    |> validate_length(:alg, is: 5)
    |> ensure_jku_https()
    |> validate_change(:jku, &validate_jku/2)
  end

  defp validate_at_least_one_thumbprint(%{valid?: false} = c), do: c

  defp validate_at_least_one_thumbprint(changeset) do
    x5t = get_field(changeset, :x5t)
    x5tS256 = get_field(changeset, :"x5t#S256")

    if is_nil(x5t) and is_nil(x5tS256) do
      add_error(changeset, :thumbprint, "Missing either `x5t` or `x5t#S256`")
    else
      changeset
    end
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
