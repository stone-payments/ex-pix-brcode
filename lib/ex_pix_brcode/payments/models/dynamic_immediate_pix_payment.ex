defmodule ExPixBRCode.Payments.Models.DynamicImmediatePixPayment do
  @moduledoc """
  A dynamic immediate Pix payment.

  This payment structure is the result of loading it from a Pix endpoint.
  """

  use ExPixBRCode.ValueObject

  alias ExPixBRCode.Changesets

  @required [:revisao, :chave, :txid, :status]
  @optional [:solicitacaoPagador]

  @calendario_required [:criacao, :apresentacao]
  @calendario_optional [:expiracao]

  @valor_required [:original]
  @valor_optional []

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
      field :expiracao, :integer, default: 86_400
    end

    embeds_one :devedor, Devedor, primary_key: false do
      field :cpf, :string
      field :cnpj, :string
      field :nome, :string
    end

    embeds_one :valor, Valor, primary_key: false do
      field :original, :decimal
    end

    embeds_many :infoAdicionais, InfoAdicionais, primary_key: false do
      field :nome, :string
      field :valor, :string
    end
  end

  @doc false
  def changeset(model \\ %__MODULE__{}, params) do
    model
    |> cast(coalesce_params(params), @required ++ @optional)
    |> validate_required(@required)
    |> cast_embed(:calendario, with: &calendario_changeset/2, required: true)
    |> cast_embed(:devedor, with: &devedor_changeset/2)
    |> cast_embed(:valor, with: &valor_changeset/2, required: true)
    |> cast_embed(:infoAdicionais, with: &info_adicionais_changeset/2)
    |> validate_number(:revisao, greater_than_or_equal_to: 0)
    |> validate_length(:txid, max: 35)
    |> validate_length(:solicitacaoPagador, max: 140)
  end

  defp coalesce_params(%{"infoAdicionais" => nil} = params),
    do: Map.put(params, "infoAdicionais", [])

  defp coalesce_params(%{infoAdicionais: nil} = params), do: Map.put(params, :infoAdicionais, [])
  defp coalesce_params(params), do: params

  defp calendario_changeset(model, params) do
    model
    |> cast(params, @calendario_required ++ @calendario_optional)
    |> validate_required(@calendario_required)
  end

  defp info_adicionais_changeset(model, params) do
    model
    |> cast(params, [:nome, :valor])
    |> validate_required([:nome, :valor])
  end

  defp valor_changeset(model, params) do
    model
    |> cast(params, @valor_required ++ @valor_optional)
    |> validate_required(@valor_required)
    |> validate_number(:original, greater_than: 0)
  end

  defp devedor_changeset(model, params) do
    model
    |> cast(params, [:nome, :cpf, :cnpj])
    |> validate_either_cpf_or_cnpj()
  end

  defp validate_either_cpf_or_cnpj(%{valid?: false} = c), do: c

  defp validate_either_cpf_or_cnpj(changeset) do
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
end
