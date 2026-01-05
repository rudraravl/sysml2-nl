package 'Robotic Medical System' {
	private import ScalarValues::*;
	private import SI::*;

	attribute def Force :> Real;
	attribute def Position :> Real;
	attribute def Voltage :> Real;
	attribute def Current :> Real;
	attribute def Temperature :> Real;
	attribute def Precision :> Real;

	enum def RobotState {
		enum idle;
		enum initializing;
		enum ready;
		enum operating;
		enum paused;
		enum error;
		enum shutdown;
	}

	enum def SurgicalPhase {
		enum preparation;
		enum incision;
		enum procedure;
		enum closure;
		enum complete;
	}

	enum def SafetyLevel {
		enum safe;
		enum warning;
		enum critical;
	}

	item def SurgicalCommand {
		attribute commandId : String;
		attribute targetPosition : Position;
		attribute targetForce : Force;
	}

	item def StatusData {
		attribute statusId : String;
		attribute currentState : RobotState;
		attribute safetyLevel : SafetyLevel;
	}

	item def SensorData {
		attribute forceReading : Force;
		attribute positionReading : Position;
		attribute temperatureReading : Temperature;
	}

	port def ControlPort {
		in command : SurgicalCommand;
		out status : StatusData;
	}

	port def PowerPort {
		in voltage : Voltage;
		in current : Current;
	}

	port def SensorPort {
		out sensorData : SensorData;
	}

	port def InstrumentPort {
		in targetPosition : Position;
		out actualPosition : Position;
	}

	action def InitializeSystem {
		out systemReady : Boolean;
	}

	action def CalibrateInstruments {
		in targetPrecision : Precision;
		out calibrationComplete : Boolean;
		out achievedPrecision : Precision;
	}

	action def MonitorVitalSigns {
		out heartRate : Real;
		out bloodPressure : Real;
		out oxygenLevel : Real;
	}

	action def PerformIncision {
		in targetDepth : Position;
		in targetLocation : Position;
		out incisionComplete : Boolean;
	}

	action def ApplyForce {
		in targetForce : Force;
		in maxForce : Force;
		out appliedForce : Force;
	}

	action def MonitorSafety {
		in forceReading : Force;
		in positionReading : Position;
		in temperatureReading : Temperature;
		out safetyStatus : SafetyLevel;
	}

	action def ExecuteSurgicalProcedure {
		in procedureType : String;
		out procedureComplete : Boolean;
	}

	action def EmergencyStop {
		out systemStopped : Boolean;
	}

	requirement def PrimaryTaskRequirement {
		doc /* The robotic system shall perform its primary task using a medical robot to execute surgical procedures safely and effectively. */
	}

	requirement def SafetyRequirement {
		doc /* The system must maintain safe operation parameters at all times. */
	}

	requirement def PrecisionRequirement {
		doc /* Surgical precision must be within 0.5mm. */
	}

	requirement def ForceControlRequirement {
		doc /* Applied force must not exceed safe limits. */
	}

	package LogicalModel {
		action def PerformMedicalTask;
		action def ExecuteSurgery;
		action def MonitorPatient;

		part def SurgicalTaskExecutor;

		action performMedicalTask : PerformMedicalTask {
			first start;
			then action executeSurgery : ExecuteSurgery;
			then action monitorPatient : MonitorPatient;
			then done;
		}

		part surgicalTaskExecutor : SurgicalTaskExecutor {
			perform performMedicalTask.executeSurgery;
		}
	}

	package PhysicalModel {
		private import LogicalModel::*;

		part def RoboticMedicalSystem;

		part def MedicalRobot {
			attribute currentState : RobotState = RobotState::idle;
			attribute currentForce : Force;
			attribute maxSafeForce : Force = 50.0[N];
			attribute achievedPrecision : Precision;
			attribute operatingTemperature : Temperature;

			port controlInterface : ControlPort;
			port powerInterface : PowerPort;
			port instrumentInterface : InstrumentPort;
			port sensorInterface : SensorPort;

			part roboticArm : RoboticArm {
				attribute armPosition : Position;
				attribute armForce : Force;
			}

			part visionSystem : VisionSystem {
				attribute imageResolution : Real;
				attribute trackingAccuracy : Precision;
			}

			part controlUnit : ControlUnit {
				attribute processingSpeed : Real;
			}

			perform performMedicalTask.executeSurgery;
		}

		part def RoboticArm {
			attribute armPosition : Position;
			attribute armForce : Force;
			attribute jointCount : Integer = 6;

			part endEffector : EndEffector {
				attribute gripForce : Force;
				attribute toolAttached : Boolean;
			}

			part actuators : Actuator[6];

			part forceController : ForceController {
				perform applyForce;
			}
		}

		part def EndEffector {
			attribute gripForce : Force;
			attribute toolAttached : Boolean;
			attribute maxGripForce : Force = 30.0[N];
		}

		part def Actuator {
			attribute actuatorId : Integer;
			attribute currentPosition : Position;
			attribute targetPosition : Position;
		}

		part def ForceController {
			ref action applyForce : ApplyForce;
		}

		part def VisionSystem {
			attribute imageResolution : Real;
			attribute trackingAccuracy : Precision;

			part cameras : Camera[2];
			part imageProcessor : ImageProcessor;
		}

		part def Camera {
			attribute cameraId : Integer;
			attribute frameRate : Real;
		}

		part def ImageProcessor {
			attribute processingLatency : Real;
		}

		part def ControlUnit {
			attribute processingSpeed : Real;

			part safetyMonitor : SafetyMonitor {
				perform monitorSafety;
			}

			part procedureController : ProcedureController {
				perform executeProcedure;
			}
		}

		part def SafetyMonitor {
			attribute safetyStatus : SafetyLevel = SafetyLevel::safe;
			ref action monitorSafety : MonitorSafety;
		}

		part def ProcedureController {
			attribute currentPhase : SurgicalPhase = SurgicalPhase::preparation;
			ref action executeProcedure : ExecuteSurgicalProcedure;
		}

		part def PatientMonitoringSystem {
			attribute patientId : String;

			part vitalSignsMonitor : VitalSignsMonitor {
				perform monitorVitals;
			}
		}

		part def VitalSignsMonitor {
			attribute heartRate : Real;
			attribute bloodPressure : Real;
			attribute oxygenLevel : Real;
			ref action monitorVitals : MonitorVitalSigns;
		}

		part def PowerSupply {
			port output : PowerPort;
			attribute voltageLevel : Voltage;
			attribute currentCapacity : Current;
		}

		part def OperatorConsole {
			port commandPort : ControlPort;
			attribute operatorId : String;
		}

		part roboticMedicalSystem : RoboticMedicalSystem {
			part medicalRobot : MedicalRobot {
				:>> currentState = RobotState::ready;
				:>> maxSafeForce = 45.0[N];
				:>> achievedPrecision = 0.3[mm];
				:>> operatingTemperature = 22.0[degC];

				perform performMedicalTask.executeSurgery;
			}

			part patientMonitor : PatientMonitoringSystem {
				:>> patientId = "PAT-2024-001";

				perform performMedicalTask.monitorPatient;
			}

			part powerSupply : PowerSupply {
				attribute :>> voltageLevel = 48.0[V];
				attribute :>> currentCapacity = 20.0[A];
			}

			part console : OperatorConsole {
				attribute :>> operatorId = "OP-001";
			}

			connection powerLink connect powerSupply.output to medicalRobot.powerInterface;
			connection controlLink connect console.commandPort to medicalRobot.controlInterface;
		}

		allocation def LogicalToPhysicalAllocation {
			end logical : SurgicalTaskExecutor;
			end physical : RoboticMedicalSystem;
		}

		allocation surgicalTaskAllocation : LogicalToPhysicalAllocation
			allocate surgicalTaskExecutor to roboticMedicalSystem {
			allocate surgicalTaskExecutor.executeSurgery 
				to roboticMedicalSystem.medicalRobot.executeSurgery;
		}
	}

	action initializeRoboticSystem : InitializeSystem {
		first start;
		then action calibrate : CalibrateInstruments {
			in targetPrecision = 0.5[mm];
			out calibrationComplete;
			out achievedPrecision;
		}
		then decide;
			if calibrate.calibrationComplete then ready;
			if !calibrate.calibrationComplete then error;
		action ready {
			out systemReady = true;
		}
		then done;
		action error {
			out systemReady = false;
		}
		then done;
	}

	action performSurgicalOperation {
		first start;
		then merge checkSafety;

		action checkSafety : MonitorSafety {
			in forceReading;
			in positionReading;
			in temperatureReading;
			out safetyStatus;
		}

		then decide;
			if checkSafety.safetyStatus == SafetyLevel::safe then proceedWithSurgery;
			if checkSafety.safetyStatus == SafetyLevel::warning then checkSafety;
			if checkSafety.safetyStatus == SafetyLevel::critical then emergencyStop;

		action proceedWithSurgery : ExecuteSurgicalProcedure {
			in procedureType = "Minimally Invasive Surgery";
			out procedureComplete;
		}

		then decide;
			if proceedWithSurgery.procedureComplete then done;
			if !proceedWithSurgery.procedureComplete then checkSafety;

		action emergencyStop : EmergencyStop {
			out systemStopped;
		}
		then done;
	}

	state def RobotOperationStateMachine {
		entry; then idle;

		state idle;
		transition idle_to_initializing
			first idle
			then initializing;

		state initializing {
			entry; do initializeRoboticSystem;
		}
		transition initializing_to_ready
			first initializing
			if initializeRoboticSystem.systemReady
			then ready;

		state ready;
		transition ready_to_operating
			first ready
			then operating;

		state operating {
			entry; do performSurgicalOperation;
		}
		transition operating_to_ready
			first operating
			if performSurgicalOperation.proceedWithSurgery.procedureComplete
			then ready;

		transition operating_to_error
			first operating
			if performSurgicalOperation.checkSafety.safetyStatus == SafetyLevel::critical
			then error;

		state error {
			entry; do action stopAction : EmergencyStop;
		}
		transition error_to_shutdown
			first error
			then shutdown;

		state shutdown;
		then done;
	}

	requirement primaryTaskReq : PrimaryTaskRequirement {
		subject system = PhysicalModel::roboticMedicalSystem;
	}

	requirement safetyReq : SafetyRequirement {
		subject system = PhysicalModel::roboticMedicalSystem;
		require constraint {
			system.medicalRobot.controlUnit.safetyMonitor.safetyStatus != SafetyLevel::critical
		}
	}

	requirement precisionReq : PrecisionRequirement {
		subject robot = PhysicalModel::roboticMedicalSystem.medicalRobot;
		require constraint {
			robot.achievedPrecision <= 0.5[mm]
		}
	}

	requirement forceReq : ForceControlRequirement {
		subject robot = PhysicalModel::roboticMedicalSystem.medicalRobot;
		require constraint {
			robot.currentForce <= robot.maxSafeForce
		}
	}

	verification def VerifyPrecision {
		subject testRobot : PhysicalModel::MedicalRobot;
		return verdict : Boolean;
		objective {
			doc /* Verify that the medical robot achieves required precision. */
		}
		requirement precisionReq;
	}

	verification precisionTest : VerifyPrecision {
		subject testRobot = PhysicalModel::roboticMedicalSystem.medicalRobot;
	}

	individual def TestMedicalRobot :> PhysicalModel::MedicalRobot;

	individual testSystem : PhysicalModel::RoboticMedicalSystem :> PhysicalModel::roboticMedicalSystem {
		timeslice surgeryPreparation {
			:>> medicalRobot : TestMedicalRobot {
				:>> currentState = RobotState::initializing;
				:>> achievedPrecision = 0.4[mm];
			}
			perform action initPrep : InitializeSystem {
				out systemReady = true;
			}
		}
		then timeslice surgeryExecution {
			:>> medicalRobot : TestMedicalRobot {
				:>> currentState = RobotState::operating;
				:>> currentForce = 25.0[N];
				:>> achievedPrecision = 0.3[mm];
			}
			perform action execSurgery : ExecuteSurgicalProcedure {
				in procedureType = "Laparoscopic Procedure";
				out procedureComplete = true;
			}
		}
		then timeslice surgeryCompletion {
			:>> medicalRobot : TestMedicalRobot {
				:>> currentState = RobotState::ready;
				:>> currentForce = 0.0[N];
			}
		}
	}

	satisfy primaryTaskReq by PhysicalModel::roboticMedicalSystem;
	satisfy safetyReq by PhysicalModel::roboticMedicalSystem;
	satisfy precisionReq by PhysicalModel::roboticMedicalSystem.medicalRobot;
	satisfy forceReq by PhysicalModel::roboticMedicalSystem.medicalRobot;
}
