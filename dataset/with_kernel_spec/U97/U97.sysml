package AutonomousEdgeSensorNode {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def DataPacket;

		attribute def ConnectionLost;
		attribute def ConnectionRestored;
		attribute def BatteryLow;
		attribute def BatteryNormal;
		attribute def ReconnectSuccess;
		attribute def ReconnectFailed;
		attribute def SyncComplete;

		attribute def BatteryLevel :> Real;
		attribute def CPUUsage :> Real;
		attribute def MemoryUsage :> Real;
		attribute def Temperature :> TemperatureValue;
		attribute def BackoffTime :> TimeValue;
		attribute def PacketCount :> Integer;

		port def NetworkPort {
			in item incomingData : DataPacket[*];
			out item outgoingData : DataPacket[*];
			attribute isConnected : Boolean;
		}

		part def EdgeSensorNode {
			port networkPort : NetworkPort;

			part sensor : Sensor;
			part dataStore : DataStore;
			part reconnectionController : ReconnectionController;
			part powerManager : PowerManager;
			part diagnosticMonitor : DiagnosticMonitor;
			part communicationModule : CommunicationModule;

			exhibit state nodeStates : NodeStates;
		}

		part def Sensor {
			out data : DataPacket;
		}

		part def DataStore {
			attribute capacity : PacketCount = 5000;
			attribute currentCount : PacketCount = 0;
			item bufferedPackets : DataPacket[0..*];
		}

		part def ReconnectionController {
			attribute initialBackoff : BackoffTime = 30 [s];
			attribute currentBackoff : BackoffTime = 30 [s];
			exhibit state reconnectionStates : ReconnectionStates;
		}

		part def PowerManager {
			attribute batteryLevel : BatteryLevel;
			attribute lowPowerMode : Boolean = false;
			exhibit state powerStates : PowerStates;
		}

		part def DiagnosticMonitor {
			attribute cpuUsage : CPUUsage;
			attribute memoryUsage : MemoryUsage;
			attribute temperature : Temperature;
			exhibit state diagnosticStates : DiagnosticStates;
		}

		part def CommunicationModule {
			port networkPort : NetworkPort;
			attribute isConnected : Boolean = true;
		}

		part def ParentSystem {
			port networkPort : NetworkPort;
		}

		state def NodeStates;
		state def ReconnectionStates;
		state def PowerStates;
		state def DiagnosticStates;

		action def GatherSensorData { out data : DataPacket; }
		action def StoreData { in data : DataPacket; in store : DataStore; }
		action def GatherAndStoreData {
			in dataStore : DataStore;
			action gather : GatherSensorData { out data; }
			then action store : StoreData {
				in data = gather.data;
				in store = dataStore;
			}
		}
		action def SynchronizeData { in store : DataStore; }
		action def AttemptReconnect { out success : Boolean; }
		action def MonitorBattery { out level : BatteryLevel; }
		action def MonitorDiagnostics { out cpu : CPUUsage; out mem : MemoryUsage; out temp : Temperature; }
		action def EnterLowPowerMode;
		action def ExitLowPowerMode;
		action def IncreaseBackoff;
		action def EnterAutonomousMode;
		action def WaitBackoff;
	}

	package Usages {
		private import Definitions::*;

		part edgeNode : EdgeSensorNode;
		part parentSystem : ParentSystem;

		connect edgeNode.networkPort to parentSystem.networkPort;

		action gatherAndStore : GatherAndStoreData { in dataStore = edgeNode.dataStore; }
		action syncData : SynchronizeData { in store = edgeNode.dataStore; }
		action monitorBattery : MonitorBattery;
		action monitorDiagnostics : MonitorDiagnostics;
		action attemptReconnect : AttemptReconnect;
		action increaseBackoff : IncreaseBackoff;
		action enterLowPower : EnterLowPowerMode;
		action exitLowPower : ExitLowPowerMode;
		action enterAutonomousMode : EnterAutonomousMode;
		action waitBackoff : WaitBackoff;

		state nodeStates : NodeStates parallel {
			state operationalStates {
				entry; then connected;
				state connected {
					do gatherAndStore;
				}
				accept ConnectionLost
					then orphaned;
				state orphaned {
					entry;
					do gatherAndStore;
				}
				accept ConnectionRestored
					then syncing;
				state syncing {
					entry syncData;
				}
				accept SyncComplete
					then connected;
			}

			state reconnectionStates {
				entry; then idle;
				state idle;
				accept ConnectionLost
					then waiting;
				state waiting {
					entry;
					do attemptReconnect;
					accept ReconnectSuccess
						then idle;
					accept ReconnectFailed
						do increaseBackoff
						then waiting;
				}
			}

			state powerStates {
				entry; then normalPower;
				state normalPower {
					do monitorBattery;
				}
				accept when monitorBattery.level < 20
					then lowPower;
				state lowPower {
					entry enterLowPower;
					do monitorBattery;
				}
				accept when monitorBattery.level > 80
					do exitLowPower
					then normalPower;
			}

			state diagnosticStates {
				entry; then monitoring;
				state monitoring {
					do monitorDiagnostics;
				}
			}
		}
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def ResilientOperationRequirement {
			doc /* The node must continue to operate when orphaned, store up to 5000 packets, use exponential backoff for reconnection, manage power, monitor health, and synchronize data upon reconnection. */
			subject node : EdgeSensorNode;
		}

		requirement resilientOperation : ResilientOperationRequirement {
			subject ::> edgeNode;
		}
	}
}
