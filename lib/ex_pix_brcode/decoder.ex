defmodule ExPixBRCode.Decoder do
  @moduledoc """
  Decode iodata that represent a BRCode.
  """

  alias Ecto.Changeset

  alias ExPixBRCode.Models.BRCode

  @keys %{
    "00" => "payload_format_indicator",
    "01" => "point_of_initiation_method",
    "26" =>
      {"merchant_account_information",
       %{
         "00" => "gui",
         "01" => "chave",
         "25" => "url"
       }},
    "52" => "merchant_category_code",
    "53" => "transaction_currency",
    "54" => "transaction_amount",
    "58" => "country_code",
    "59" => "merchant_name",
    "60" => "merchant_city",
    "61" => "postal_code",
    "62" => {"additional_data_field_template", %{"05" => "reference_label"}},
    "63" => "crc",
    "80" => {"unreserved_templates", %{"00" => "gui"}}
  }

  @doc """
  Decode input into a map with string keys with known keys for Brocade.

  There is no actual validation about the values. If you want to coerce values and validate see
  `decode_to/3` function.

  ## Errors

  Known validation errors result in a tuple with `{:validation, reason}`. Reason might be an atom
  or a string.

  ## Options

  The following options are currently supported:

    - `strict_validation` (`t:boolean()` - default `false`): whether to allow unknown values or not

  ## Example

      iex> brcode = "00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-426655440000" <>
      ...> "5204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D"
      ...> decode(brcode)
      {:ok, %{"additional_data_field_template" => "0503***",
               "country_code" => "BR",
               "crc" => "1D3D",
               "merchant_account_information" => %{
                 "gui" => "br.gov.bcb.pix",
                 "key" => "123e4567-e12b-12d1-a456-426655440000"
               },
               "merchant_category_code" => "0000",
               "merchant_city" => "BRASILIA",
               "merchant_name" => "Fulano de Tal",
               "payload_format_indicator" => "01",
               "transaction_currency" => "986"
             }}
  """
  @spec decode(input :: iodata(), Keyword.t()) ::
          {:ok, term()} | {:error, {:validation, atom() | String.t()} | :unknown_error}
  def decode(input, opts \\ []) do
    brcode = IO.iodata_to_binary(input)
    {contents, crc} = extract_crc(brcode)

    check_crc =
      contents
      |> CRC.ccitt_16()
      |> Integer.to_string(16)
      |> String.pad_leading(4, "0")

    if check_crc == crc do
      case do_parse(brcode, opts) do
        result when is_map(result) ->
          {:ok, result}

        error ->
          error
      end
    else
      {:error, :invalid_crc}
    end
  end

  # This is basically String.split_at(binary, -4),
  # optimized using the fact that we only have
  # 1-byte characters.
  # The guard is needed so binary_part/3 doesn't raise
  defp extract_crc(binary) when byte_size(binary) > 4 do
    len = byte_size(binary)
    crc = binary_part(binary, len, -4)
    val = binary_part(binary, 0, len - 4)
    {val, crc}
  end

  defp extract_crc(binary), do: {"", binary}

  @doc """
  Decode an iodata to a given schema module.

  This calls `decode/2` and then casts it into an `t:Ecto.Schema` module.

  It must have a changeset/2 public function.
  """
  @spec decode_to(input :: iodata(), Keyword.t(), schema :: module()) ::
          {:ok, struct()} | {:error, term()}
  def decode_to(input, opts \\ [], schema \\ BRCode) do
    case decode(input, opts) do
      {:ok, result} ->
        schema
        |> struct([])
        |> schema.changeset(result)
        |> case do
          %{valid?: true} = c -> {:ok, Changeset.apply_changes(c)}
          error -> {:error, {:validation, error}}
        end

      err ->
        err
    end
  end

  defguardp is_digit(value) when is_integer(value) and value >= ?0 and value <= ?9

  defp do_parse(brcode, opts, keys \\ @keys, acc \\ %{})

  defp do_parse(<<>>, _opts, _keys, acc), do: acc

  # Elixir uses Binaries as the underlying representation for String.
  # The first argument used Elixir's Binary-matching syntax.
  # The matches mean:
  # - key::binary-size(2) -> key is a 2-byte string
  # - size_tens::size(8) -> size_tens is an 8-bit integer
  # - size_units::size(8) -> size_tens is an 8-bit integer
  # - rest::binary -> rest is an undefined-length string

  # Also the is_digit guard is used to ensure that both size_tens and
  # size_units are ASCII encoded digits
  defp do_parse(
         <<key::binary-size(2), size_tens::size(8), size_units::size(8), rest::binary>>,
         opts,
         keys,
         acc
       )
       when is_digit(size_tens) and is_digit(size_units) do
    # Having the tens-place digit and the units-place digit,
    # we need to multiply size_tens by 10 to shift it to the
    # left (e.g. if size_tens is "3", we want to add 30).
    # However, since they are ascii encoded, we need to also subtract
    # ?0 (the ASCII value for "0") from both size_tens and size_units.
    len = (size_tens - ?0) * 10 + (size_units - ?0)

    with {:value, <<value::binary-size(len), rest::binary>>} <- {:value, rest} do
      case Map.get(keys, key) do
        {key, sub_keys} ->
          value = do_parse(value, opts, sub_keys, %{})
          acc = Map.put(acc, key, value)
          do_parse(rest, opts, keys, acc)

        key when is_binary(key) ->
          acc = Map.put(acc, key, value)
          do_parse(rest, opts, keys, acc)

        nil ->
          if Keyword.get(opts, :strict_validation, false) do
            do_parse(rest, opts, keys, acc)
          else
            {:error, :validation, {:unknown_key, key}}
          end
      end
    else
      {:parsed_size, :error} -> {:error, {:validation, :size_not_an_integer}}
      error -> {:error, {:unknown_error, error}}
    end
  end

  defp do_parse(_, _, _, _), do: {:error, {:validation, :invalid_tag_length_value}}
end
