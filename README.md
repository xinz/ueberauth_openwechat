# UeberauthOpenWeChat

> WeChat OAuth2 strategy for Überauth.

## Installation

1.  Setup your application at [WeChat Open Platform](https://open.weixin.qq.com/).

2.  Add `:ueberauth_openwechat` to your list of dependencies in `mix.exs`.

3.  Add WeChat to your Überauth configuration:

     ```elixir
     config :ueberauth, Ueberauth,
       providers: [
         wechat: {Ueberauth.Strategy.WeChat, []}
       ]
     ```
4.  Update your provider configuration:

    Use that if you want to read app ID/secret from the environment
    variables in the compile time:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.WeChat.OAuth,
      appid: System.get_env("WECHAT_APP_ID"),
      appsecret: System.get_env("WECHAT_APP_SECRET")
    ```

    Use that if you want to read app ID/secret from the environment
    variables in the run time:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.WeChat.OAuth,
      appid: {System, :get_env, ["WECHAT_APP_ID"]},
      appsecret: {System, :get_env, ["WECHAT_APP_SECRET"]}
    ```
     
    Note: this configuration is optional if do not fetch user information in this service,
    there provide a optional way to pass the `authorization code` to the third application,
    and then fetch user information with the above mentioned `appid` and `appsecret` configuration.

5.  Include the Überauth plug in your controller:

    ```elixir
    defmodule MyApp.AuthController do
      use MyApp.Web, :controller
      plug Ueberauth
      ...
    end
    ```

6.  Create the request and callback routes if you haven't already:

    ```elixir
    scope "/auth", MyApp do
      pipe_through :browser

      get "/:provider", AuthController, :request
      get "/:provider/callback", AuthController, :callback
    end
    ```

    Note:
    
    * If the defined service will pass the authorization code to the third application, the `/auth/:provider/callback`
      url is useless.
    * If the defined service will *ONLY* use the authorization code to fetch user information, the `/auth/:provider` url
      is useless.

7.  Your controller needs to implement callbacks to deal with `Ueberauth.Auth` and `Ueberauth.Failure` responses,
    for example:

    ```elixir
    defmodule MyApp.AuthController do
      use UehelloWeb, :controller

      plug Ueberauth

      alias Ueberauth.Strategy.Helpers

      def request(conn, _params) do
        render(conn, "request.html", callback_url: Helpers.callback_url(conn))
      end

      def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
        conn
        |> put_flash(:error, "Failed to authenticate.")
        |> redirect(to: "/")
      end

      def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
        IO.inspect(auth)
        ...
      end
    end
    ```

## Calling

Depending on the configured url you can initiate the request through:

```text
/auth/wechat
```

Or with options:

```text
/auth/wechat?appid=YOUR_APPID
```

Custom the lang parameter to call the [snsapi_userinfo](https://developers.weixin.qq.com/doc/oplatform/Third-party_Platforms/2.0/api/Before_Develop/Official_Accounts/official_account_website_authorization.html) API

```text
/auth/wechat?appid=YOUR_APPID&lang=zh_CN
```

If you want to pass the authorization code to the third application (e.g "https://yourthirdapp.com/auth/wechat/callback") to finish OAuth2:

```text
/auth/wechat?appid=YOUR_APPID&lang=zh_CN&redirect_uri=https%3A%2F%2Fyourthirdapp.com%2Fauth%2Fwechat%2Fcallback
```

In this case, after a user authorized, we will see the authorization code parameter into like this:

```text
https://yourthirdapp.com/auth/wechat/callback?code=CODE
```

You can fetch the authorized user information in the third application by the `code` and the configured `appid` and `appsecret`.

## License

MIT
