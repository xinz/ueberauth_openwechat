defmodule Ueberauth.Strategy.WechatTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Ueberauth.Strategy.WeChat.OAuth
  import Mock

  @session_options Plug.Session.init(
                     store: Plug.Session.COOKIE,
                     key: "_test_key",
                     signing_salt: "abc012345"
                   )

  setup_with_mocks([
    {
      OAuth,
      [:passthrough],
      [
        get_access_token: &get_access_token/1,
        get_userinfo: &get_userinfo/2
      ]
    }
  ]) do
    :ok
  end

  def get_access_token(code: "success_code") do
    body = %{
      "access_token" => "success_access_token",
      "openid" => "test_openid"
    }

    {:ok, %{body: body}}
  end

  def get_access_token(code: "invalid_code") do
    {:error, %{body: %{"errcode" => 40013, "errmsg" => "invalid code"}}}
  end

  def get_userinfo(%{"access_token" => "success_access_token", "openid" => "test_openid"}, _lang) do
    body = %{
      "openid" => "test_openid",
      "nickname" => "test_nickname",
      "unionid" => "test_unionid"
    }

    {:ok, %{body: body}}
  end

  test "handle_request! with an optional third redirect_uri param" do
    appid = "testappid"
    third_redirection = "http://localhost:4333/code_to_access_token"
    conn = conn(:get, "/auth/wechat", %{redirect_uri: third_redirection, appid: appid})

    routes = Ueberauth.init()

    resp = Ueberauth.call(conn, routes)

    assert resp.status == 302

    [location] = get_resp_header(resp, "location")
    redirect_uri = URI.parse(location)
    assert redirect_uri.host == "open.weixin.qq.com"
    assert redirect_uri.path == "/connect/qrconnect"

    query_params = Plug.Conn.Query.decode(redirect_uri.query)
    assert query_params["appid"] == appid
    assert query_params["scope"] == "snsapi_login"
    assert query_params["redirect_uri"] =~ ~s|www.example.com/auth/wechat/callback|

    assert query_params["redirect_uri"] =~
             ~s|redirect_uri=#{URI.encode_www_form(third_redirection)}|

    assert is_bitstring(query_params["state"]) == true
  end

  test "handle_request! without the third redirect_uri param" do
    conn = conn(:get, "/auth/wechat", %{})

    routes = Ueberauth.init()

    resp = Ueberauth.call(conn, routes)

    assert resp.status == 302

    [location] = get_resp_header(resp, "location")
    redirect_uri = URI.parse(location)
    assert redirect_uri.host == "open.weixin.qq.com"
    assert redirect_uri.path == "/connect/qrconnect"

    query_params = Plug.Conn.Query.decode(redirect_uri.query)
    assert query_params["appid"] == "config_test_appid"
    assert query_params["scope"] == "snsapi_login"
    assert query_params["redirect_uri"] == "http://www.example.com/auth/wechat/callback"
    assert is_bitstring(query_params["state"]) == true
  end

  test "handle_request! with an optional lang param" do
    lang = "en"
    conn = conn(:get, "/auth/wechat", %{lang: lang})

    routes = Ueberauth.init()

    resp = Ueberauth.call(conn, routes)

    assert resp.status == 302

    [location] = get_resp_header(resp, "location")
    redirect_uri = URI.parse(location)
    assert redirect_uri.host == "open.weixin.qq.com"
    assert redirect_uri.path == "/connect/qrconnect"

    query_params = Plug.Conn.Query.decode(redirect_uri.query)
    assert query_params["appid"] == "config_test_appid"
    assert query_params["scope"] == "snsapi_login"

    assert query_params["redirect_uri"] ==
             "http://www.example.com/auth/wechat/callback?lang=#{lang}"

    assert is_bitstring(query_params["state"]) == true
  end

  test "handle_callback! assigns required fields on successful auth" do
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
  end

  test "handle_callback! assigns required fields with invalid token" do
    conn = conn(:get, "/auth/wechat", %{})

    routes = Ueberauth.init()

    resp = Ueberauth.call(conn, routes) |> Plug.Conn.fetch_cookies()

    state = resp.private.ueberauth_state_param

    conn =
      :get
      |> conn("/auth/wechat/callback", %{code: "invalid_code", state: state})
      |> Map.put(:cookies, resp.cookies)
      |> Map.put(:req_cookies, resp.req_cookies)
      |> Plug.Session.call(@session_options)

    resp = Ueberauth.call(conn, routes)

    assert resp.assigns.ueberauth_failure != nil
  end
end
