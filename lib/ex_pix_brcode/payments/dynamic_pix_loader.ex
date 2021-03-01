defmodule ExPixBRCode.Payments.DynamicPixLoader do
  @moduledoc """
  Load either a :dynamic_payment_immediate or a :dynamic_payment_with_due_date from a url.

  Dynamic payments have a URL inside their text representation which we should use to
  validate the certificate chain and signature and fill a Pix payment model.
  """

  alias ExPixBRCode.Changesets
  alias ExPixBRCode.JWS
  alias ExPixBRCode.JWS.Models.{JWKS, JWSHeaders}
  alias ExPixBRCode.Payments.Models.{DynamicImmediatePixPayment, DynamicPixPaymentWithDueDate}

  defguardp is_success(status) when status >= 200 and status < 300

  @doc """
  Given a `t:Tesla.Client` and a PIX payment URL it loads its details after validation.
  """
  @spec load_pix(Tesla.Client.t(), String.t()) ::
          {:ok, DynamicImmediatePixPayment.t() | DynamicPixPaymentWithDueDate.t()}
          | {:error, atom()}
  def load_pix(client, url, opts \\ []) do
    query_params = Keyword.get(opts, :query_params, [])
    case Tesla.get(client, url, query_params: query_params) do
      {:ok, %{status: status} = env} when is_success(status) ->
        do_process_jws(client, url, env.body, opts)

      {:ok, _} ->
        {:error, :http_status_not_success}

      {:error, _} = err ->
        err
    end
  end

  defp do_process_jws(client, url, jws, opts) do
    with {:ok, header_claims} <- Joken.peek_header(jws),
         {:ok, header_claims} <-
           Changesets.cast_and_apply(JWSHeaders, header_claims),
         {:ok, jwks_storage} <- fetch_jwks_storage(client, header_claims, opts),
         :ok <- verify_certificate(jwks_storage.certificate),
         :ok <- verify_alg(jwks_storage.jwk, header_claims.alg),
         {:ok, payload} <-
           Joken.verify(jws, build_signer(jwks_storage.jwk, header_claims.alg)),
         type <- type_from_url(url),
         {:ok, pix} <- Changesets.cast_and_apply(type, payload) do
      {:ok, pix}
    end
  end

  defp type_from_url(url) do
    url
    |> URI.parse()
    |> Map.get(:path)
    |> Path.split()
    |> Enum.member?("cobv")
    |> if do
      DynamicPixPaymentWithDueDate
    else
      DynamicImmediatePixPayment
    end
  end

  defp build_signer(jwk, alg) do
    %Joken.Signer{
      alg: alg,
      jwk: jwk,
      jws: JOSE.JWS.from_map(%{"alg" => alg})
    }
  end

  defp verify_alg(%{kty: {:jose_jwk_kty_ec, _}}, alg)
       when alg in ["ES256", "ES384", "ES512"],
       do: :ok

  defp verify_alg(%{kty: {:jose_jwk_kty_rsa, _}}, alg)
       when alg in ["PS256", "PS384", "PS512", "RS256", "RS384", "RS512"],
       do: :ok

  defp verify_alg(_jwk, _alg) do
    {:error, :invalid_token_signing_algorithm}
  end

  defp verify_certificate(certificate) do
    {:Validity, not_before, not_after} = X509.Certificate.validity(certificate)

    not_before_check = DateTime.compare(DateTime.utc_now(), X509.DateTime.to_datetime(not_before))
    not_after_check = DateTime.compare(DateTime.utc_now(), X509.DateTime.to_datetime(not_after))

    cond do
      not_before_check not in [:gt, :eq] -> {:error, :certificate_not_yet_valid}
      not_after_check not in [:lt, :eq] -> {:error, :certificate_expired}
      true -> :ok
    end
  end

  defp fetch_jwks_storage(client, header_claims, opts) do
    case JWS.jwks_storage_by_jws_headers(header_claims) do
      nil ->
        try_fetching_signers(client, header_claims, opts)

      storage_item ->
        {:ok, storage_item}
    end
  end

  defp try_fetching_signers(client, header_claims, opts) do
    case Tesla.get(client, header_claims.jku) do
      {:ok, %{status: status} = env} when is_success(status) ->
        process_jwks(env.body, header_claims, opts)

      {:ok, _} ->
        {:error, :http_status_not_success}

      {:error, _} = err ->
        err
    end
  end

  defp process_jwks(jwks, header_claims, opts) when is_binary(jwks) do
    case Jason.decode(jwks) do
      {:ok, jwks} when is_map(jwks) -> process_jwks(jwks, header_claims, opts)
      {:error, _} = err -> err
      {:ok, _} -> {:error, :invalid_jwks_contents}
    end
  end

  defp process_jwks(jwks, header_claims, opts) when is_map(jwks) do
    with {:ok, jwks} <- Changesets.cast_and_apply(JWKS, jwks),
         :ok <- JWS.process_keys(jwks.keys, header_claims.jku, opts),
         storage_item when not is_nil(storage_item) <-
           JWS.jwks_storage_by_jws_headers(header_claims) do
      {:ok, storage_item}
    else
      nil -> {:error, :key_not_found_in_jku}
      err -> err
    end
  end
end
