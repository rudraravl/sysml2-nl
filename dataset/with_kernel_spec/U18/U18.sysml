package 'Cable-Driven Parallel Robot' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	private import Time::Clock;

	item def TargetCoordinate {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}

	item def PositionStatus {
		attribute currentX : LengthValue;
		attribute currentY : LengthValue;
		attribute currentZ : LengthValue;
		attribute cableTensions : ForceValue[6];
	}

	item def WinchCommand {
		attribute targetLength : LengthValue;
	}

	attribute def StartCommand;
	attribute def HoldCommand;
	attribute def ResetCommand;
	attribute def EmergencyStopSignal;
	attribute def OverloadAlert;

	requirement def WorkspaceVolumeRequirement {
		doc /* The operational workspace shall be at least 30 cubic meters. */
		attribute minVolume : VolumeValue = 30 [m**3];
		subject workspaceVolume : VolumeValue;
		require constraint { workspaceVolume >= minVolume }
	}

	requirement def PayloadMassRequirement {
		doc /* The system shall handle payloads up to 100 kg. */
		attribute maxMass : MassValue = 100 [kg];
		subject payloadMass : MassValue;
		require constraint { payloadMass <= maxMass }
	}

	requirement def PositioningAccuracyRequirement {
		doc /* Positioning accuracy shall be within 2 millimeters. */
		attribute requiredAccuracy : LengthValue = 2 [mm];
		subject actualAccuracy : LengthValue;
		require constraint { actualAccuracy <= requiredAccuracy }
	}

	requirement def TensionSafetyRequirement {
		doc /* Cable tension must never exceed the maximum safe limit. */
		attribute maxSafeTension : ForceValue = 5000 [N];
		subject cableTension : ForceValue;
		require constraint { cableTension <= maxSafeTension }
	}

	action def 'Rotate Motor' {
		in targetLength : LengthValue;
		out actualLength : LengthValue;
		out actualTension : ForceValue;
	}

	action def 'Compute Inverse Kinematics' {
		in target : TargetCoordinate;
		in currentPosition : PositionStatus;
		out cableLengths : LengthValue[6];
		out cableTensions : ForceValue[6];
	}

	action def 'Monitor Tensions' {
		in tensions : ForceValue[6];
		out overload : Boolean;
	}

	action def 'Send Status' {
		in position : PositionStatus;
	}

	part def AnchorPoint {
		attribute positionX : LengthValue;
		attribute positionY : LengthValue;
		attribute positionZ : LengthValue;
	}

	part def Winch {
		port controlPort;
		port feedbackPort;
		port cablePort;
		attribute anchorPosition : TargetCoordinate;
		attribute commandedLength : LengthValue;
		attribute actualLength : LengthValue;
		attribute cableTension : ForceValue;
		attribute maxSafeTension : ForceValue = 5000 [N];
		perform action 'rotate motor' : 'Rotate Motor';

		exhibit state winchStates {
			entry; then stopped;
			state stopped;
			accept cmd : WinchCommand via controlPort
				then moving;
			state moving {
				entry assign commandedLength := cmd.targetLength;
				do 'rotate motor';
				accept when actualLength == commandedLength
					then stopped;
				accept when cableTension > maxSafeTension
					then fault;
			}
			state fault;
			accept ResetCommand via controlPort
				then stopped;
		}
	}

	part def Cable {
		port winchEnd;
		port payloadEnd;
		attribute length : LengthValue;
		attribute tension : ForceValue;
		attribute maxTension : ForceValue = 5000 [N];
	}

	part def PayloadPlatform {
		port cablePorts[6];
		attribute mass : MassValue;
		attribute currentX : LengthValue;
		attribute currentY : LengthValue;
		attribute currentZ : LengthValue;
	}

	part def OperatorStation {
		port commandPort;
		port statusPort;
	}

	part def CableRobotController {
		port operatorPort;
		port winchCommandPorts[6];
		port winchFeedbackPorts[6];
		attribute controlFrequency : Real = 100.0;
		attribute maxPayloadMass : MassValue = 100 [kg];
		attribute positioningAccuracy : LengthValue = 2 [mm];
		attribute workspaceVolume : VolumeValue = 30 [m**3];
		attribute targetCoordinate : TargetCoordinate;
		attribute currentPosition : PositionStatus;
		attribute cableLengthCommands : LengthValue[6];
		attribute cableTensionReadings : ForceValue[6];
		attribute overloadDetected : Boolean;
		perform action 'compute inverse kinematics' : 'Compute Inverse Kinematics';
		perform action 'monitor tensions' : 'Monitor Tensions';
		perform action 'send status' : 'Send Status';

		exhibit state controllerStates {
			entry; then Idle;
			state Idle {
				do 'monitor tensions';
			}
			accept target : TargetCoordinate via operatorPort
				then Positioning;
			state Positioning {
				entry assign targetCoordinate := target;
				do 'compute inverse kinematics';
				do 'send status';
				accept after 0.01 [s]
					then Positioning;
				accept HoldCommand via operatorPort
					then Holding;
				accept when overloadDetected
					then Emergency;
			}
			state Holding {
				do 'monitor tensions';
				do 'send status';
				accept target : TargetCoordinate via operatorPort
					then Positioning;
				accept when overloadDetected
					then Emergency;
			}
			state Emergency {
				entry do send new OverloadAlert() to operatorPort;
				accept ResetCommand via operatorPort
					then Idle;
			}
		}
	}

	part def CableDrivenRobot {
		part controller : CableRobotController {
			part :>> localClock = new Time::Clock();
		}
		part platform : PayloadPlatform {
			attribute mass : MassValue = 50 [kg];
		}
		part winches : Winch[6];
		part cables : Cable[6];
		part anchors : AnchorPoint[6];
		part operatorStation : OperatorStation;

		connect controller.winchCommandPorts to winches.controlPort;
		connect winches.feedbackPort to controller.winchFeedbackPorts;
		connect winches.cablePort to cables.winchEnd;
		connect cables.payloadEnd to platform.cablePorts;
		connect operatorStation.commandPort to controller.operatorPort;
		connect controller.operatorPort to operatorStation.statusPort;

		requirement workspaceReq : WorkspaceVolumeRequirement {
			attribute :>> workspaceVolume = controller.workspaceVolume;
		}
		requirement payloadReq : PayloadMassRequirement {
			attribute :>> payloadMass = platform.mass;
		}
		requirement accuracyReq : PositioningAccuracyRequirement {
			attribute :>> actualAccuracy = controller.positioningAccuracy;
		}
		requirement tensionReq : TensionSafetyRequirement {
			attribute :>> cableTension = cables.tension;
		}

		satisfy workspaceReq by controller;
		satisfy payloadReq by platform;
		satisfy accuracyReq by controller;
		satisfy tensionReq by cables;

		assert constraint payloadMassConstraint {
			platform.mass <= controller.maxPayloadMass
		}
		assert constraint tensionSafetyConstraint {
			cables.tension <= cables.maxTension
		}
	}

	part robot : CableDrivenRobot;
}
