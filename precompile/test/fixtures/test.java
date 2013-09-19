package com.sbi;
import com.sbi.jmx.SbiManagementAgent;

/**
 * handles creating new accounts
 *
 */
public class AccountExtension extends AbstractExtension
{
  private static final String CLASS_NAME = AccountExtension.class.getName();
  private static final int ACCOUNT_CREATION_THREAD_POOL_SIZE = 2;

  /**
  * Initialization point:
  *
  * This method is called as soon as the extension
  * is loaded in the server.
  */
  @Override
  public void init(A a, B b, C[] c)
  {
    ExtensionUtility.debugTrace("init()", 3, CLASS_NAME);
    SbiAbstractHandler.accountExt = this;
    OneExtensionToRuleThemAll e = SbiAbstractHandler.ext;
    // init all handlers to pre-existing handlers from world zone IN THIS ORDER
    SbiManagementAgent.init();
  }
}
