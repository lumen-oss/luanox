defmodule LuaNox.AccountsTest do
  use LuaNox.DataCase

  alias LuaNox.Accounts

  import LuaNox.AccountsFixtures
  alias LuaNox.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "register_user/1" do
    test "stores the oauth avatar URL" do
      auth = %Ueberauth.Auth{
        provider: "github",
        info: %Ueberauth.Auth.Info{
          nickname: "ntb",
          name: "NTBBloodbath",
          email: unique_user_email(),
          image: "https://avatars.githubusercontent.com/u/36456999"
        }
      }

      assert {:ok, %User{avatar_url: url}} = Accounts.register_user(auth)
      assert url == "https://avatars.githubusercontent.com/u/36456999"
    end

    test "rejects avatar URLs from untrusted hosts" do
      auth = %Ueberauth.Auth{
        provider: "github",
        info: %Ueberauth.Auth.Info{
          nickname: "ntb",
          name: "NTBBloodbath",
          email: unique_user_email(),
          image: "https://evil.example/avatar.png"
        }
      }

      assert {:error, %Ecto.Changeset{errors: errors}} = Accounts.register_user(auth)
      assert {"must come from a trusted provider", _opts} = errors[:avatar_url]
    end
  end

  describe "update_bio/2" do
    test "updates the user's bio" do
      user = user_fixture()

      assert {:ok, %User{bio: "Making awesome Lua plugins"}} =
               Accounts.update_bio(user, "Making awesome Lua plugins")
    end

    test "strips URLs from the bio" do
      user = user_fixture()

      assert {:ok, %User{bio: bio}} =
               Accounts.update_bio(user, "Check my site: https://malicious.example/foo")

      refute bio =~ "https://"
    end

    test "strips bare domains from the bio" do
      user = user_fixture()

      assert {:ok, %User{bio: bio}} = Accounts.update_bio(user, "Visit evil.com now")

      refute bio =~ "evil.com"
    end

    test "trims surrounding whitespace from the bio" do
      user = user_fixture()

      assert {:ok, %User{bio: "hello world"}} =
               Accounts.update_bio(user, "  hello world\n")
    end

    test "rejects bios longer than 160 characters" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Accounts.update_bio(user, String.duplicate("a", 161))

      assert {"should be at most %{count} character(s)", _opts} = errors[:bio]
    end
  end

  describe "update_user_avatar/2" do
    test "updates the avatar URL" do
      user = user_fixture()

      assert {:ok, %User{avatar_url: "https://avatars.githubusercontent.com/u/36456999"}} =
               Accounts.update_user_avatar(
                 user,
                 "https://avatars.githubusercontent.com/u/36456999"
               )
    end

    test "rejects avatar URLs from untrusted hosts" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Accounts.update_user_avatar(user, "https://evil.example/avatar.png")

      assert {"must come from a trusted provider", _opts} = errors[:avatar_url]
    end

    test "rejects non-https avatar URLs" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_user_avatar(
                 user,
                 "http://avatars.githubusercontent.com/u/76052559"
               )
    end
  end

  describe "two-factor authentication" do
    test "totp_enabled?/1 returns false when no secret" do
      user = user_fixture()
      refute Accounts.totp_enabled?(user)
    end

    test "enable_totp/3 with valid code persists the secret" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(Base.decode32!(secret))

      assert {:ok, user} = Accounts.enable_totp(user, secret, code)
      assert Accounts.totp_enabled?(user)
      assert user.totp_secret == secret
    end

    test "enable_totp/3 with invalid code returns error" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()

      assert {:error, :invalid_code} = Accounts.enable_totp(user, secret, "000000")
      refute Accounts.totp_enabled?(user)
    end

    test "verify_totp/2 validates the current code" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(Base.decode32!(secret))

      {:ok, user} = Accounts.enable_totp(user, secret, code)
      assert Accounts.verify_totp(user, NimbleTOTP.verification_code(Base.decode32!(secret)))
      refute Accounts.verify_totp(user, "000000")
    end

    test "disable_totp/2 clears secret and recovery codes" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(Base.decode32!(secret))

      {:ok, user} = Accounts.enable_totp(user, secret, code)
      Accounts.generate_recovery_codes(user)
      assert length(LuaNox.Repo.all(LuaNox.Accounts.UserRecoveryCode)) == 10

      {:ok, user} = Accounts.disable_totp(user, NimbleTOTP.verification_code(Base.decode32!(secret)))
      refute Accounts.totp_enabled?(user)
      assert LuaNox.Repo.all(LuaNox.Accounts.UserRecoveryCode) == []
    end

    test "disable_totp/2 rejects an invalid code" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(Base.decode32!(secret))
      {:ok, user} = Accounts.enable_totp(user, secret, code)

      assert {:error, :invalid_code} = Accounts.disable_totp(user, "000000")
    end

    test "generate_recovery_codes/1 returns 10 unique plaintext codes" do
      user = user_fixture()
      codes = Accounts.generate_recovery_codes(user)

      assert length(codes) == 10
      assert length(Enum.uniq(codes)) == 10
    end

    test "verify_recovery_code/2 is single-use" do
      user = user_fixture()
      [code | _] = Accounts.generate_recovery_codes(user)

      assert {:ok, _} = Accounts.verify_recovery_code(user, code)
      assert {:error, :invalid_code} = Accounts.verify_recovery_code(user, code)
    end

    test "verify_2fa/2 accepts either totp or recovery code" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(Base.decode32!(secret))
      {:ok, user} = Accounts.enable_totp(user, secret, code)

      assert {:ok, _} = Accounts.verify_2fa(user, NimbleTOTP.verification_code(Base.decode32!(secret)))
      assert {:error, :invalid_code} = Accounts.verify_2fa(user, "000000")

      [recovery | _] = Accounts.generate_recovery_codes(user)
      assert {:ok, _} = Accounts.verify_2fa(user, recovery)
    end
  end
end
