import Config

config :ueberauth, Ueberauth,
  providers: [
    wechat: {Ueberauth.Strategy.WeChat, []}
  ]

config :ueberauth, Ueberauth.Strategy.WeChat.OAuth,
  appid: "config_test_appid"
