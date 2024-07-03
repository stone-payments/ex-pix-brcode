defmodule ExPixBRCode.Payments.Models.DynamicPixPaymentWithDueDate do
  @moduledoc """
  A dynamic Pix payment with due date.

  This has extra complexity when dealing with interests and due dates.
  """

  use ExPixBRCode.ValueObject
  alias ExPixBRCode.Changesets

  @required [:revisao, :chave, :txid, :status]
  @optional [:solicitacaoPagador]

  @calendario_required [:criacao, :apresentacao, :dataDeVencimento]
  @calendario_optional [:validadeAposVencimento]
  @max_value_validade_apos_vencimento 2_147_483_647

  @devedor_required [:cpf, :cnpj, :nome]

  @recebedor_required [:nome, :logradouro, :cidade, :uf, :cep]
  @recebedor_optional [:nomeFantasia]
  @recebedor_one_of [:cpf, :cnpj]

  @valor_required [:final]
  @valor_optional [:original, :abatimento, :desconto, :juros, :multa]

  embedded_schema do
    field :revisao, :integer
    field :chave, :string
    field :txid, :string

    field :status, Ecto.Enum,
      values: ~w(ATIVA CONCLUIDA REMOVIDA_PELO_USUARIO_RECEBEDOR REMOVIDA_PELO_PSP)a

    field :solicitacaoPagador, :string

    embeds_one :calendario, Calendario, primary_key: false do
      field :criacao, :utc_datetime
      field :apresentacao, :utc_datetime
      field :dataDeVencimento, :date
      field :validadeAposVencimento, :integer, default: 30
    end

    embeds_one :devedor, Devedor, primary_key: false do
      field :cpf, :string
      field :cnpj, :string
      field :nome, :string
    end

    embeds_one :valor, Valor, primary_key: false do
      field :original, :decimal
      field :abatimento, :decimal
      field :desconto, :decimal
      field :juros, :decimal
      field :multa, :decimal
      field :final, :decimal
    end

    embeds_one :recebedor, Recebedor, primary_key: false do
      field :cpf, :string
      field :cnpj, :string
      field :nome, :string
      field :nomeFantasia, :string
      field :logradouro, :string
      field :cidade, :string
      field :uf, :string
      field :cep, :string
    end

    embeds_many :infoAdicionais, InfoAdicionais, primary_key: false do
      field :nome, :string
      field :valor, :string
    end
  end

  @spec changeset(
          {map, map}
          | %{
              :__struct__ => atom | %{:__changeset__ => map, optional(any) => any},
              optional(atom) => any
            },
          any
        ) :: Ecto.Changeset.t()
  @doc false
  def changeset(model \\ %__MODULE__{}, params) do
    model
    |> cast(coalesce_params(params), @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:txid, max: 35)
    |> validate_length(:solicitacaoPagador, max: 140)
    |> validate_number(:revisao, greater_than_or_equal_to: 0)
    |> cast_embed(:calendario, required: true, with: &calendario_changeset/2)
    |> cast_embed(:devedor, required: true, with: &devedor_changeset/2)
    |> cast_embed(:valor, require: true, with: &valor_changeset/2)
    |> cast_embed(:recebedor, required: true, with: &recebedor_changeset/2)
    |> cast_embed(:infoAdicionais, with: &info_adicionais_changeset/2)
    |> validate_length(:infoAdicionais, less_than_or_equal_to: 77)
  end

  defp coalesce_params(%{"infoAdicionais" => nil} = params),
    do: Map.put(params, "infoAdicionais", [])

  defp coalesce_params(%{infoAdicionais: nil} = params), do: Map.put(params, :infoAdicionais, [])

  defp coalesce_params(params), do: params

  defp calendario_changeset(model, params) do
    model
    |> cast(params, @calendario_required ++ @calendario_optional)
    |> validate_required(@calendario_required)
    # The validadeAposVencimeneto field accepts only Int32 possitive value type
    |> validate_number(:validadeAposVencimento,
      less_than_or_equal_to: @max_value_validade_apos_vencimento,
      greater_than_or_equal_to: 0
    )
  end

  defp devedor_changeset(model, params) do
    model
    |> cast(params, @devedor_required)
    |> devedor_validate_required()
  end

  defp devedor_validate_required(changeset) do
    cpf = get_field(changeset, :cpf)
    cnpj = get_field(changeset, :cnpj)
    name = get_field(changeset, :nome)

    cond do
      not is_nil(cpf) and not is_nil(cnpj) ->
        add_error(changeset, :devedor, "only one of cpf or cnpj must be present")

      (not is_nil(cpf) or not is_nil(cnpj)) and is_nil(name) ->
        add_error(changeset, :devedor, "when either cpf or cnpj is present so must be 'nome'")

      not is_nil(cpf) ->
        Changesets.validate_document(changeset, :cpf)

      true ->
        Changesets.validate_document(changeset, :cnpj)
    end
  end

  defp recebedor_changeset(model, params) do
    model
    |> cast(params, @recebedor_optional ++ @recebedor_one_of ++ @recebedor_required)
    |> validate_required(@recebedor_required)
    |> validate_either_cpf_or_cnpj()
  end

  defp validate_either_cpf_or_cnpj(changeset) do
    cpf = get_field(changeset, :cpf)
    cnpj = get_field(changeset, :cnpj)

    cond do
      is_nil(cpf) and is_nil(cnpj) ->
        add_error(changeset, :recebedor, "one of cpf or cnpj must be present")

      not is_nil(cpf) and not is_nil(cnpj) ->
        add_error(changeset, :recebedor, "only one of cpf or cnpj must be present")

      not is_nil(cpf) ->
        Changesets.validate_document(changeset, :cpf)

      true ->
        Changesets.validate_document(changeset, :cnpj)
    end
  end

  defp info_adicionais_changeset(model, params) do
    model
    |> cast(params, [:nome, :valor])
    |> put_change_for_empty_string(params, [:nome, :valor])
    |> custom_validate_required([:nome, :valor])
    |> validate_length(:nome, less_than_or_equal_to: 50)
    |> validate_length(:valor, less_than_or_equal_to: 200)
  end

  defp put_change_for_empty_string(changeset, params, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      string_field = Atom.to_string(field)
      field_value = get_field(acc, field)
      params_value = params[string_field]

      if is_nil(field_value) and
           is_binary(params_value) and
           String.trim(params_value) == "" do
        put_change(acc, field, "")
      else
        acc
      end
    end)
  end

  defp custom_validate_required(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      if get_field(acc, field) == "" do
        acc
      else
        validate_required(acc, [field])
      end
    end)
  end

  defp valor_changeset(model, params) do
    model
    |> cast(params, @valor_required ++ @valor_optional)
    |> validate_required(@valor_required)
    |> validate_number(:abatimento, greater_than_or_equal_to: 0)
    |> validate_number(:desconto, greater_than_or_equal_to: 0)
    |> validate_number(:juros, greater_than_or_equal_to: 0)
    |> validate_number(:multa, greater_than_or_equal_to: 0)
  end
end
