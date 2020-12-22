defmodule ExPixBRCode.JWS do
  @moduledoc """
  JWS utilities for validating certificates/signatures/etc.
  """

  alias ExPixBRCode.JWS.JWKSStorage

  defdelegate process_keys(keys, jku, opts \\ []), to: JWKSStorage
  defdelegate jwks_storage_by_jws_headers(headers), to: JWKSStorage
end
