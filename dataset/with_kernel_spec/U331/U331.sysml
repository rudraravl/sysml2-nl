package NurseCallSystem {
	doc
	/* Comprehensive nurse call button system for a healthcare facility. */
	
	private import ScalarValues::*;
	
	attribute def RoomNumber :> Integer;
	attribute def BedNumber :> Integer;
	attribute def Voltage :> Real;
	attribute def Seconds :> Real;
	attribute def Availability :> Real;
	
	item def CallSignal {
		attribute roomNumber : RoomNumber;
		attribute bedNumber : BedNumber;
		attribute issuedAt : Seconds;
	}
	item def AckSignal {
		attribute roomNumber : RoomNumber;
		attribute bedNumber : BedNumber;
		attribute acknowledgedAt : Seconds;
	}
	item def CancelSignal {
		attribute roomNumber : RoomNumber;
		attribute bedNumber : BedNumber;
		attribute cancelledAt : Seconds;
	}
	attribute def LogEntry {
		attribute roomNumber : RoomNumber;
		attribute bedNumber : BedNumber;
		attribute issuedAt : Seconds;
		attribute acknowledgedAt : Seconds[0..1];
		attribute cancelledAt : Seconds[0..1];
	}
	
	occurrence def ButtonPress;
	occurrence def StaffAckRoom101;
	occurrence def StaffAckRoom102;
	occurrence def StaffCancelRoom101;
	occurrence def StaffCancelRoom102;
	
	port def CallOutPort { out item call : CallSignal; }
	port def CallInPort { in item call : CallSignal; }
	port def AckOutPort { out item ack : AckSignal; }
	port def AckInPort { in item ack : AckSignal; }
	port def CancelOutPort { out item cancel : CancelSignal; }
	port def CancelInPort { in item cancel : CancelSignal; }
	
	interface def ButtonToControllerIf {
		end button : CallOutPort;
		end controller : CallInPort;
	}
	interface def ControllerToPanelCallIf {
		end controller : CallOutPort;
		end panel : CallInPort;
	}
	interface def ControllerToStationCallIf {
		end controller : CallOutPort;
		end station : CallInPort;
	}
	interface def StationToControllerAckIf {
		end station : AckOutPort;
		end controller : AckInPort;
	}
	interface def ControllerToPanelAckIf {
		end controller : AckOutPort;
		end panel : AckInPort;
	}
	interface def ControllerToButtonAckIf {
		end controller : AckOutPort;
		end button : AckInPort;
	}
	interface def StationToControllerCancelIf {
		end station : CancelOutPort;
		end controller : CancelInPort;
	}
	interface def ControllerToPanelCancelIf {
		end controller : CancelOutPort;
		end panel : CancelInPort;
	}
	interface def ControllerToButtonCancelIf {
		end controller : CancelOutPort;
		end button : CancelInPort;
	}
	
	part def CallButton {
		attribute roomNumber : RoomNumber;
		attribute bedNumber : BedNumber;
		attribute supplyVoltage : Voltage = 24.0;
		port callOutPort : CallOutPort;
		port ackInPort : AckInPort;
		port cancelInPort : CancelInPort;
		state ButtonState {
			entry; then Idle;
			state Idle;
			state Active;
			state ResponsePending;
			transition
				first Idle
				accept ButtonPress
				do send new CallSignal(roomNumber, bedNumber, 0.0) via callOutPort
				then Active;
			transition
				first Active
				accept a : AckSignal via ackInPort
				do indicateResponse
				then ResponsePending;
			transition
				first ResponsePending
				accept c : CancelSignal via cancelInPort
				then Idle;
			transition
				first Active
				accept c : CancelSignal via cancelInPort
				then Idle;
		}
		action indicateResponse;
	}
	
	part def RoomAlertPanel {
		attribute roomNumber : RoomNumber;
		attribute alarmActive : Boolean = false;
		attribute lightDimmed : Boolean = false;
		attribute measuredActivationTime : Seconds = 1.5;
		port callInPort : CallInPort;
		port ackInPort : AckInPort;
		port cancelInPort : CancelInPort;
		state PanelState {
			entry; then Standby;
			state Standby;
			state Active;
			state Acknowledged;
			transition
				first Standby
				accept c : CallSignal via callInPort
				do activateAlarm
				then Active;
			transition
				first Active
				accept a : AckSignal via ackInPort
				do dimLight
				then Acknowledged;
			transition
				first Acknowledged
				accept c : CancelSignal via cancelInPort
				do deactivate
				then Standby;
			transition
				first Active
				accept c : CancelSignal via cancelInPort
				do deactivate
				then Standby;
		}
		action activateAlarm;
		action dimLight;
		action deactivate;
	}
	
	part def NurseStationConsole {
		attribute consoleId : String;
		attribute callLog : LogEntry[*];
		attribute totalCallCount : Integer = 0;
		port callInPort : CallInPort;
		port ackOutPort101 : AckOutPort;
		port ackOutPort102 : AckOutPort;
		port cancelOutPort101 : CancelOutPort;
		port cancelOutPort102 : CancelOutPort;
		state StationState {
			entry; then Monitoring;
			state Monitoring;
			transition
				first Monitoring
				accept c : CallSignal via callInPort
				do logCall
				then Monitoring;
			transition
				first Monitoring
				accept StaffAckRoom101
				do send new AckSignal(101, 1, 0.0) via ackOutPort101
				then Monitoring;
			transition
				first Monitoring
				accept StaffAckRoom102
				do send new AckSignal(102, 1, 0.0) via ackOutPort102
				then Monitoring;
			transition
				first Monitoring
				accept StaffCancelRoom101
				do send new CancelSignal(101, 1, 0.0) via cancelOutPort101
				then Monitoring;
			transition
				first Monitoring
				accept StaffCancelRoom102
				do send new CancelSignal(102, 1, 0.0) via cancelOutPort102
				then Monitoring;
		}
		action logCall;
	}
	
	part def CommunicationController {
		attribute controllerId : String;
		attribute nominalVoltage : Voltage = 24.0;
		attribute networkAvailability : Availability = 0.9995;
		port callInButton101 : CallInPort;
		port callInButton102 : CallInPort;
		port callOutPanel101 : CallOutPort;
		port callOutPanel102 : CallOutPort;
		port callOutStation : CallOutPort;
		port ackInStation101 : AckInPort;
		port ackInStation102 : AckInPort;
		port ackOutPanel101 : AckOutPort;
		port ackOutPanel102 : AckOutPort;
		port ackOutButton101 : AckOutPort;
		port ackOutButton102 : AckOutPort;
		port cancelInStation101 : CancelInPort;
		port cancelInStation102 : CancelInPort;
		port cancelOutPanel101 : CancelOutPort;
		port cancelOutPanel102 : CancelOutPort;
		port cancelOutButton101 : CancelOutPort;
		port cancelOutButton102 : CancelOutPort;
		state ControllerState {
			entry; then Routing;
			state Routing;
			transition
				first Routing
				accept c : CallSignal via callInButton101
				do action {
					first start;
					then send c via callOutPanel101;
					then send c via callOutStation;
				}
				then Routing;
			transition
				first Routing
				accept c : CallSignal via callInButton102
				do action {
					first start;
					then send c via callOutPanel102;
					then send c via callOutStation;
				}
				then Routing;
			transition
				first Routing
				accept a : AckSignal via ackInStation101
				do action {
					first start;
					then send a via ackOutPanel101;
					then send a via ackOutButton101;
				}
				then Routing;
			transition
				first Routing
				accept a : AckSignal via ackInStation102
				do action {
					first start;
					then send a via ackOutPanel102;
					then send a via ackOutButton102;
				}
				then Routing;
			transition
				first Routing
				accept c : CancelSignal via cancelInStation101
				do action {
					first start;
					then send c via cancelOutPanel101;
					then send c via cancelOutButton101;
				}
				then Routing;
			transition
				first Routing
				accept c : CancelSignal via cancelInStation102
				do action {
					first start;
					then send c via cancelOutPanel102;
					then send c via cancelOutButton102;
				}
				then Routing;
		}
	}
	
	part def Room {
		attribute roomNumber : RoomNumber;
		part callButton : CallButton;
		part alertPanel : RoomAlertPanel;
	}
	
	requirement def RapidAlertActivationReq {
		doc
		/* The room alert panel shall activate within 2 seconds of a button press. */
		attribute maxActivationTime : Seconds = 2.0;
		subject panel : RoomAlertPanel;
		constraint { panel.measuredActivationTime <= maxActivationTime }
	}
	requirement def ContinuousNetworkAvailabilityReq {
		doc
		/* The communication network shall maintain continuous availability. */
		attribute minAvailability : Availability = 0.999;
		subject controller : CommunicationController;
		constraint { controller.networkAvailability >= minAvailability }
	}
	requirement def SafeLowVoltageReq {
		doc
		/* The system shall operate at a safe low voltage. */
		attribute maxVoltage : Voltage = 48.0;
		subject button : CallButton;
		constraint { button.supplyVoltage <= maxVoltage }
	}
	requirement def CallEventLoggingReq {
		doc
		/* All call events shall be logged for quality assurance and record-keeping. */
		subject station : NurseStationConsole;
	}
	
	requirement rapidAlertReq : RapidAlertActivationReq;
	requirement networkAvailabilityReq : ContinuousNetworkAvailabilityReq;
	requirement safeVoltageReq : SafeLowVoltageReq;
	requirement eventLoggingReq : CallEventLoggingReq;
	
	part def HealthcareFacility {
		attribute facilityName : String = "Central General Hospital";
		attribute supplyVoltage : Voltage = 24.0;
		part controller : CommunicationController {
			:>> controllerId = "CC-1";
		}
		part nurseStation : NurseStationConsole {
			:>> consoleId = "NS-1";
		}
		part room101 : Room {
			:>> roomNumber = 101;
			part callButton : CallButton {
				:>> roomNumber = 101;
				:>> bedNumber = 1;
			}
			part alertPanel : RoomAlertPanel {
				:>> roomNumber = 101;
			}
		}
		part room102 : Room {
			:>> roomNumber = 102;
			part callButton : CallButton {
				:>> roomNumber = 102;
				:>> bedNumber = 1;
			}
			part alertPanel : RoomAlertPanel {
				:>> roomNumber = 102;
			}
		}
		interface b2c101 : ButtonToControllerIf connect room101.callButton.callOutPort to controller.callInButton101;
		interface c2pCall101 : ControllerToPanelCallIf connect controller.callOutPanel101 to room101.alertPanel.callInPort;
		interface b2c102 : ButtonToControllerIf connect room102.callButton.callOutPort to controller.callInButton102;
		interface c2pCall102 : ControllerToPanelCallIf connect controller.callOutPanel102 to room102.alertPanel.callInPort;
		interface c2sCall : ControllerToStationCallIf connect controller.callOutStation to nurseStation.callInPort;
		interface s2cAck101 : StationToControllerAckIf connect nurseStation.ackOutPort101 to controller.ackInStation101;
		interface c2pAck101 : ControllerToPanelAckIf connect controller.ackOutPanel101 to room101.alertPanel.ackInPort;
		interface c2bAck101 : ControllerToButtonAckIf connect controller.ackOutButton101 to room101.callButton.ackInPort;
		interface s2cAck102 : StationToControllerAckIf connect nurseStation.ackOutPort102 to controller.ackInStation102;
		interface c2pAck102 : ControllerToPanelAckIf connect controller.ackOutPanel102 to room102.alertPanel.ackInPort;
		interface c2bAck102 : ControllerToButtonAckIf connect controller.ackOutButton102 to room102.callButton.ackInPort;
		interface s2cCancel101 : StationToControllerCancelIf connect nurseStation.cancelOutPort101 to controller.cancelInStation101;
		interface c2pCancel101 : ControllerToPanelCancelIf connect controller.cancelOutPanel101 to room101.alertPanel.cancelInPort;
		interface c2bCancel101 : ControllerToButtonCancelIf connect controller.cancelOutButton101 to room101.callButton.cancelInPort;
		interface s2cCancel102 : StationToControllerCancelIf connect nurseStation.cancelOutPort102 to controller.cancelInStation102;
		interface c2pCancel102 : ControllerToPanelCancelIf connect controller.cancelOutPanel102 to room102.alertPanel.cancelInPort;
		interface c2bCancel102 : ControllerToButtonCancelIf connect controller.cancelOutButton102 to room102.callButton.cancelInPort;
		satisfy rapidAlertReq by room101.alertPanel;
		satisfy rapidAlertReq by room102.alertPanel;
		satisfy networkAvailabilityReq by controller;
		satisfy safeVoltageReq by room101.callButton;
		satisfy safeVoltageReq by room102.callButton;
		satisfy eventLoggingReq by nurseStation;
	}
	
	part facility : HealthcareFacility;
}
