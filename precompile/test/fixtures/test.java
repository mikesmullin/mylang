public class AccountExtension extends AbstractExtension
{
  public void init()
  {
    _healthPingRequestCount = 0;
  }

  public void destroy()
  {
    if (!_isDestroyed)
    {
      ExtensionUtility.debugTrace("Extension destroyed", 3, CLASS_NAME);
    }
  }
}
