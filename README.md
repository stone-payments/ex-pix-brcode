# ExPixBRCode - pt-BR

Biblioteca Elixir para validação e leitura de BRCodes destinados ao sistema Pix.

Para a leitura de um BRCode basta:

``` elixir
{:ok, brcode_map} = ExPixBRCode.Decoder.decode(brcode)
```

Ou fazendo o cast para um `Ecto.Schema`:

``` elixir
{:ok, %ExPixBRCode.Models.BRCode{} = brcode_struct} = ExPixBRCode.Decoder.decode_to(brcode)
```

Após o decode, caso o type seja de algum Pix dinâmico, é necessário carregar os dados do JWS. Para isso, basta:

``` elixir
{:ok, %ExPixBRCode.Models.PixPayment{} = payment} = ExPixBRCode.DynamicPixLoader.load_pix(client, url)
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

