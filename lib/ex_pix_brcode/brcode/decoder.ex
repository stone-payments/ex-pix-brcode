defmodule ExPixBRCode.BRCodes.Decoder do
  @moduledoc """
  Decode iodata that represent a BRCode.
  """

  alias ExPixBRCode.BRCodes.Models.BRCode
  alias ExPixBRCode.Changesets

  @keys %{
    "00" => "payload_format_indicator",
    "01" => "point_of_initiation_method",
    "26" =>
      {"merchant_account_information",
       %{
         "00" => "gui",
         "01" => "chave",
         "02" => "info_adicional",
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

  @max_size_in_bytes 512

  @doc """
  Decode input into a map with string keys with known keys for BRCode.

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
          {:ok, term()}
          | {:error,
             {:validation,
              :invalid_tag_length_value
              | {:unexpected_value_length_for_key, String.t()}
              | {:unknown_key, String.t()}}
             | :unknown_error
             | :invalid_crc
             | :invalid_input_length}

  def decode(input, opts \\ []) do
    brcode = IO.iodata_to_binary(input)

    with {:ok, brcode} <- check_brcode_size(brcode),
         {:ok, {contents, crc}} <- extract_crc(brcode),
         :ok <- validate_crc(contents, crc) do
      parse(brcode, opts)
    end
  end

  # This is basically String.split_at(binary, -4),
  # optimized using the facts that we only have
  # 1-byte characters in the CRC and that we can count
  # right to left. The guard is needed so that
  # binary_part/3 doesn't raise
  defp extract_crc(binary) when byte_size(binary) > 4 do
    len = byte_size(binary)
    crc = binary_part(binary, len, -4)
    val = binary_part(binary, 0, len - 4)
    {:ok, {val, crc}}
  end

  defp extract_crc(_binary), do: {:error, :invalid_input_length}

  defp validate_crc(contents, received_crc) do
    calculated_crc =
      contents
      |> CRC.ccitt_16()
      |> Integer.to_string(16)
      |> String.pad_leading(4, "0")

    if received_crc == calculated_crc do
      :ok
    else
      {:error, :invalid_crc}
    end
  end

  defp parse(brcode, opts) do
    case do_parse(brcode, opts) do
      result when is_map(result) ->
        {:ok, result}

      error ->
        error
    end
  end

  defp check_brcode_size(brcode) when byte_size(brcode) <= @max_size_in_bytes, do: {:ok, brcode}
  defp check_brcode_size(_brcode), do: {:error, :invalid_input_size}

  @doc """
  Decode an iodata to a given schema module.

  This calls `decode/2` and then casts it into an `t:Ecto.Schema` module.

  It must have a changeset/2 public function.
  """
  @spec decode_to(input :: iodata(), Keyword.t(), schema :: module()) ::
          {:ok, struct()} | {:error, term()}
  def decode_to(input, opts \\ [], schema \\ BRCode) do
    case decode(input, opts) do
      {:ok, result} -> Changesets.cast_and_apply(schema, result)
      err -> err
    end
  end

  # This guard ensures a number is the integer representation of the
  # ASCII characters 0 through 9, inclusive
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
    # However, since they are ascii encoded, we also need to subtract
    # ?0 (the ASCII value for "0") from both `size_tens` and `size_units`.
    len = (size_tens - ?0) * 10 + (size_units - ?0)

    {value, rest} = String.split_at(rest, len)
    effective_length = String.length(value)

    strict_validation = Keyword.get(opts, :strict_validation, false)

    result = Map.get(keys, key)

    case {effective_length, result, strict_validation} do
      {effective_length, _result, _strict_validation} when effective_length != len ->
        {:error, {:validation, {:unexpected_value_length_for_key, key}}}

      {_, {key, sub_keys}, _} ->
        value = do_parse(value, opts, sub_keys, %{})
        acc = Map.put(acc, key, value)
        do_parse(rest, opts, keys, acc)

      {_, key, _} when is_binary(key) ->
        acc = Map.put(acc, key, value)
        do_parse(rest, opts, keys, acc)

      {_, nil, false} ->
        do_parse(rest, opts, keys, acc)

      _ ->
        {:error, :validation, {:unknown_key, key}}
    end
  end

  defp do_parse(
         <<key::binary-size(2), size_tens::size(8), size_units::size(8), _rest::binary>>,
         _opts,
         _keys,
         _acc
       )
       when not is_digit(size_tens) or not is_digit(size_units) do
    {:error, {:validation, {:invalid_length_for_tag, key}}}
  end

  defp do_parse(_, _, _, _), do: {:error, {:validation, :invalid_tag_length_value}}
end
