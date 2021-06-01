defmodule Ueberauth.Strategy.WeChat.OAuth do
  @api_host "https://api.weixin.qq.com"

  @context %{
    retries: 0,
    delay: 50,
    max_retries: 5,
    max_delay: 5_000,
    jitter_factor: 0.2
  }

  def authorize_url(params) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    params =
      params
      |> Keyword.put(:response_type, "code")
      |> Keyword.put_new(:appid, config[:appid])

    "https://open.weixin.qq.com/connect/qrconnect?#{URI.encode_query(params)}"
  end

  def get_access_token(params) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    params =
      params
      |> Keyword.put(:grant_type, "authorization_code")
      |> Keyword.put_new(:appid, config[:appid])
      |> Keyword.put(:secret, config[:appsecret])

    url = "#{@api_host}/sns/oauth2/access_token?#{URI.encode_query(params)}"
    retry(&send_get_request/1, [url], @context)
  end

  def get_userinfo(token, lang) when lang in ["zh_CN", "zh_TW", "en"] do
    token
    |> Map.take(["access_token", "openid"])
    |> Map.put("lang", lang)
    |> get_userinfo()
  end

  def get_userinfo(token, _) do
    token
    |> Map.take(["access_token", "openid"])
    |> get_userinfo()
  end

  defp get_userinfo(params) do
    url = "#{@api_host}/sns/userinfo?#{URI.encode_query(params)}"
    retry(&send_get_request/1, [url], @context)
  end

  defp send_get_request(url) do
    :get
    |> Finch.build(url)
    |> Finch.request(UeberauthWeChat.HttpClient)
  end

  defp retry(fun, args, %{max_retries: max, retries: max}) do
    request_and_json_decode_resp(fun, args)
  end

  defp retry(fun, args, context) do
    result = request_and_json_decode_resp(fun, args)

    if should_retry?(result) do
      backoff(context.max_delay, context.delay, context.retries, context.jitter_factor)
      context = update_in(context, [:retries], &(&1 + 1))
      retry(fun, args, context)
    else
      result
    end
  end

  defp should_retry?({:error, :closed}), do: true
  defp should_retry?({:error, :timeout}), do: true
  defp should_retry?({:error, _error}), do: false
  defp should_retry?({:ok, _response}), do: false

  defp request_and_json_decode_resp(fun, args) do
    case apply(fun, args) do
      {:ok, %{status: 200, body: ""}} = response ->
        {:ok, response}

      {:ok, %{status: 200, body: body} = response} ->
        {:ok, %{response | body: Jason.decode!(body)}}

      {:error, error} ->
        {:error, error}
    end
  end

  # Exponential backoff with jitter
  defp backoff(cap, base, attempt, jitter_factor) do
    factor = Bitwise.bsl(1, attempt)
    max_sleep = min(cap, base * factor)

    # This ensures that the delay's order of magnitude is kept intact, while still having some jitter.
    # Generates a value x where 1-jitter_factor <= x <= 1 + jitter_factor
    jitter = 1 + 2 * jitter_factor * :rand.uniform() - jitter_factor

    # The actual delay is in the range max_sleep * (1 - jitter_factor), max_sleep * (1 + jitter_factor)
    delay = trunc(max_sleep + jitter)

    :timer.sleep(delay)
  end
end
