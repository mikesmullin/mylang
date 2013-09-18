package com.sbi;
import com.mysql.jdbc.StringUtils;

/**
 * handles creating new accounts
 *
 */
public class AccountExtension extends AbstractExtension
{
  private static final String CLASS_NAME = AccountExtension.class.getName();
  private static final int ACCOUNT_CREATION_THREAD_POOL_SIZE = 2;
  private boolean _isDestroyed = false;
  private ExtensionHelper _sfsExtHelper;

  /**
  * Initialization point:
  *
  * This method is called as soon as the extension
  * is loaded in the server.
  */
  @Override
  public void init()
  {
    ExtensionUtility.debugTrace("init()", 3, CLASS_NAME);
    SbiManagementAgent.init();
    _sfsExtHelper = ExtensionHelper.instance();

    // init all handlers to pre-existing handlers from world zone IN THIS ORDER
    OneExtensionToRuleThemAll e = SbiAbstractHandler.ext;
    _dbLogger.initAccountZone(_sfsExtHelper.getZone(SbiConstants.ACCOUNT_ZONE_NAME));
    _accountCreationThreadPool = new FixedThreadPool(ACCOUNT_CREATION_THREAD_POOL_SIZE, "AccountCreationThreadPool");
    _healthPingRequestCount = 0;
  }
}
