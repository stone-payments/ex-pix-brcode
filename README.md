# ExPixBRCode - pt-BR

Biblioteca Elixir para validação e leitura de BRCodes destinados ao sistema Pix.

Para a leitura de um BRCode basta:

``` elixir
{:ok,
   %{
     "additional_data_field_template" => %{"reference_label" => "***"},
     "country_code" => "BR",
     "crc" => "1D3D",
     "merchant_account_information" => %{
       "gui" => "br.gov.bcb.pix",
       "chave" => "123e4567-e12b-12d1-a456-426655440000"
     },
     "merchant_category_code" => "0000",
     "merchant_city" => "BRASILIA",
     "merchant_name" => "Fulano de Tal",
     "payload_format_indicator" => "01",
     "transaction_currency" => "986"
   }} = ExPixBRCode.BRCodes.decode(brcode)
```

Ou fazendo o cast para um `Ecto.Schema`:

``` elixir
alias ExPixBRCode.BRCodes.Models.BRCode
alias ExPixBRCode.BRCodes.Models.BRCode.{AdditionalDataField, MerchantAccountInfo}

{:ok,
 %BRCode{
   additional_data_field_template: %AdditionalDataField{
     reference_label: "***"
   },
   country_code: "BR",
   crc: "1D3D",
   merchant_account_information: %MerchantAccountInfo{
     chave: "123e4567-e12b-12d1-a456-426655440000",
     gui: "br.gov.bcb.pix",
     info_adicional: nil,
     url: nil
   },
   merchant_category_code: "0000",
   merchant_city: "BRASILIA",
   merchant_name: "Fulano de Tal",
   payload_format_indicator: "01",
   point_of_initiation_method: nil,
   transaction_amount: nil,
   transaction_currency: "986",
   type: :static
 }} = ExPixBRCode.BRCodes.decode_to(brcode)
```

Após o decode, caso o type seja de algum Pix dinâmico, é necessário carregar os dados do JWS. Para isso, basta:

``` elixir
alias ExPixBRCode.Payments.Models.PixPayment
alias ExPixBRCode.Payments.Models.PixPayment.{Calendario, Valor}

ExPixBRCode.Payments.DynamicPixLoader.load_pix(client, url) |> IO.inspect()
{:ok,
 %PixPayment{
   calendario: %Calendario{
     apresentacao: ~U[2020-11-28 03:15:39Z],
     criacao: ~U[2020-11-13 23:59:49Z],
     expiracao: 86400
   },
   chave: "14413050762",
   devedor: nil,
   infoAdicionais: [],
   revisao: 0,
   solicitacaoPagador: nil,
   status: :ATIVA,
   txid: "4DE46328260C11EB91C04049FC2CA371",
   valor: %Valor{original: #Decimal<1.00>}
 }}
```

Nesse caso há dois parâmetros: uma instância de `Tesla.Client` e a URL do Pix que deve retornar um JWS válido.

!!! IMPORTANTE !!! Esta biblioteca NÃO faz a validação TLS exigida pelo BACEN. Isso porque é necessário ter acesso ao sistema SPI (Sistema de Pagamentos Instantâneos) para poder baixar um arquivo com os certificados dos participantes. Iremos colocar um exemplo de configuração apenas ilustrativo, porém fica a cargo de quem estiver usando a biblioteca providenciar um `Tesla.Client` que:

- Garanta que só se conectará em servidores TLS 1.2+
- Garanta que a validação de certificados e domínios seja de acordo com o arquivo providenciado pelo BACEN através do sistema SPI

Basicamente isso pode ser feito através da opção `verify_fun` da aplicação de `:ssl` do Erlang, mas não está feito nesta biblioteca.

# ExPixBRCode - en-US

Elixir library for validating and reading BRCodes used in Pix payments.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_pix_brcode` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_pix_brcode, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ex_pix_brcode](https://hexdocs.pm/ex_pix_brcode).
