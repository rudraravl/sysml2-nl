package 'Automated Metal Corset System' {
	private import ScalarValues::*;

	attribute def AngleValue : Real;
	attribute def ForceValue : Real;
	attribute def LengthValue : Real;

	item def PostureData {
		attribute spinalAlignmentAngle : AngleValue;
		attribute torsoCircumference : LengthValue;
	}

	item def IdealPosture {
		attribute idealAngle : AngleValue;
	}

	item def CompressionCommand {
		attribute tensionAdjustment : ForceValue;
		attribute tighten : Boolean;
	}

	item def PowerOn;
	item def AlignmentRestored;
	item def OverCompressionSignal;
	item def ManualReset;

	part def MetalBoning {
		attribute material : String = "Spring Steel";
		attribute stiffness : Real;
	}

	part def StructuralFrame {
		part boningElements : MetalBoning[8..16];
	}

	part def AutomatedLacingMechanism {
		port commandPort {
			in compressionCommand : CompressionCommand;
		}
		attribute currentTension : ForceValue;
		attribute adjustmentRangeMin : LengthValue;
		attribute adjustmentRangeMax : LengthValue;

		action adjustTension {
			action acceptCommand accept CompressionCommand via commandPort;
			then action setTension {
				in command : CompressionCommand = acceptCommand.compressionCommand;
			}
		}
	}

	part def PostureSensor {
		port dataPort {
			out postureData : PostureData;
		}
		action sensePosture {
			out data : PostureData;
		}
	}

	part def CompressionActuator {
		port inPort {
			in compressionCommand : CompressionCommand;
		}
		port outPort {
			out compressionCommand : CompressionCommand;
		}
		action adjustTension {
			action acceptCommand accept CompressionCommand via inPort;
			then action applyForce {
				in command : CompressionCommand = acceptCommand.compressionCommand;
				out adjustedCommand : CompressionCommand;
			}
			then send applyForce.adjustedCommand via outPort;
		}
	}

	part def CentralControlUnit {
		port sensorPort {
			in postureData : PostureData;
		}
		port actuatorPort {
			out compressionCommand : CompressionCommand;
		}
		attribute idealPosture : IdealPosture;
		attribute maxCompressionForce : ForceValue;
		attribute tolerance : AngleValue;

		action controlBehavior {
			loop action controlLoop {
				action receiveData accept PostureData via sensorPort;
				then action calculateCorrection {
					in data : PostureData = receiveData.postureData;
					in idealAngle : AngleValue = idealPosture.idealAngle;
					in limit : ForceValue = maxCompressionForce;
					in tolAngle : AngleValue = tolerance;
					out cmd : CompressionCommand;
				}
				then if calculateCorrection.cmd.tensionAdjustment > 0.0 {
					action sendCommand send new CompressionCommand() via actuatorPort;
				}
			}
		}
	}

	state def CorsetOperationStates {
		entry; then standby;
		state standby;
		state activeMonitoring;
		state postureCorrection;
		state safetyOverride;

		transition standby_to_active
			first standby
			accept PowerOn
			then activeMonitoring;

		transition detect_deviation
			first activeMonitoring
			accept PostureData
			then postureCorrection;

		transition correction_complete
			first postureCorrection
			accept AlignmentRestored
			then activeMonitoring;

		transition safety_trigger_monitor
			first activeMonitoring
			accept OverCompressionSignal
			then safetyOverride;

		transition safety_trigger_correction
			first postureCorrection
			accept OverCompressionSignal
			then safetyOverride;

		transition reset_from_safety
			first safetyOverride
			accept ManualReset
			then standby;
	}

	part def PhysicalCorset {
		port sensorDataPort {
			out postureData : PostureData;
		}
		port commandPort {
			in compressionCommand : CompressionCommand;
		}

		part structuralFrame : StructuralFrame;
		part lacing : AutomatedLacingMechanism;
		part sensor : PostureSensor;
		part actuator : CompressionActuator;
		part controller : CentralControlUnit;

		flow sensorDataFlow of PostureData
			from sensor.dataPort.postureData to controller.sensorPort.postureData;
		flow actuatorCommandFlow of CompressionCommand
			from controller.actuatorPort.compressionCommand to actuator.inPort.compressionCommand;
		flow lacingCommandFlow of CompressionCommand
			from actuator.outPort.compressionCommand to lacing.commandPort.compressionCommand;

		bind sensorDataPort = sensor.dataPort;
		bind commandPort = lacing.commandPort;
	}

	requirement def PostureCorrectionRequirement {
		subject corset : PhysicalCorset;

		requirement provideSupport {
			doc /* The system shall provide torso support using a rigid structural frame with metal boning elements. */
		}
		requirement correctPosture {
			doc /* The system shall actively correct the wearer's posture by adjusting compression based on posture data. */
		}
		requirement ensureSafety {
			doc /* The system shall not exceed the maximum compression force limit. */
			attribute maxForce : ForceValue = 50.0;
		}
		requirement accommodateBodyTypes {
			doc /* The system shall be adaptable to different body types via an adjustment range. */
			attribute minCircumference : LengthValue = 600.0;
			attribute maxCircumference : LengthValue = 1000.0;
		}
		requirement maintainAccuracy {
			doc /* The system shall maintain posture within 5 degrees of the ideal angle. */
			attribute tolerance : AngleValue = 5.0;
		}
	}

	part corsetSystem : PhysicalCorset {
		satisfy req : PostureCorrectionRequirement by corsetSystem;
	}

	occurrence def CorsetOperation {
		message postureDataMsg of PostureData;
		message commandMsg of CompressionCommand;

		ref part corset : PhysicalCorset {
			event corset.sensor.sensePosture[1] :>> postureSensed;
			event corset.controller.controlBehavior.controlLoop.receiveData[1] :>> dataReceived;
			event corset.controller.controlBehavior.controlLoop.calculateCorrection[1] :>> correctionCalculated;
			event corset.controller.controlBehavior.controlLoop.sendCommand[1] :>> commandSent;
			event corset.actuator.adjustTension[1] :>> tensionAdjusted;
		}
		message :>> postureDataMsg = corset.sensor.dataPort.postureData;
		message :>> commandMsg = corset.controller.actuatorPort.compressionCommand;
	}
}
