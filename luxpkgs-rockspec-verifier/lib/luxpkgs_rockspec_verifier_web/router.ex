defmodule LuxpkgsRockspecVerifierWeb.Router do
  use LuxpkgsRockspecVerifierWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", LuxpkgsRockspecVerifierWeb do
    pipe_through :api
  end

  scope "/", LuxpkgsRockspecVerifierWeb do
    pipe_through :api

    post "/verify", VerifyController, :verify
    post "/parse", VerifyController, :parse
  end
end
