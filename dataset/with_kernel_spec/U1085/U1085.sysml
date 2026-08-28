package 'Home Server System' {
	private import ScalarValues::Integer;
	private import ScalarValues::Real;
	private import ScalarValues::String;
	private import ScalarValues::Boolean;
	private import SI::*;

	attribute def DataCapacity :> Real;
	attribute def DataRate :> Real;
	attribute def Duration :> Real;
	attribute def PowerConsumption :> Real;

	item def Credentials {
		attribute username : String = "";
		attribute password : String = "";
	}

	item def AuthToken {
		attribute valid : Boolean = true;
		attribute userId : String = "";
	}

	item def Request;

	item def FileRequest :> Request {
		attribute filePath : String = "";
	}

	item def MediaStreamRequest :> Request {
		attribute mediaId : String = "";
		attribute mediaType : String = "";
	}

	item def FileData {
		attribute payload : String = "";
		attribute size : DataCapacity = 0.0;
	}

	item def MediaStream {
		attribute streamId : String = "";
		attribute mediaType : String = "";
	}

	item def BackupCommand {
		attribute backupType : String = "incremental";
	}

	item def BackupStatus {
		attribute status : String = "completed";
		attribute timestamp : String = "";
	}

	item def PowerCommand {
		attribute command : String = "";
	}

	item def PowerStatus {
		attribute status : String = "";
	}

	port def NetworkPort {
		in item request : Request;
		in item credentials : Credentials;
		out item fileData : FileData;
		out item mediaStream : MediaStream;
	}

	port def StoragePort {
		in item fileReq : FileRequest;
		out item fileData : FileData;
		in item backupCmd : BackupCommand;
		out item backupStatus : BackupStatus;
	}

	port def MediaPort {
		in item mediaReq : MediaStreamRequest;
		out item mediaStream : MediaStream;
	}

	port def AuthPort {
		in item credentials : Credentials;
		out item authToken : AuthToken;
	}

	port def BackupPort {
		in item backupCmd : BackupCommand;
		out item backupStatus : BackupStatus;
	}

	port def PowerPort {
		in item powerCmd : PowerCommand;
		out item powerStatus : PowerStatus;
	}

	part def ProcessingUnit {
		attribute numCores : Integer = 4;

		port networkPort : NetworkPort;
		port storagePort : StoragePort;
		port mediaPort : MediaPort;
		port authPort : AuthPort;
		port backupPort : BackupPort;
		port powerPort : PowerPort;

		state ProcessingUnitBehavior {
			entry; then idle;

			state idle;
			accept req : FileRequest via networkPort
				then authForFile;
			accept req : MediaStreamRequest via networkPort
				then authForMedia;

			state authForFile;
			accept token : AuthToken via authPort
				if token.valid
				do send new FileRequest() to storagePort
				then servingFile;
			accept token : AuthToken via authPort
				if !token.valid
				then idle;

			state authForMedia;
			accept token : AuthToken via authPort
				if token.valid
				do send new MediaStreamRequest() to mediaPort
				then streamingMedia;
			accept token : AuthToken via authPort
				if !token.valid
				then idle;

			state servingFile;
			accept data : FileData via storagePort
				do send data to networkPort
				then idle;

			state streamingMedia;
			accept stream : MediaStream via mediaPort
				do send stream to networkPort
				then idle;
		}
	}

	part def StorageSubsystem {
		attribute capacity : DataCapacity = 4.0;
		attribute raidLevel : String = "RAID 5";
		attribute usedSpace : DataCapacity = 0.0;

		port storagePort : StoragePort;
		port backupPort : BackupPort;

		state StorageBehavior {
			entry; then ready;

			state ready;
			accept fileReq : FileRequest via storagePort
				then reading;
			accept backupCmd : BackupCommand via backupPort
				then backingUp;

			state reading;
			accept after 2 [SI::s]
				do send new FileData() to storagePort
				then ready;

			state backingUp;
			accept after 10 [SI::s]
				do send new BackupStatus() to backupPort
				then ready;
		}
	}

	part def NetworkInterface {
		attribute bandwidth : DataRate = 1.0;
		attribute macAddress : String = "00:00:00:00:00:00";

		port externalPort : NetworkPort;
		port internalPort : NetworkPort;

		state NetworkBehavior {
			entry; then connected;

			state connected;
			accept req : Request via externalPort
				do send req to internalPort
				then connected;
			accept cred : Credentials via externalPort
				do send cred to internalPort
				then connected;
			accept data : FileData via internalPort
				do send data to externalPort
				then connected;
			accept stream : MediaStream via internalPort
				do send stream to externalPort
				then connected;
		}
	}

	part def MediaServerModule {
		attribute maxStreams : Integer = 5;
		attribute activeStreams : Integer = 0;

		port mediaPort : MediaPort;
		port storagePort : StoragePort;

		state MediaBehavior {
			entry; then idle;

			state idle;
			accept mediaReq : MediaStreamRequest via mediaPort
				if activeStreams < maxStreams
				then streaming;

			state streaming;
			accept after 1 [SI::s]
				do send new MediaStream() to mediaPort
				then idle;
		}
	}

	part def BackupManager {
		attribute retentionDays : Integer = 30;
		attribute lastBackupTime : String = "";

		port backupPort : BackupPort;
		port storagePort : BackupPort;

		state BackupBehavior {
			entry; then idle;

			state idle;
			accept backupCmd : BackupCommand via backupPort
				then performing;
			accept after 24 [SI::h]
				then performing;

			state performing;
			accept after 30 [SI::min]
				do send new BackupStatus() to backupPort
				then idle;
		}
	}

	part def AuthenticationService {
		attribute maxUsers : Integer = 10;
		attribute activeUsers : Integer = 0;

		port authPort : AuthPort;

		state AuthBehavior {
			entry; then idle;

			state idle;
			accept cred : Credentials via authPort
				then verifying;

			state verifying;
			accept after 0.5 [SI::s]
				do send new AuthToken() to authPort
				then idle;
		}
	}

	part def PowerManagement {
		attribute activePower : PowerConsumption = 15.0;
		attribute idlePower : PowerConsumption = 5.0;
		attribute currentPower : PowerConsumption = 5.0;

		port powerPort : PowerPort;

		state PowerBehavior {
			entry; then active;

			state active;
			accept powerCmd : PowerCommand via powerPort
				if powerCmd.command == "sleep"
				then sleeping;

			state sleeping;
			accept powerCmd : PowerCommand via powerPort
				if powerCmd.command == "wake"
				then active;
		}
	}

	part def HomeServer {
		part processingUnit : ProcessingUnit;
		part storage : StorageSubsystem;
		part network : NetworkInterface;
		part mediaServer : MediaServerModule;
		part backupManager : BackupManager;
		part authService : AuthenticationService;
		part powerMgmt : PowerManagement;

		connect network.internalPort to processingUnit.networkPort;
		connect processingUnit.storagePort to storage.storagePort;
		connect processingUnit.mediaPort to mediaServer.mediaPort;
		connect processingUnit.authPort to authService.authPort;
		connect processingUnit.backupPort to backupManager.backupPort;
		connect processingUnit.powerPort to powerMgmt.powerPort;
		connect mediaServer.storagePort to storage.storagePort;
		connect backupManager.storagePort to storage.backupPort;
	}

	requirement uptimeReq {
		doc /* The system shall maintain at least 99.5% uptime. */
		attribute minUptime : Real = 99.5;
	}

	requirement responseTimeReq {
		doc /* The system shall provide fast user response times under 2 seconds. */
		attribute maxResponseTime : Duration = 2.0;
	}

	requirement storageCapacityReq {
		doc /* The storage subsystem shall provide at least 4TB of capacity with RAID 5. */
		attribute minCapacity : DataCapacity = 4.0;
		attribute raidLevel : String = "RAID 5";
	}

	requirement backupRetentionReq {
		doc /* The backup manager shall retain backups for a 30-day period. */
		attribute retentionDays : Integer = 30;
	}

	requirement userCapacityReq {
		doc /* The authentication service shall support up to 10 users. */
		attribute maxUsers : Integer = 10;
	}

	requirement mediaStreamingReq {
		doc /* The media server shall support up to 5 simultaneous streams. */
		attribute maxStreams : Integer = 5;
	}

	requirement processingCoreReq {
		doc /* The processing unit shall have at least 4 cores. */
		attribute minCores : Integer = 4;
	}

	part homeServer : HomeServer;

	satisfy uptimeReq by homeServer;
	satisfy responseTimeReq by homeServer;
	satisfy storageCapacityReq by homeServer.storage;
	satisfy backupRetentionReq by homeServer.backupManager;
	satisfy userCapacityReq by homeServer.authService;
	satisfy mediaStreamingReq by homeServer.mediaServer;
	satisfy processingCoreReq by homeServer.processingUnit;
}
