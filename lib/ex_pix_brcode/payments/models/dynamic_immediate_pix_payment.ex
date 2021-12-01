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
  @valor_optional [:modalidadeAlteracao]

  @saque_required [:valor, :prestadorDoServicoDeSaque, :modalidadeAgente]
  @saque_optional [:modalidadeAlteracao]

  @troco_required [:valor, :prestadorDoServicoDeSaque, :modalidadeAgente]
  @troco_optional [:modalidadeAlteracao]

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
      # Campo Obrigatório
      # Quando NAO for saque ou troco, DEVE ser maior que 0 EXCETO se modalidadeAlteracao for 1
      # Quando for saque, DEVE ser 0
      # Quando for troco, DEVE ser MAIOR que 0 referente a compra do produto.
      field :original, :decimal

      # Campo opcional
      # Valores aceitos serão 0 ou 1
      # Caso ausente, o valor será 0
      # Caso seja saque ou troco, sempre será 0 (ou pode vir sem prenchimento que no caso será igual a 0)
      field :modalidadeAlteracao, :integer, default: 0

      embeds_one :retirada, Retirada, primary_key: false do
        # valor.retirada.saque  e valor.retirada.troco não é possível que ambas sejam fornecidas em conjunto (São mutualmente excludentes)
        # Campo opcional
        embeds_one :saque, Saque, primary_key: false do
          # CAMPO OBRIGATÕRIO
          # Deve ser maior que 0 se valor.retirada.saque.modalidadeAlteracao for 0(zero)
          # Pode ser 0 caso valor.retirada.saque.modalidadeAlteracao for 1
          field :valor, :decimal

          # Campo opcional
          # Valores aceitos serão 0 ou 1
          # Caso ausente, o valor será 0
          field :modalidadeAlteracao, :integer, default: 0

          # CAMPO OBRIGATÕRIO
          # Adicionar o validação de ISPB
          field :prestadorDoServicoDeSaque, :string

          # CAMPO OBRIGATÕRIO
          # Valores que sao aceitos (AGTEC) (AGTOT) (AGPSS)
          field :modalidadeAgente, :string
        end

        # Campo opcional
        embeds_one :troco, Troco, primary_key: false do
          # CAMPO OBRIGATÕRIO
          # DEVE ser maior que 0 caso valor.retirada.troco.modalidadeAlteracao for 0 (zero)
          # Pode ser 0.00 (zero) se valor.retirada.troco.modalidadeAlteracao for 1
          field :valor, :decimal

          # Campo opcional
          # Valores aceitos serão 0 ou 1
          # Caso ausente, o valor será 0
          field :modalidadeAlteracao, :integer, default: 0

          # CAMPO OBRIGATÕRIO
          # Adicionar o validação de ISPB
          field :prestadorDoServicoDeSaque, :string

          # CAMPO OBRIGATÕRIO
          # Valor aceito (AGTEC)
          field :modalidadeAgente, :string
        end
      end
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

  defp valor_changeset(model, params) do
    model
    |> cast(params, @valor_required ++ @valor_optional)
    |> validate_required(@valor_required)
    |> validate_inclusion(:modalidadeAlteracao, [0, 1])
    |> cast_embed(:retirada, with: &retirada_changeset/2)
    |> validate_valor_original()
    |> validate_either_saque_or_troco()
  end

  defp retirada_changeset(model, params) do
    model
    |> cast(params, [])
    |> cast_embed(:saque, with: &saque_changeset/2)
    |> cast_embed(:troco, with: &troco_changeset/2)
  end

  defp saque_changeset(model, params) do
    model
    |> cast(params, @saque_required ++ @saque_optional)
    |> validate_required(@saque_required)
    |> validate_inclusion(:modalidadeAlteracao, [0, 1])
    |> validate_valor()
    |> validate_length(:prestadorDoServicoDeSaque, is: 8)
    |> validate_format(:prestadorDoServicoDeSaque, ~r/^[[:digit:]]+$/)
    |> validate_inclusion(:modalidadeAgente, ["AGTEC", "AGTOT", "AGPSS"])
  end

  defp troco_changeset(model, params) do
    model
    |> cast(params, @troco_required ++ @troco_optional)
    |> validate_required(@troco_required)
    |> validate_inclusion(:modalidadeAlteracao, [0, 1])
    |> validate_valor()
    |> validate_length(:prestadorDoServicoDeSaque, is: 8)
    |> validate_format(:prestadorDoServicoDeSaque, ~r/^[[:digit:]]+$/)
    |> validate_inclusion(:modalidadeAgente, ["AGTEC"])
  end

  defp validate_valor(changeset) do
    modalidade_alteracao = get_field(changeset, :modalidadeAlteracao)

    cond do
      modalidade_alteracao == 0 ->
        validate_number(changeset, :valor, greater_than: 0)

      modalidade_alteracao == 1 ->
        validate_number(changeset, :valor, greater_than_or_equal_to: 0)
    end
  end

  defp validate_valor_original(%{changes: %{retirada: _saque_or_troco}} = changeset) do
    modalidade_alteracao = get_field(changeset, :modalidadeAlteracao)

    retirada = get_field(changeset, :retirada)
    saque = retirada.saque
    troco = retirada.troco

    cond do
      is_nil(saque) and is_nil(troco) and modalidade_alteracao == 0 ->
        validate_number(changeset, :original, greater_than: 0)

      is_nil(saque) and is_nil(troco) and modalidade_alteracao == 1 ->
        validate_number(changeset, :original, greater_than_or_equal_to: 0)

      not is_nil(saque) and is_nil(troco) ->
        validate_number(changeset, :original, equal_to: 0)

      is_nil(saque) and not is_nil(troco) ->
        validate_number(changeset, :original, greater_than: 0)
    end
  end

  defp validate_valor_original(changeset) do
    modalidade_alteracao = get_field(changeset, :modalidadeAlteracao)

    cond do
      modalidade_alteracao == 0 ->
        validate_number(changeset, :original, greater_than: 0)

      modalidade_alteracao == 1 ->
        validate_number(changeset, :original, greater_than_or_equal_to: 0)
    end
  end

  defp validate_either_saque_or_troco(%{changes: %{retirada: _saque_or_troco}} = changeset) do
    modalidade_alteracao = get_field(changeset, :modalidadeAlteracao)
    retirada = get_field(changeset, :retirada)

    saque = retirada.saque
    troco = retirada.troco

    cond do
      not is_nil(saque) and not is_nil(troco) ->
        add_error(changeset, :retirada, "only one of saque or troco must be present")

      modalidade_alteracao == 1 ->
        add_error(changeset, :modalidadeAlteracao, "must be 0 when it is troco or saque")

      true ->
        changeset
    end
  end

  defp validate_either_saque_or_troco(changeset), do: changeset

  defp info_adicionais_changeset(model, params) do
    model
    |> cast(params, [:nome, :valor])
    |> validate_required([:nome, :valor])
  end
end
