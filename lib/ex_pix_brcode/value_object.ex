defmodule ExPixBRCode.ValueObject do
  @moduledoc """
  Value object is a data structure that has no identity.

  We use value objects as a means of defining a data structure with its validations.

  Also, it has helpers for turning structs into maps (the opposite of 
  `ExPixBRCode.Changests.cast_and_apply`).
  """

  @iso8601_structs [
    Date,
    DateTime,
    NaiveDateTime,
    Time
  ]

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @typedoc """
      Represent the schema type
      """
      @type t :: %__MODULE__{}

      @primary_key false
    end
  end

  @doc "Transforms a struct and its inner fields to atom-maps"
  def to_map(instance, opts \\ []) do
    key_type = Keyword.get(opts, :key_type, :atom_keys)
    serialize_timestamps = Keyword.get(opts, :serialize_timestamps, false)

    instance
    |> Map.drop([:__struct__, :__meta__])
    |> Map.new(fn
      {key, value} ->
        {cast_key(key, key_type), do_cast_to_map(value, key_type, serialize_timestamps)}
    end)
  end

  defp do_cast_to_map(%schema{} = struct, key_type, serialize_timestamps) do
    cond do
      schema in @iso8601_structs and serialize_timestamps ->
        date_format(struct)

      schema in @iso8601_structs ->
        struct

      true ->
        struct
        |> Map.from_struct()
        |> do_cast_to_map(key_type, serialize_timestamps)
    end
  end

  defp do_cast_to_map(map, key_type, serialize_timestamps) when is_map(map) do
    map
    |> Map.drop([:__meta__])
    |> Map.to_list()
    |> Enum.map(fn
      {k, v} -> {cast_key(k, key_type), do_cast_to_map(v, key_type, serialize_timestamps)}
    end)
    |> Enum.into(%{})
  end

  defp do_cast_to_map(list, key_type, serialize_timestamps) when is_list(list) do
    Enum.map(list, fn
      {k, v} -> {cast_key(k, key_type), do_cast_to_map(v, key_type, serialize_timestamps)}
      v -> do_cast_to_map(v, key_type, serialize_timestamps)
    end)
  end

  defp do_cast_to_map(value, _key_type, _serialize_timestamps), do: value

  defp cast_key(key, :atom_keys), do: to_atom(key)
  defp cast_key(key, :string_keys), do: to_string(key)

  defp to_atom(v) when is_atom(v), do: v
  defp to_atom(v), do: String.to_atom(v)

  defp date_format(nil), do: nil

  defp date_format(%Date{} = date), do: Date.to_iso8601(date)

  defp date_format(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp date_format(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end
end
