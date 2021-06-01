defmodule Ueberauth.Strategy.OAuthRetryTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Mock

  @session_options Plug.Session.init(
                     store: Plug.Session.COOKIE,
                     key: "_test_key",
                     signing_salt: "abc012345"
                   )

  @body_access_token Jason.encode!(%{
                       "access_token" => "success_access_token",
                       "openid" => "test_openid"
                     })

  @body_userinfo Jason.encode!(%{
                   "openid" => "test_openid",
                   "nickname" => "test_nickname",
                   "unionid" => "test_unionid"
                 })

  setup_with_mocks([
    {
      Finch,
      [:passthrough],
      [
        request: &request/2
      ]
    }
  ]) do
    :ok
  end

  def request(%{path: "/sns/oauth2/access_token", method: "GET"}, _) do
    case Process.get("retry_access_token") do
      index when index in [0, 1, 2, 3, 4] ->
        Process.put("retry_access_token", index + 1)
        {:error, :timeout}

      _ ->
        {:ok, %{body: @body_access_token, status: 200}}
    end
  end

  def request(%{path: "/sns/userinfo", method: "GET"}, _) do
    case Process.get("retry_access_token") do
      5 ->
        Process.put("retry_access_token", 0)
        {:error, :closed}

      _ ->
        {:ok, %{body: @body_userinfo, status: 200}}
    end
  end

  test "handle_callback! with retry" do
    Process.put("retry_access_token", 0)

    conn = conn(:get, "/auth/wechat", %{})

    routes = Ueberauth.init()

    resp = Ueberauth.call(conn, routes) |> Plug.Conn.fetch_cookies()

    state = resp.private.ueberauth_state_param

    conn =
      :get
      |> conn("/auth/wechat/callback", %{code: "success_code", state: state})
      |> Map.put(:cookies, resp.cookies)
      |> Map.put(:req_cookies, resp.req_cookies)
      |> Plug.Session.call(@session_options)

    resp = Ueberauth.call(conn, routes)

    %Plug.Conn{assigns: %{ueberauth_auth: auth}} = resp

    assert auth.uid == "test_unionid"

    wechat_user = resp.private.wechat_user

    assert wechat_user["nickname"] == "test_nickname"
    assert wechat_user["openid"] == "test_openid"
    assert wechat_user["unionid"] == "test_unionid"
    assert resp.req_cookies == %{}

    assert Process.get("retry_access_token") == 0
  end
end
