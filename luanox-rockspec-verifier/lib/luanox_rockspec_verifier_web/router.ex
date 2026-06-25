defmodule LuanoxRockspecVerifierWeb.Router do
  use LuanoxRockspecVerifierWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", LuanoxRockspecVerifierWeb do
    pipe_through :api
  end

  scope "/", LuanoxRockspecVerifierWeb do
    pipe_through :api

    post "/verify", VerifyController, :verify
    post "/parse", VerifyController, :parse
  end
end
