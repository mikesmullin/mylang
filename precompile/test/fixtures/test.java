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
 * @author darren.healey
 *
 */
public class AccountExtension extends AbstractExtension
{
	private static final String CLASS_NAME = AccountExtension.class.getName();
	private static final int ACCOUNT_CREATION_THREAD_POOL_SIZE = 2;
	
	private boolean _isDestroyed = false;
	private ExtensionHelper _sfsExtHelper;
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
	public void init()
	{
		ExtensionUtility.debugTrace("init()", 3, CLASS_NAME);
		
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
	
	
	/**
	* This method is called by the server when an extension
	* is being removed / destroyed.
	* 
	* Always make sure to release resources like setInterval(s)
	* open files etc in this method.
	* 
	* WARNING:  Since this extension is not the "owner" of shared handler objects, do not call destroy() on them from this extension!
	*/
	@Override
	public void destroy()
	{
		if (!_isDestroyed)
		{
			// set this to true ASAP to prevent multiple threads from executing this block
			// and to keep the extension from processing commands after destroy() is called
			_isDestroyed = true;
			
			SbiManagementAgent.destroy();
			_accountCreationThreadPool.shutdown();
			
			_sfsExtHelper = null;
			_dbLogger = null;
			_threadTracker = null;
			_defDAO = null;
			_userDbDAO = null;
			_defHandler = null;
			_roomListHandler = null;
			
			ExtensionUtility.debugTrace("Extension destroyed", 3, CLASS_NAME);
		}
	}
	
	/**
	 * Handle Client Requests in XML format
	 * 
	 * @param cmd		the command name
	 * @param ao		the actionscript object with the request params
	 * @param u			the user who sent the request
	 * @param fromRoom	the roomId where the request was generated
	 */
	@Override
	public void handleRequest(String cmd, ActionscriptObject incomingData, User u, int fromRoom)
	{
		if (_isDestroyed)
			return;
		ExtensionUtility.debugTrace("handleRequest(XML):  not implemented: cmd="+cmd+" ip="+u.getIpAddress(), 1, CLASS_NAME);
	}
	
	/**
	 * Handle Client Requests in String format
	 * 
	 * @param cmd		the command name
	 * @param params	an array of String parameters
	 * @param u			the user who sent the request
	 * @param fromRoom	the roomId where the request was generated
	 */
	@Override
	public void handleRequest(String cmd, String params[], User u, int fromRoom)
	{
		if (_isDestroyed)
			return;
		
//		// *** START MB_DETECT_SCAFFOLDING
//		if (_sbiConfig.getTier().equals("dev"))
//		{
//			int[] firstMbChar = ExtensionUtility.detectMultiByteChar(params);
//			if (firstMbChar != null)
//			{
//				ExtensionUtility.debugTrace("WARNING: detected a multi-byte character: userName="+u.getName()+" ip="+u.getIpAddress()+" cmd="+cmd+" paramIdx="+firstMbChar[0]+" param="+params[firstMbChar[0]]+" position="+firstMbChar[1], 0, CLASS_NAME);
//			}
//		}
//		// *** END MB_DETECT_SCAFFOLDING
		
		++_healthPingRequestCount;
		
		ExtensionUtility.debugTrace("handleRequest(String) command=" + cmd, 3, CLASS_NAME);
		ThreadInfo info = _threadTracker.start("a."+cmd, SbiConstants.METRIC_TYPE_REQUEST_IN);
		try
		{
			if (cmd.equals("rs"))
			{
				_roomListHandler.handleBestShardsList(u, params);
			}
			else if (cmd.equals("rm"))
			{
				_roomListHandler.handleAllShardsList(u, params);
			}
			else if (cmd.equals("la") || cmd.equals("lc"))  // Login Available / Login Create
			{
				_accountCreationThreadPool.add(new AccountCreationTask(u, cmd, params));  // immediately add task to thread pool
			}
			else if( cmd.equals("gl") )
			{
				_defHandler.handleGenericList(u, new String[]{params[0], Integer.toString(SbiConstants.LOCALIZATION_LANG_ENG)});
			}
			else if( cmd.equals("ka") )
			{
				//ExtensionUtility.debugTrace("Keep alive for user:"+u.getName(), 5, CLASS_NAME);
				// fromRoom -2 means this "ka" ext command is from ServerNodeDAO checkHandlerThreads() test
				if( fromRoom == -2 )
				{
					ExtensionUtility.debugTrace("checkHandlerThreads AccountExtension keep alive confirmed u:"+u.getName()+" t:"+Thread.currentThread().getName(), 1, CLASS_NAME);
					ServerNodeDAO.setKeepAliveAccountThreadCheck();
				}
				return;  // no response necessary, don't track in metrics
			}
			else
			{
				ExtensionUtility.debugTrace("WARNING: Ignoring unrecognized STR request cmd:"+cmd+" from user:"+u.getName()+" ip="+u.getIpAddress(), 1, CLASS_NAME);
				return;
			}
			
			_dbLogger.addMetric(SbiConstants.METRIC_TYPE_REQUEST_IN, cmd, info.startTime);
		}
		catch (Exception e)
		{
			e.printStackTrace();
		}
		finally
		{
			_threadTracker.finish();
		}
	}
	
	/**
	 * Handle Client Requests in JSON format
	 * TODO: put a throttle on this and track people that grab this data over and over again so we can mark them as bad clients
	 * 
	 * @param cmd		the command name
	 * @param params	a JSONObject with the request parameters
	 * @param u			the user who sent the request
	 * @param fromRoom	the roomId where the request was generated
	 */
	@Override
	public void handleRequest(String cmd, JSONObject incomingData, User u, int fromRoom)
	{
		if (_isDestroyed)
			return;
		ExtensionUtility.debugTrace("handleRequest(JSON):  not implemented: cmd="+cmd+" ip="+u.getIpAddress(), 1, CLASS_NAME);
	}
	
	/**
	 * Handle Internal Server Events
	 * 
	 * @param ieo		the event object
	 */
	@Override
	public void handleInternalEvent(InternalEventObject ieo)
	{
		if (_isDestroyed)
			return;
		
		++_healthPingInternalEventCount;
		
		String eventName = ieo.getEventName();
		ExtensionUtility.debugTrace("handleInternalEvent=" + eventName, 4, CLASS_NAME);
		
		try
		{
//			if (eventName.equals("userJoin"))
//			{
//				dbLogger.incrementCCU(SbiConstants.ZONE_TYPE_ACCOUNT);
//			}
//			else if (eventName.equals("userLost") || eventName.equals("logOut"))
//			{
//				dbLogger.decrementCCU(SbiConstants.ZONE_TYPE_ACCOUNT);
//			}
		}
		catch(Exception e)
		{
			ExtensionUtility.debugTrace("ERROR: Caught unhandled exception during handleInternalEvent!", 1, CLASS_NAME);
			e.printStackTrace();
		}
	}
	
	public int getNumPendingAccountCreationTasks()
	{
		return _accountCreationThreadPool.getQueueSize();
	}
	
	public int resetAndGetRequestCount()
	{
		int rc = _healthPingRequestCount;
		_healthPingRequestCount = 0;
		return rc;
	}
	
	public int resetAndGetInternalEventCount()
	{
		int iec = _healthPingInternalEventCount;
		_healthPingInternalEventCount = 0;
		return iec;
	}
	
	/**
	 * Handles a request to check if a given account or avatar name is available
	 * @param sfsUser
	 * @param params
	 */
	private void handleLoginAvailable(User sfsUser, String[] params)
	{
		int checkType = Integer.parseInt(params[0]);
		String checkVal = params[1];
		String[] response;
		int returnId = SbiConstants.MSG_ID_LOGIN_INVALID;
		
		if( checkType == 0 && !checkVal.matches(".*\\W.*") )
		{
			if( _userDbDAO == null )  // server shutting down
			{
				sendResponse(new String[]{"la", Integer.toString(returnId)}, -1, null, ExtensionUtility.getSingleChannelListBySfsUser(sfsUser));
				return;
			}
			returnId = _userDbDAO.getAccountAvailability(checkVal, null, null, false, false);
		}
		else if( checkType == 1 && checkVal.matches("^[A-Za-z0-9 ]+$") )
		{
			// all possible avatar names will be checked elsewhere
			returnId = SbiConstants.MSG_ID_SUCCESS;
		}
		else if( checkType == 2)
		{
			returnId = SbiConstants.MSG_ID_USERNAME_UNAVAILABLE;
		}
		//ExtensionUtility.debugTrace("handleLoginAvailable returnId="+returnId, 5, CLASS_NAME);
		if( returnId == SbiConstants.MSG_ID_USERNAME_UNAVAILABLE )
		{
			final int NUM_SUGGESTED_NAMES = 4;
			final int PADDED_SUGGESTED_CHARS = 5;  // if you change this, also change the format string and constant next to Math.random() below
			String[] sugNames = new String[NUM_SUGGESTED_NAMES];
			int sugNamesDone = 0;
			
			if( checkVal.length() > SbiConstants.MAX_CHARS_PER_NEW_USERNAME-PADDED_SUGGESTED_CHARS )
			{
				checkVal = checkVal.substring(0,checkVal.length()-PADDED_SUGGESTED_CHARS);
			}
			
			// TODO: come up with better solution here - name synonyms, word boundaries, avoid random collision
			int limitSuggestions = 10;
			nextSugName:
			while(sugNamesDone < NUM_SUGGESTED_NAMES)
			{
				if( --limitSuggestions == 0 )
					break;
				
				String newName = checkVal.concat(String.format("%05d", (int)(Math.random()*99999)));
				
				for(int ni=0; ni<sugNamesDone; ++ni)
				{
					if( newName.equals(sugNames[ni]) )
						continue nextSugName;  // jump to outer while loop without incrementing sugNamesDone 
				}
				
				if( _userDbDAO == null )  // server shutting down
				{
					sendResponse(new String[]{"la", Integer.toString(returnId)}, -1, null, ExtensionUtility.getSingleChannelListBySfsUser(sfsUser));
					return;
				}
				if( _userDbDAO.getAccountAvailability(newName, null, null, false, false) != SbiConstants.MSG_ID_SUCCESS )
					continue;
				
				sugNames[sugNamesDone++] = newName;
			}
			while( sugNamesDone < NUM_SUGGESTED_NAMES )
			{
				sugNames[sugNamesDone++] = "";
			}
			
			response = new String[]{"la", Integer.toString(returnId), sugNames[0], sugNames[1], sugNames[2], sugNames[3]};
		}
		else
		{
			response = new String[]{"la", Integer.toString(returnId)};
		}
		
		sendResponse(response, -1, null, ExtensionUtility.getSingleChannelListBySfsUser(sfsUser));
	}
	
	/**
	 * Handles a LoginCreate "lc" request (create account)
	 * @param sfsUser
	 * @param params
	 */
	private void handleLoginCreate(User sfsUser, String[] params)
	{
		int statusId = 0;  // failure response for "unknown" system error
		try
		{
			statusId = validateLoginCreateParams(params, sfsUser);
			if (statusId == SbiConstants.MSG_ID_SUCCESS)
			{
				statusId = _userDbDAO.createNewUserAndAvatar(params, sfsUser.getIpAddress());  // TODO: get bluebox ip here instead if applicable
			}
		}
		catch (Exception e)  // problem parsing params, decrypting password, etc.
		{
			e.printStackTrace();
		}
		
		// send response
		String[] response = {
				"lc",
				Integer.toString(statusId)};
		sendResponse(response, -1, null, ExtensionUtility.getSingleChannelListBySfsUser(sfsUser));
	}
	
	/**
	 * Validates incoming params for "lc" (does not include checking database or CS2 filter)
	 * @param params
	 * @param sfsUser
	 * @return SbiConstants.MSG_ID_SUCCESS on success (see SbiContants.MSG_ID_*)
	 * @throws Exception on failure to parse params or decrypting password
	 */
	private int validateLoginCreateParams(String[] params, User sfsUser) throws Exception
	{
		String userName = params[0];
		String emailAddress = params[1];
		String password = params[2];  // encrypted
		int gender = Integer.parseInt(params[4]);
		int avatarDefId = Integer.parseInt(params[10]);
		String avatarError = null;
		
		// validate avatarDefId
		AvatarDef avatarDef = _defDAO.getAvatarDef(avatarDefId);
		if (avatarDef == null)
		{
			avatarError = "avatar invalid";
		}
		else if (!_defDAO.getAvatarDefIsEnviroType(avatarDef, SbiConstants.ENVIRO_TYPE_LAND))
		{
			avatarError = "avatar not usable on land";
		}
		else if (avatarDef.membersOnly)
		{
			avatarError = "avatar is membersOnly";
		}
		else if (!_defDAO.getAvatarDefIsViewable(avatarDef.id, SbiConstants.UV_DEF_AVT_VIEWABLE_FLAG))  // test against default viewable flag value 
		{
			avatarError = "avatar not viewable";
		}
		
		// if error validating avatarDefId, use a random avatar and log
		if (avatarError != null)
		{
			avatarDef = _defDAO.getRandomAccountCreationAvatarDef();
			params[10] = Integer.toString(avatarDef.id);
			ExtensionUtility.debugTrace(
					"WARNING: validateLoginCreateParams: "+avatarError+
					": badAvatarDefId="+avatarDefId+
					" newAvatarDefId="+avatarDef.id+
					" emailAddress="+
					emailAddress+
					" clientIp="+sfsUser.getIpAddress(),
				0, CLASS_NAME);
		}
		
		if (gender < 0 || gender > 1)
		{
			ExtensionUtility.debugTrace("createNewUser bad gender="+gender, 5, CLASS_NAME);
			return SbiConstants.MSG_ID_LOGIN_INVALID;  // hacked client
		}
		
		if (userName.length() == 0)
		{
			return SbiConstants.MSG_ID_USERNAME_MISSING;
		}
		if( userName.matches("^[a-zA-Z0-9].*\\p{javaUpperCase}+.*") && !userName.startsWith("sbiAutoLoginCBt") )
		{
			ExtensionUtility.debugTrace("createNewUser bad characters userName="+userName, 5, CLASS_NAME);
			return SbiConstants.MSG_ID_LOGIN_INVALID;  // hacked client
		}
		if (userName.length() > SbiConstants.MAX_CHARS_PER_USERNAME)
		{
			ExtensionUtility.debugTrace("createNewUser bad length userName="+userName, 5, CLASS_NAME);
			return SbiConstants.MSG_ID_LOGIN_INVALID;
		}
		if (userName.matches(".*\\W.*"))
		{
			ExtensionUtility.debugTrace("createNewUser bad userName="+userName, 5, CLASS_NAME);
			return SbiConstants.MSG_ID_LOGIN_INVALID;
		}
		
		if (emailAddress.length() == 0)
		{
			return SbiConstants.MSG_ID_EMAIL_MISSING;
		}
		if (!emailAddress.matches("\\A([^;:,\\(\\)\\[\\]@\\s]+)@((?:[-a-z0-9]+\\.)+[a-z]{2,})\\Z"))//"\\A([^@\\s]+)@((?:[-a-z0-9]+\\.)+[a-z]{2,})\\Z"))
		{
			return SbiConstants.MSG_ID_EMAIL_INVALID;
		}
		
		if (password.length() == 0)
		{
			return SbiConstants.MSG_ID_PASSWORD_MISSING;
		}
		
		// unencrypt password
		password = Crypto.clientDecrypt(password, _sfsExtHelper.getSecretKey(sfsUser.getChannel()));
		//ExtensionUtility.debugTrace("encryptedPassword="+params[2]+" password="+password, 1, CLASS_NAME);
		params[2] = password;  // replace encrypted password in params with decrypted password
		
		// any password policy enforcement goes here
		if (password.length() < SbiConstants.MIN_PASSWORD_LEN)  // TODO: auto-sync password policy with SGE?
		{
			return SbiConstants.MSG_ID_PASSWORD_INVALID;
		}
		
		if (!userName.startsWith("sbiAutoLogin") && StringUtils.indexOfIgnoreCase(password, userName) >= 0)
		{
			return SbiConstants.MSG_ID_PASSWORD_HAS_USERNAME;
		}
		
		return SbiConstants.MSG_ID_SUCCESS;
	}
	
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
