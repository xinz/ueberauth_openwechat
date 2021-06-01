defmodule Ueberauth.Strategy.WeChat do
  @moduledoc """
  WeChat Strategy for Überauth.
  """

  use Ueberauth.Strategy,
    uid_field: :unionid,
    ignores_csrf_attack:
      :ueberauth
      |> Application.get_env(Ueberauth.Strategy.WeChat, [])
      |> Keyword.get(:ignores_csrf_attack, false)

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @scope "snsapi_login"

  @impl true
  def handle_request!(conn) do
    state = conn.private[:ueberauth_state_param]

    params =
      [scope: @scope, state: state, redirect_uri: may_append_params_to_callback_url(conn)]
      |> with_param(:appid, conn)

    redirect!(conn, Ueberauth.Strategy.WeChat.OAuth.authorize_url(params))
  end

  @impl true
  def handle_callback!(
        %Plug.Conn{params: %{"code" => _code, "redirect_uri" => redirect_uri} = params} = conn
      ) do
    uri =
      params
      |> Map.take(["code", "lang"])
      |> merge_query_params_to_uri(redirect_uri)

    redirect!(conn, uri)
  end

  @impl true
  def handle_callback!(%Plug.Conn{params: %{"code" => code} = params} = conn) do
    case Ueberauth.Strategy.WeChat.OAuth.get_access_token(code: code) do
      {:ok, %{body: token}} ->
        fetch_user(conn, token, params["lang"])

      {:error, _error} ->
        set_errors!(conn, [error("invalid_code", "Invalid code")])
    end
  end

  @impl true
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @impl true
  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string()

    conn.private.wechat_user[uid_field]
  end

  @impl true
  def credentials(conn) do
    token = conn.private.wechat_token
    scope_string = token["scope"] || ""
    scopes = String.split(scope_string, ",")

    %Credentials{
      token: token["access_token"],
      refresh_token: token["refresh_token"],
      expires_at: token["expires_in"],
      token_type: nil,
      expires: !!token["expires_in"],
      scopes: scopes
    }
  end

  @impl true
  def info(conn) do
    user = conn.private.wechat_user

    %Info{
      nickname: user["nickname"],
      image: user["headimgurl"]
    }
  end

  @impl true
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.wechat_token,
        user: conn.private.wechat_user
      }
    }
  end

  defp may_append_params_to_callback_url(conn) do
    options =
      []
      |> with_param(:redirect_uri, conn)
      |> with_param(:lang, conn)

    callback_url(conn, options)
  end

  defp with_param(options, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(options, key, value), else: options
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end

  defp fetch_user(conn, token, lang) do
    conn = put_private(conn, :wechat_token, token)

    response = Ueberauth.Strategy.WeChat.OAuth.get_userinfo(token, lang)

    case response do
      {:ok, %{body: %{"errcode" => errcode, "errmsg" => errmsg}}} ->
        set_errors!(conn, [error(errcode, errmsg)])

      {:ok, %{body: user}} ->
        put_private(conn, :wechat_user, user)

      {:error, %{status_code: status_code}} ->
        set_errors!(conn, [error("OAuth2", status_code)])

      {:error, %{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp merge_query_params_to_uri(params, uri) when is_bitstring(uri) do
    uri = URI.parse(uri)

    query =
      (uri.query || "")
      |> URI.decode_query()
      |> Map.merge(params)
      |> URI.encode_query()

    URI.to_string(%{uri | query: query})
  end
end
