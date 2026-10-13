defmodule Luxpkgs.Accounts.TOTP do
  import Ecto.Query

  alias Luxpkgs.Repo
  alias Luxpkgs.Accounts.TotpSecret
  alias Luxpkgs.Accounts.TotpBackupCode
  alias Luxpkgs.Accounts.User

  @period 30
  @backup_code_count 10
  @backup_code_length 10
  @backup_code_alphabet "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

  def enable(%User{} = user, secret \\ NimbleTOTP.secret()) do
    %TotpSecret{}
    |> TotpSecret.changeset(%{secret: secret, user_id: user.id})
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :user_id)
    |> case do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  def disable(%User{id: user_id}) do
    Repo.delete_all(from c in TotpBackupCode, where: c.user_id == ^user_id)
    Repo.delete_all(from t in TotpSecret, where: t.user_id == ^user_id)
    :ok
  end

  def secret(%User{} = user) do
    case Repo.get_by(TotpSecret, user_id: user.id) do
      %TotpSecret{secret: secret} -> secret
      nil -> nil
    end
  end

  def verify(%User{} = user, code, opts \\ []) do
    case Repo.get_by(TotpSecret, user_id: user.id) do
      %TotpSecret{secret: secret, last_used_step: last_used_step} ->
        case verify_secret_with_time(secret, code, last_used_step, opts) do
          {:ok, step} ->
            mark_used(user, step)
            :ok

          :error ->
            verify_backup_code(user, code)
        end

      nil ->
        :error
    end
  end

  def valid?(secret, code, opts \\ []) do
    match?({:ok, _}, verify_secret_with_time(secret, code, nil, opts))
  end

  def uri(%User{} = user, secret) do
    NimbleTOTP.otpauth_uri("Luxpkgs:#{user.username}", secret, issuer: "Luxpkgs")
  end

  def generate_backup_codes(%User{id: user_id}) do
    Repo.delete_all(from c in TotpBackupCode, where: c.user_id == ^user_id)

    codes = Enum.map(1..@backup_code_count, fn _ -> random_backup_code() end)
    now = DateTime.utc_now(:second)

    Repo.insert_all(
      TotpBackupCode,
      Enum.map(codes, fn code ->
        %{
          user_id: user_id,
          code_hash: Bcrypt.hash_pwd_salt(code),
          inserted_at: now,
          updated_at: now
        }
      end)
    )

    codes
  end

  def backup_codes_remaining(%User{id: user_id}) do
    Repo.one(from c in TotpBackupCode, where: c.user_id == ^user_id, select: count(c.id))
  end

  def format_backup_code(code) do
    {left, right} = String.split_at(normalize(code), 5)
    "#{left}-#{right}"
  end

  defp verify_backup_code(user, code) do
    if backup_code?(code) do
      normalized = normalize(code)

      from(c in TotpBackupCode, where: c.user_id == ^user.id)
      |> Repo.all()
      |> Enum.find(fn c -> Bcrypt.verify_pass(normalized, c.code_hash) end)
      |> case do
        nil ->
          :error

        %TotpBackupCode{id: id} ->
          case Repo.delete_all(from c in TotpBackupCode, where: c.id == ^id) do
            {1, _} -> :ok
            _ -> :error
          end
      end
    else
      :error
    end
  end

  defp backup_code?(code) when is_binary(code),
    do: String.length(normalize(code)) == @backup_code_length

  defp backup_code?(_), do: false

  defp normalize(code) when is_binary(code) do
    code |> String.replace(~r/[^A-Za-z0-9]/, "") |> String.upcase()
  end

  defp normalize(_), do: ""

  defp random_backup_code do
    for <<byte <- :crypto.strong_rand_bytes(@backup_code_length)>>, into: "" do
      <<:binary.at(@backup_code_alphabet, rem(byte, 32))>>
    end
  end

  defp verify_secret_with_time(secret, code, last_used_step, opts) do
    now = Keyword.get(opts, :time, System.os_time(:second))
    since = last_used_step && last_used_step * @period

    Enum.find_value([now - @period, now, now + @period], :error, fn time ->
      if NimbleTOTP.valid?(secret, code, time: time, since: since) do
        {:ok, Integer.floor_div(time, @period)}
      end
    end)
  end

  defp mark_used(%User{id: user_id}, step) do
    from(t in TotpSecret, where: t.user_id == ^user_id)
    |> Repo.update_all(set: [last_used_step: step])
  end
end
