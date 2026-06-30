defmodule LuaNox.Accounts.TOTPBackupCodeTest do
  use LuaNox.DataCase, async: true

  import LuaNox.AccountsFixtures

  alias LuaNox.Accounts.TOTP
  alias LuaNox.Accounts.TotpBackupCode
  alias LuaNox.Accounts.User
  alias LuaNox.Repo

  @secret <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20>>
  @now 1_700_000_000

  defp enabled_user do
    user = user_fixture()
    :ok = TOTP.enable(user, @secret)
    user
  end

  test "generates ten distinct codes and stores only hashes" do
    user = enabled_user()
    codes = TOTP.generate_backup_codes(user)

    assert length(codes) == 10
    assert Enum.uniq(codes) == codes
    assert TOTP.backup_codes_remaining(user) == 10

    stored = Repo.all(TotpBackupCode)
    assert length(stored) == 10
    refute Enum.any?(stored, fn c -> c.code_hash in codes end)

    Enum.each(codes, fn code ->
      assert Enum.any?(stored, fn c -> Bcrypt.verify_pass(code, c.code_hash) end)
    end)
  end

  test "a backup code verifies once and cannot be reused" do
    user = enabled_user()
    [code | _] = TOTP.generate_backup_codes(user)

    assert TOTP.verify(user, code) == :ok
    assert TOTP.verify(user, code) == :error
    assert TOTP.backup_codes_remaining(user) == 9
  end

  test "backup codes accept separators and mixed case" do
    user = enabled_user()
    [code | _] = TOTP.generate_backup_codes(user)

    assert TOTP.verify(user, TOTP.format_backup_code(code)) == :ok
  end

  test "regenerating invalidates every previous code" do
    user = enabled_user()
    [old | _] = TOTP.generate_backup_codes(user)

    _ = TOTP.generate_backup_codes(user)

    assert TOTP.verify(user, old) == :error
    assert TOTP.backup_codes_remaining(user) == 10
  end

  test "unknown or malformed codes are rejected without consuming a valid one" do
    user = enabled_user()
    TOTP.generate_backup_codes(user)

    assert TOTP.verify(user, "ZZZZZ-ZZZZZ") == :error
    assert TOTP.verify(user, "") == :error
    assert TOTP.verify(user, nil) == :error
    assert TOTP.verify(user, "1234") == :error
    assert TOTP.backup_codes_remaining(user) == 10
  end

  test "a totp code still passes and remains single use" do
    user = enabled_user()
    TOTP.generate_backup_codes(user)
    code = NimbleTOTP.verification_code(@secret, time: @now)

    assert TOTP.verify(user, code, time: @now) == :ok
    assert TOTP.verify(user, code, time: @now) == :error
  end

  test "removing two-factor authentication deletes the secret and every backup code" do
    user = enabled_user()
    TOTP.generate_backup_codes(user)

    assert :ok = TOTP.disable(user)
    assert TOTP.secret(user) == nil
    assert TOTP.backup_codes_remaining(user) == 0
    refute User.has_totp?(user)
  end

  test "backup codes no longer work once two-factor authentication is removed" do
    user = enabled_user()
    [code | _] = TOTP.generate_backup_codes(user)

    :ok = TOTP.disable(user)

    assert TOTP.verify(user, code) == :error
  end
end
