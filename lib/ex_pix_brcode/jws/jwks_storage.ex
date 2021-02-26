defmodule ExPixBRCode.JWS.JWKSStorage do
  @moduledoc """
  A JWKS storage of validated keys and certificates.
  """

  alias ExPixBRCode.JWS.Models.JWKS.Key
  alias ExPixBRCode.JWS.Models.JWSHeaders

  defstruct [:jwk, :certificate, :key]

  @typedoc """
  Storage item.

  It has a parsed JWK, the certificate of the key and the key parsed from the JWKS.
  We should always check the certificate validity before using the signer.
  """
  @type t() :: %__MODULE__{
          jwk: JOSE.JWK.t(),
          certificate: X509.Certificate.t(),
          key: Key.t()
        }

  @doc """
  Get the signer associated with the given 
  """
  @spec jwks_storage_by_jws_headers(JWSHeaders.t()) :: nil | __MODULE__.t()
  def jwks_storage_by_jws_headers(headers) do
    case :persistent_term.get(headers.jku, nil) do
      nil -> nil
      values -> get_key(values, headers)
    end
  end

  defp get_key(values, %{x5t: thumb, kid: kid}) when is_binary(thumb),
    do: Map.get(values, {thumb, kid})

  defp get_key(values, %{:"x5t#S256" => thumb, :kid => kid}) when is_binary(thumb),
    do: Map.get(values, {thumb, kid})

  @doc """
  Process validation and storage of keys.

  Keys in JWKS endpoints must pass the following validations:
    - Must be of either EC or RSA types
    - Must have the x5c claim
    - The first certificate in the x5c claim MUST have the same key parameters as the key in the
    root
    - The certificate thumbprint must match that of the first certificate in the chain

  After successful validation, keys are inserted in a `:persistent_term`.
  """
  @spec process_keys([Key.t()], jku :: String.t(), opts :: Keyword.t()) ::
          :ok
          | {:error,
             :key_thumbprint_and_first_certificate_differ
             | :key_from_first_certificate_differ
             | :invalid_certificate_encoding
             | :certificate_subject_and_jku_uri_authority_differs}
  def process_keys(keys, jku, opts) when is_list(keys) do
    case Enum.reduce_while(keys, {:ok, []}, &validate_and_persist_key(&1, jku, &2, opts)) do
      {:ok, keys} -> :persistent_term.put(jku, Map.new(keys))
      {:error, _} = err -> err
    end
  end

  defp validate_and_persist_key(%Key{x5c: [b64_cert | _] = chain} = key, jku, {:ok, acc}, opts) do
    key_from_params = key |> build_key_map() |> JOSE.JWK.from_map()

    with {:ok, jwk} <- validate_certificate_chain(chain, key_from_params, opts),
         {:ok, certificate, raw_der} <- get_certificate(b64_cert),
         {:ok, certificate} <-
           validate_leaf_certificate(certificate, raw_der, jku, key, opts),
         {:key_from_cert, true} <- {:key_from_cert, key_from_params == jwk} do
      storage_item = %__MODULE__{jwk: key_from_params, certificate: certificate, key: key}

      keys =
        [Map.get(key, :x5t), Map.get(key, :"x5t#S256")]
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&{{&1, key.kid}, storage_item})

      {:cont, {:ok, keys ++ acc}}
    else
      {:key_from_cert, false} -> {:halt, {:error, :key_from_leaf_certificate_differ}}
      {:error, _} = err -> {:halt, err}
      :error -> {:halt, {:error, :invalid_certificate_encoding}}
    end
  end

  defp get_certificate(b64_cert) do
    with {:ok, raw_der} <- Base.decode64(b64_cert),
         {:ok, certificate} <- X509.Certificate.from_der(raw_der) do
      {:ok, certificate, raw_der}
    end
  end

  @doc false
  def validate_leaf_certificate(certificate, raw_der, jku, key, opts) do
    with true <- Keyword.get(opts, :leaf_certificate_should_fail, true),
         :ok <- validate_cert_subject(certificate, jku),
         {:x5t, true} <- validate_thumbprint(raw_der, key) do
      {:ok, certificate}
    else
      false -> {:ok, certificate}
      {:x5t, false} -> {:error, :key_thumbprint_and_leaf_certificate_differ}
      :error -> :error
      {:error, _} = err -> err
    end
  end

  defp validate_thumbprint(raw_der, %{x5t: thumb}) when is_binary(thumb),
    do: {:x5t, thumbprint(raw_der) == thumb}

  defp validate_thumbprint(raw_der, %{:"x5t#S256" => thumb}) when is_binary(thumb),
    do: {:x5t, thumbprint(raw_der, :sha256) == thumb}

  defp validate_certificate_chain(chain, key_from_params, opts) do
    with true <- Keyword.get(opts, :x5c_should_fail, true),
         {:ok, [root | certificate_chain]} <- decode_chain(chain),
         {:ok, {{_, pkey, _}, _}} <-
           :public_key.pkix_path_validation(root, certificate_chain, []) do
      {:ok, JOSE.JWK.from_key(pkey)}
    else
      false -> {:ok, key_from_params}
      :error -> {:error, :invalid_cert_encoding}
      {:error, _} = err -> err
    end
  end

  defp decode_chain(chain) when length(chain) > 1 do
    # This reverses the chain automatically
    Enum.reduce_while(chain, {:ok, []}, fn cert, {:ok, acc} ->
      case Base.decode64(cert) do
        {:ok, decoded_cert} -> {:cont, {:ok, [decoded_cert | acc]}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp decode_chain(_), do: {:error, :x5c_must_have_more_than_one_cert}

  defp validate_cert_subject(certificate, jku) do
    jku = URI.parse(jku)

    [authority | _] =
      certificate
      |> X509.Certificate.subject()
      |> X509.RDNSequence.get_attr("commonName")

    {:Extension, {2, 5, 29, 17}, _, values} =
      X509.Certificate.extension(certificate, {2, 5, 29, 17})

    dns = Keyword.get(values, :dNSName, nil) |> to_string()

    if jku.authority == authority or jku.authority == dns do
      :ok
    else
      {:error, :certificate_subject_and_jku_uri_authority_differs}
    end
  end

  defp build_key_map(%{kty: "EC"} = key),
    do: %{"kty" => "EC", "crv" => key.crv, "x" => key.x, "y" => key.y}

  defp build_key_map(%{kty: "RSA"} = key),
    do: %{"kty" => "RSA", "n" => key.n, "e" => key.e}

  defp thumbprint(raw_cert, alg \\ :sha) do
    alg
    |> :crypto.hash(raw_cert)
    |> Base.url_encode64(padding: false)
  end
end
