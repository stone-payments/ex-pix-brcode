defmodule ExPixBRCode.Changesets do
  @moduledoc """
  Helper module for custom validations and casting external input.
  """

  import Ecto.Changeset
  alias Ecto.Changeset

  require Logger

  @doc """
  Receives a schema module then casts and validates params using its changeset function.
  """
  @spec cast_and_apply(schema_module :: module(), params :: map(), type :: atom()) ::
          {:ok, struct()} | {:error, {type :: atom, Changeset.t()}}
  def cast_and_apply(schema_module, params, type \\ :validation) do
    params
    |> schema_module.changeset()
    |> case do
      %{valid?: true} = changeset -> {:ok, apply_changes(changeset)}
      changeset -> {:error, {type, changeset}}
    end
  end

  @spec validate_document(Changeset.t(), atom) :: Changeset.t()
  def validate_document(changeset, field) do
    validate_change(changeset, field, fn field, value ->
      if valid_document?(value, field) do
        []
      else
        [{field, "is invalid"}]
      end
    end)
  end

  @spec valid_document?(String.t(), atom()) :: boolean
  def valid_document?(document, field \\ :document)

  def valid_document?(document, field) when is_binary(document) and is_atom(field) do
    field_str = Atom.to_string(field)

    cond do
      String.contains?(field_str, "cpf") ->
        String.length(document) == 11 and Brcpfcnpj.cpf_valid?(%Cpf{number: document})

      String.contains?(field_str, "cnpj") ->
        String.length(document) == 14 and Brcpfcnpj.cnpj_valid?(%Cnpj{number: document})

      String.length(document) == 11 ->
        Brcpfcnpj.cpf_valid?(%Cpf{number: document})

      String.length(document) == 14 ->
        Brcpfcnpj.cnpj_valid?(%Cnpj{number: document})

      true ->
        false
    end
  end

  def valid_document?(_document, _field), do: false

  @doc """
  'chave' and 'infoAdicional' validation.

  These fields have the following rules:
    -
  """
  def validate_chave_and_info_adicional_length(%{valid?: false} = c, _, _, _), do: c

  def validate_chave_and_info_adicional_length(changeset, chave, info_adicional, message) do
    [chave, info_adicional]
    |> Enum.join()
    |> String.length()
    |> case do
      length when length > 99 ->
        add_error(changeset, :chave_and_info_adicional_length, message)

      _ ->
        changeset
    end
  end
end
