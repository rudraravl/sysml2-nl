package 'Total Artificial Heart System' {

	private import ScalarValues::*;

	value type PressureValue > ScalarValues::Real {
		unit 'mmHg';
	}
	value type FlowRateValue > ScalarValues::Real {
		unit 'L/min';
	}
	value type AngularSpeedValue > ScalarValues::Real {
		unit 'rpm';
	}
	value type TorqueValue > ScalarValues::Real {
		unit 'N*m';
	}
	value type PercentValue > ScalarValues::Real {
		unit '%';
	}

	item def Blood;
	item def DeoxygenatedBlood :> Blood;
	item def OxygenatedBlood :> Blood;

	item def BloodPressureReading {
		attribute systolic : PressureValue;
		attribute diastolic : PressureValue;
	}

	item def FlowRateReading {
		attribute value : FlowRateValue;
	}

	item def BatteryLevelReading {
		attribute charge : PercentValue;
	}

	item def MotorCommand {
		attribute targetSpeed : AngularSpeedValue;
		attribute targetTorque : TorqueValue;
	}

	item def ValveCommand {
		attribute isOpen : Boolean;
	}

	item def SystemAlert {
		attribute severity : String;
		attribute alertText : String;
	}

	attribute def SystoleTrigger;
	attribute def DiastoleTrigger;
	attribute def WarningCondition;
	attribute def CriticalCondition;
	attribute def NormalCondition;

	part def Patient {
		port systemicReturnPort {
			out deoxygenatedBlood : DeoxygenatedBlood;
		}
		port systemicDeliveryPort {
			in oxygenatedBlood : OxygenatedBlood;
		}
	}

	part def Lungs {
		port pulmonaryInputPort {
			in deoxygenatedBlood : DeoxygenatedBlood;
		}
		port pulmonaryOutputPort {
			out oxygenatedBlood : OxygenatedBlood;
		}
	}

	part def RightVentricle {
		port inflowPort {
			in deoxygenatedBlood : DeoxygenatedBlood;
		}
		port outflowPort {
			out deoxygenatedBlood : DeoxygenatedBlood;
		}
		port drivePort {
			in driveForce : TorqueValue;
		}
	}

	part def LeftVentricle {
		port inflowPort {
			in oxygenatedBlood : OxygenatedBlood;
		}
		port outflowPort {
			out oxygenatedBlood : OxygenatedBlood;
		}
		port drivePort {
			in driveForce : TorqueValue;
		}
	}

	part def MechanicalValve {
		port bloodInPort {
			in blood : Blood;
		}
		port bloodOutPort {
			out blood : Blood;
		}
		port commandPort {
			in command : ValveCommand;
		}
		attribute isOpen : Boolean;
	}

	part def ElectricMotor {
		port commandPort {
			in motorCommand : MotorCommand;
		}
		port rightDrivePort {
			out rightDriveForce : TorqueValue;
		}
		port leftDrivePort {
			out leftDriveForce : TorqueValue;
		}
		attribute currentSpeed : AngularSpeedValue;
		attribute currentTorque : TorqueValue;
	}

	part def RechargeableBattery {
		port levelPort {
			out batteryLevel : BatteryLevelReading;
		}
		attribute chargeLevel : PercentValue;
	}

	part def SensorSuite {
		port pressurePort {
			out bloodPressure : BloodPressureReading;
		}
		port flowPort {
			out flowRate : FlowRateReading;
		}
	}

	part def HeartController {
		port pressureInPort {
			in bloodPressure : BloodPressureReading;
		}
		port flowInPort {
			in flowRate : FlowRateReading;
		}
		port batteryInPort {
			in batteryLevel : BatteryLevelReading;
		}
		port motorOutPort {
			out motorCommand : MotorCommand;
		}
		port tricuspidCmdPort {
			out tricuspidCommand : ValveCommand;
		}
		port pulmonaryCmdPort {
			out pulmonaryCommand : ValveCommand;
		}
		port mitralCmdPort {
			out mitralCommand : ValveCommand;
		}
		port aorticCmdPort {
			out aorticCommand : ValveCommand;
		}
		port alertOutPort {
			out systemAlert : SystemAlert;
		}

		attribute currentPressure : BloodPressureReading;
		attribute currentFlow : FlowRateReading;
		attribute currentBattery : BatteryLevelReading;

		state def ControllerStates;
		state controllerState : ControllerStates parallel {
			state cardiacCycle {
				entry; then diastole;
				state diastole;
				accept SystoleTrigger then systole;
				state systole;
				accept DiastoleTrigger then diastole;
			}
			state healthStatus {
				entry; then normal;
				state normal;
				accept WarningCondition then warning;
				state warning;
				accept NormalCondition then normal;
				accept CriticalCondition then critical;
				state critical;
				accept NormalCondition then normal;
			}
		}

		action monitorVitals {
			action receivePressure accept BloodPressureReading via pressureInPort;
			then action receiveFlow accept FlowRateReading via flowInPort;
			then action receiveBattery accept BatteryLevelReading via batteryInPort;
			then action computeMotorCommand;
			then action sendMotorCommand send new MotorCommand() to motorOutPort;
		}
	}

	part def TotalArtificialHeart {
		port systemicReturnPort {
			in deoxygenatedBlood : DeoxygenatedBlood;
		}
		port systemicDeliveryPort {
			out oxygenatedBlood : OxygenatedBlood;
		}
		port pulmonaryArteryPort {
			out deoxygenatedBlood : DeoxygenatedBlood;
		}
		port pulmonaryVeinPort {
			in oxygenatedBlood : OxygenatedBlood;
		}

		part rightVentricle : RightVentricle;
		part leftVentricle : LeftVentricle;
		part tricuspidValve : MechanicalValve;
		part pulmonaryValve : MechanicalValve;
		part mitralValve : MechanicalValve;
		part aorticValve : MechanicalValve;
		part driveMotor : ElectricMotor;
		part battery : RechargeableBattery;
		part controller : HeartController;
		part sensorSuite : SensorSuite;

		flow deoxygenatedBloodFromBody of DeoxygenatedBlood
			from systemicReturnPort.deoxygenatedBlood to tricuspidValve.bloodInPort.blood;
		flow tricuspidToRightVentricle of DeoxygenatedBlood
			from tricuspidValve.bloodOutPort.blood to rightVentricle.inflowPort.deoxygenatedBlood;
		flow rightVentricleToPulmonary of DeoxygenatedBlood
			from rightVentricle.outflowPort.deoxygenatedBlood to pulmonaryValve.bloodInPort.blood;
		flow pulmonaryToLungs of DeoxygenatedBlood
			from pulmonaryValve.bloodOutPort.blood to pulmonaryArteryPort.deoxygenatedBlood;

		flow oxygenatedBloodFromLungs of OxygenatedBlood
			from pulmonaryVeinPort.oxygenatedBlood to mitralValve.bloodInPort.blood;
		flow mitralToLeftVentricle of OxygenatedBlood
			from mitralValve.bloodOutPort.blood to leftVentricle.inflowPort.oxygenatedBlood;
		flow leftVentricleToAortic of OxygenatedBlood
			from leftVentricle.outflowPort.oxygenatedBlood to aorticValve.bloodInPort.blood;
		flow aorticToBody of OxygenatedBlood
			from aorticValve.bloodOutPort.blood to systemicDeliveryPort.oxygenatedBlood;

		flow pressureFeedback of BloodPressureReading
			from sensorSuite.pressurePort.bloodPressure to controller.pressureInPort.bloodPressure;
		flow flowFeedback of FlowRateReading
			from sensorSuite.flowPort.flowRate to controller.flowInPort.flowRate;
		flow batteryFeedback of BatteryLevelReading
			from battery.levelPort.batteryLevel to controller.batteryInPort.batteryLevel;

		flow motorControl of MotorCommand
			from controller.motorOutPort.motorCommand to driveMotor.commandPort.motorCommand;
		flow rightDriveForceFlow of TorqueValue
			from driveMotor.rightDrivePort.rightDriveForce to rightVentricle.drivePort.driveForce;
		flow leftDriveForceFlow of TorqueValue
			from driveMotor.leftDrivePort.leftDriveForce to leftVentricle.drivePort.driveForce;

		flow tricuspidControl of ValveCommand
			from controller.tricuspidCmdPort.tricuspidCommand to tricuspidValve.commandPort.command;
		flow pulmonaryControl of ValveCommand
			from controller.pulmonaryCmdPort.pulmonaryCommand to pulmonaryValve.commandPort.command;
		flow mitralControl of ValveCommand
			from controller.mitralCmdPort.mitralCommand to mitralValve.commandPort.command;
		flow aorticControl of ValveCommand
			from controller.aorticCmdPort.aorticCommand to aorticValve.commandPort.command;
	}

	part patient : Patient {
		action patientPhysiology {
			action receiveOxygenatedBlood accept OxygenatedBlood via patient;
			then action sendDeoxygenatedBlood send new DeoxygenatedBlood() to artificialHeart;
		}
	}

	part lungs : Lungs {
		action lungPhysiology {
			action receiveDeoxygenatedBlood accept DeoxygenatedBlood via lungs;
			then action sendOxygenatedBlood send new OxygenatedBlood() to artificialHeart;
		}
	}

	part artificialHeart : TotalArtificialHeart {
		part :>> controller {
			action controllerBehavior {
				action receivePressure accept BloodPressureReading via controller;
				then action receiveFlow accept FlowRateReading via controller;
				then action receiveBattery accept BatteryLevelReading via controller;
				then action evaluatePhysiologicalNeeds;
				then action sendMotorCommand send new MotorCommand() to driveMotor;
				then action sendValveCommands send new ValveCommand() to tricuspidValve;
			}
		}
		part :>> driveMotor {
			action motorBehavior {
				action receiveMotorCommand accept MotorCommand via driveMotor;
				then action applyDriveForce;
			}
		}
		part :>> sensorSuite {
			action sensorBehavior {
				action sendPressure send new BloodPressureReading() to controller;
				then action sendFlow send new FlowRateReading() to controller;
			}
		}
		part :>> battery {
			action batteryBehavior {
				action sendBatteryLevel send new BatteryLevelReading() to controller;
			}
		}
		part :>> rightVentricle {
			action rightVentricleBehavior {
				action fillDeoxygenatedBlood accept DeoxygenatedBlood via rightVentricle;
				then action ejectDeoxygenatedBlood send new DeoxygenatedBlood() to pulmonaryValve;
			}
		}
		part :>> leftVentricle {
			action leftVentricleBehavior {
				action fillOxygenatedBlood accept OxygenatedBlood via leftVentricle;
				then action ejectOxygenatedBlood send new OxygenatedBlood() to aorticValve;
			}
		}
	}

	interface patientToHeartInterface connect patient.systemicReturnPort to artificialHeart.systemicReturnPort {
		flow deoxygenatedBloodReturn of DeoxygenatedBlood
			from patient.systemicReturnPort.deoxygenatedBlood to artificialHeart.systemicReturnPort.deoxygenatedBlood;
	}

	interface heartToPatientInterface connect artificialHeart.systemicDeliveryPort to patient.systemicDeliveryPort {
		flow oxygenatedBloodDelivery of OxygenatedBlood
			from artificialHeart.systemicDeliveryPort.oxygenatedBlood to patient.systemicDeliveryPort.oxygenatedBlood;
	}

	interface heartToLungsInterface connect artificialHeart.pulmonaryArteryPort to lungs.pulmonaryInputPort {
		flow deoxygenatedBloodToLungs of DeoxygenatedBlood
			from artificialHeart.pulmonaryArteryPort.deoxygenatedBlood to lungs.pulmonaryInputPort.deoxygenatedBlood;
	}

	interface lungsToHeartInterface connect lungs.pulmonaryOutputPort to artificialHeart.pulmonaryVeinPort {
		flow oxygenatedBloodFromLungs of OxygenatedBlood
			from lungs.pulmonaryOutputPort.oxygenatedBlood to artificialHeart.pulmonaryVeinPort.oxygenatedBlood;
	}

	requirement def CardiovascularSupportRequirement {
		doc /* The Total Artificial Heart must provide continuous blood circulation. */
		subject artificialHeart : TotalArtificialHeart;
	}

	requirement def CardiacCycleRequirement {
		doc /* The system must alternate between filling (diastole) and ejection (systole). */
		subject artificialHeart : TotalArtificialHeart;
	}

	requirement def PowerAutonomyRequirement {
		doc /* The internal battery must provide several hours of continuous operation. */
		subject battery : RechargeableBattery;
	}

	requirement def PhysiologicalAdaptationRequirement {
		doc /* The controller must adjust motor speed and force based on sensor feedback. */
		subject controller : HeartController;
	}

	requirement def HealthMonitoringRequirement {
		doc /* The system must track its health and enter normal, warning, or critical states. */
		subject controller : HeartController;
	}

	requirement cardiovascularSupport : CardiovascularSupportRequirement {
		subject :>> artificialHeart = artificialHeart;
	}

	requirement cardiacCycle : CardiacCycleRequirement {
		subject :>> artificialHeart = artificialHeart;
	}

	requirement powerAutonomy : PowerAutonomyRequirement {
		subject :>> battery = artificialHeart.battery;
	}

	requirement physiologicalAdaptation : PhysiologicalAdaptationRequirement {
		subject :>> controller = artificialHeart.controller;
	}

	requirement healthMonitoring : HealthMonitoringRequirement {
		subject :>> controller = artificialHeart.controller;
	}

}
