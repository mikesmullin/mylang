package com.sbi;

import it.gotoandplay.smartfoxserver.data.User;
import it.gotoandplay.smartfoxserver.events.InternalEventObject;
import it.gotoandplay.smartfoxserver.extensions.AbstractExtension;
import it.gotoandplay.smartfoxserver.extensions.ExtensionHelper;
import it.gotoandplay.smartfoxserver.lib.ActionscriptObject;

import org.json.JSONObject;

import com.mysql.jdbc.StringUtils;
import com.sbi.dao.DbDAOManager;
import com.sbi.dao.DefDAO;
import com.sbi.dao.ServerNodeDAO;
import com.sbi.dao.UserDbDAO;
import com.sbi.db.logging.DatabaseLoggerManager;
import com.sbi.edo.AvatarDef;
import com.sbi.edo.ThreadInfo;
import com.sbi.jmx.SbiManagementAgent;
import com.sbi.util.Crypto;
import com.sbi.util.ExtensionUtility;
import com.sbi.util.FixedThreadPool;
import com.sbi.util.ThreadTracker;

/**
 * handles creating new accounts
 *
 */
public class AccountExtension extends AbstractExtension
{
  private static final String CLASS_NAME = AccountExtension.class.getName();
  private static final int ACCOUNT_CREATION_THREAD_POOL_SIZE = 2;

  private boolean _isDestroyed = false;
  private static ExtensionHelper _sfsExtHelper;
  private DatabaseLoggerManager _dbLogger;
  private ThreadTracker _threadTracker;
  private DefDAO _defDAO;
  private UserDbDAO _userDbDAO;
  private DefHandler _defHandler;
  private RoomListHandler _roomListHandler;
  private FixedThreadPool _accountCreationThreadPool;

  private int _healthPingRequestCount;
  private int _healthPingInternalEventCount;


  /**
  * Initialization point:
  *
  * This method is called as soon as the extension
  * is loaded in the server.
  */
  @Override
  public static void init()
  {
    ExtensionUtility.debugTrace("init()", 3, CLASS_NAME);

    if (1==1)
      SbiManagementAgent.init();

    _sfsExtHelper = ExtensionHelper.instance();
    _dbLogger = DatabaseLoggerManager.getInstance();
    _threadTracker = ThreadTracker.getInstance();
    _defDAO = DbDAOManager.getDefDAO();
    _userDbDAO = DbDAOManager.getUserDbDAO();

    // init all handlers to pre-existing handlers from world zone IN THIS ORDER
    SbiAbstractHandler.accountExt = this;
    OneExtensionToRuleThemAll e = SbiAbstractHandler.ext;
    _defHandler = e.defHandler;
    _roomListHandler = e.roomListHandler;
    //e.setAccountExtAndStartHealthPing(this);

    // tell other classes about this extension
    _dbLogger.initAccountZone(_sfsExtHelper.getZone(SbiConstants.ACCOUNT_ZONE_NAME));

    // create thread pool for account creation tasks
    _accountCreationThreadPool = new FixedThreadPool(ACCOUNT_CREATION_THREAD_POOL_SIZE, "AccountCreationThreadPool");

    _healthPingRequestCount = 0;
    _healthPingInternalEventCount = 0;
  }
}
