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
  @valor_optional [:original]

  @abatimento_required [:modalidade, :valorPerc]

  @abatimento_modalidades [1, 2]

  @desconto_required [:modalidade]
  @desconto_optional [:valorPerc]

  @desconto_modalidades [1, 2, 3, 4, 5, 6]

  @juros_required [:modalidade, :valorPerc]

  @juros_modalidades [1, 2, 3, 4, 5, 6, 7, 8]

  @multa_required [:modalidade, :valorPerc]
  @multa_modalidades [1, 2]

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

      embeds_one :abatimento, Abatimento, primary_key: false do
        field :modalidade, :integer
        field :valorPerc, :decimal
      end

      embeds_one :desconto, Desconto, primary_key: false do
        field :modalidade, :integer

        embeds_many :descontoDataFixa, DescontoDataFixa, primary_key: false do
          field :valorPerc, :decimal
          field :data, :date
        end

        field :valorPerc, :decimal
      end

      embeds_one :juros, Juros, primary_key: false do
        field :modalidade, :integer
        field :valorPerc, :decimal
      end

      embeds_one :multa, Multa, primary_key: false do
        field :modalidade, :integer
        field :valorPerc, :decimal
      end

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
    |> validate_length(:txid, min: 26, max: 35)
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
    |> validate_required([:nome, :valor])
    |> validate_length(:nome, less_than_or_equal_to: 50)
    |> validate_length(:valor, less_than_or_equal_to: 200)
  end

  defp valor_changeset(model, params) do
    model
    |> cast(params, @valor_required ++ @valor_optional)
    |> validate_required(@valor_required)
    |> cast_embed(:abatimento, with: &abatimento_changeset/2)
    |> cast_embed(:desconto, with: &desconto_changeset/2)
    |> cast_embed(:juros, with: &juros_changeset/2)
    |> cast_embed(:multa, with: &multa_changeset/2)
  end

  defp abatimento_changeset(model, params) do
    model
    |> cast(params, @abatimento_required)
    |> validate_required(@abatimento_required)
    |> validate_inclusion(:modalidade, @abatimento_modalidades)
    |> validate_number(:valorPerc, greater_than: 0)
  end

  defp desconto_changeset(model, params) do
    model
    |> cast(params, @desconto_required ++ @desconto_optional)
    |> validate_required(@desconto_required)
    |> validate_inclusion(:modalidade, @desconto_modalidades)
    |> validate_either_desconto_data_fixa_or_valor_perc()
  end

  defp validate_either_desconto_data_fixa_or_valor_perc(changeset) do
    desconto_modalidade = get_field(changeset, :modalidade)

    fixed_value_or_proportinal_value_until_informed_date = [1, 2]

    cond do
      desconto_modalidade in fixed_value_or_proportinal_value_until_informed_date ->
        changeset
        |> cast_embed(:descontoDataFixa, with: &desconto_data_fixa_changeset/2)
        |> validate_length(:descontoDataFixa,
          greater_than_or_equal_to: 1,
          less_than_or_equal_to: 3
        )

      true ->
        validate_number(changeset, :valorPerc, greater_than: 0)
    end
  end

  def desconto_data_fixa_changeset(model, params) do
    model
    |> cast(params, [:valorPerc, :data])
    |> validate_required([:valorPerc, :data])
    |> validate_number(:valorPerc, greater_than: 0)
  end

  defp juros_changeset(model, params) do
    model
    |> cast(params, @juros_required)
    |> validate_required(@juros_required)
    |> validate_inclusion(:modalidade, @juros_modalidades)
    |> validate_number(:valorPerc, greater_than: 0)
  end

  defp multa_changeset(model, params) do
    model
    |> cast(params, @multa_required)
    |> validate_required(@multa_required)
    |> validate_inclusion(:modalidade, @multa_modalidades)
    |> validate_number(:valorPerc, greater_than: 0)
  end
end
