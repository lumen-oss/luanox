defmodule LuaNox.Accounts.TOTPTest do
  use LuaNox.DataCase

  import LuaNox.AccountsFixtures

  alias LuaNox.Accounts.TOTP

  @secret <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20>>
  @now 1_700_000_000

  defp enabled_user do
    user = user_fixture()
    assert :ok = TOTP.enable(user, @secret)
    user
  end

  defp code(time), do: NimbleTOTP.verification_code(@secret, time: time)

  test "accepts the current code" do
    assert TOTP.verify(enabled_user(), code(@now), time: @now) == :ok
  end

  test "tolerates one step of clock drift either way" do
    assert TOTP.verify(enabled_user(), code(@now - 30), time: @now) == :ok
    assert TOTP.verify(enabled_user(), code(@now + 30), time: @now) == :ok
  end

  test "rejects a code replayed in the same step" do
    user = enabled_user()
    assert TOTP.verify(user, code(@now), time: @now) == :ok
    assert TOTP.verify(user, code(@now), time: @now) == :error
  end

  test "rejects a code replayed in a later step" do
    user = enabled_user()
    assert TOTP.verify(user, code(@now), time: @now) == :ok
    assert TOTP.verify(user, code(@now), time: @now + 30) == :error
  end

  test "rejects codes outside the drift window" do
    assert TOTP.verify(enabled_user(), code(@now - 60), time: @now) == :error
  end
end
