public class AccountExtension extends AbstractExtension
{
  public void a() {
    // any password policy enforcement goes here
    if (password.length() < SbiConstants.MIN_PASSWORD_LEN)  // TODO: auto-sync password policy with SGE?
      return SbiConstants.MSG_ID_PASSWORD_INVALID;
  }
}
