public class AccountExtension extends AbstractExtension
{
  private class AccountCreationTask implements Runnable
  {
    private final User _sfsUser;
    private final String _cmd;
    private final String[] _params;

    public AccountCreationTask(User sfsUser, String cmd, String[] params)
    {
      _sfsUser = sfsUser;
      _cmd = cmd;
      _params = params;
    }

    public void run()
    {
      if (_cmd.equals("la"))
      {
        handleLoginAvailable(_sfsUser, _params);
      }
      else if (_cmd.equals("lc"))
      {
        handleLoginCreate(_sfsUser, _params);
      }
      else
      {
        ExtensionUtility.debugTrace("WARNING: unsupported cmd put in ExtensionCommandQueue: "+_cmd, 0, CLASS_NAME);
      }
    }
  }
}
