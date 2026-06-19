package ClimberSystemModel {
	import ScalarValues::*;

	attribute def UnitSymbol :> String;

	attribute def Length_m :> Real {
		attribute unitSymbol : UnitSymbol = "m";
	}

	attribute def Speed_m_per_s :> Real {
		attribute unitSymbol : UnitSymbol = "m/s";
	}

	attribute def Acceleration_m_per_s2 :> Real {
		attribute unitSymbol : UnitSymbol = "m/s^2";
	}

	attribute def Mass_kg :> Real {
		attribute unitSymbol : UnitSymbol = "kg";
	}

	attribute def Force_N :> Real {
		attribute unitSymbol : UnitSymbol = "N";
	}

	attribute def Energy_Wh :> Real {
		attribute unitSymbol : UnitSymbol = "Wh";
	}

	attribute def Power_W :> Real {
		attribute unitSymbol : UnitSymbol = "W";
	}

	attribute def Voltage_V :> Real {
		attribute unitSymbol : UnitSymbol = "V";
	}

	attribute def Current_A :> Real {
		attribute unitSymbol : UnitSymbol = "A";
	}

	attribute def Time_s :> Real {
		attribute unitSymbol : UnitSymbol = "s";
	}

	attribute def Angle_deg :> Real {
		attribute unitSymbol : UnitSymbol = "deg";
	}

	item def ClimberOperator {
		attribute bodyMass : Mass_kg;
		attribute carriedEquipmentMass : Mass_kg;
	}

	item def ElectricalPower {
		attribute voltage : Voltage_V;
		attribute current : Current_A;
		attribute power : Power_W;
	}

	item def BatteryState {
		attribute storedEnergy : Energy_Wh;
		attribute stateOfCharge : Real;
		attribute outputVoltage : Voltage_V;
		attribute availablePower : Power_W;
	}

	item def ClimbCommand {
		attribute requestedHeightChange : Length_m;
		attribute requestedSpeed : Speed_m_per_s;
		attribute upward : Boolean;
		attribute holdPosition : Boolean;
		attribute emergencyStop : Boolean;
	}

	item def ClimberStatus {
		attribute currentHeight : Length_m;
		attribute currentSpeed : Speed_m_per_s;
		attribute attached : Boolean;
		attribute loadSupported : Boolean;
		attribute faultActive : Boolean;
		attribute batteryStateOfCharge : Real;
	}

	item def SurfaceContact {
		attribute localSlope : Angle_deg;
		attribute surfaceNormalForce : Force_N;
		attribute surfaceIsGrippable : Boolean;
	}

	item def AnchorLoad {
		attribute normalForce : Force_N;
		attribute shearForce : Force_N;
		attribute attachmentForce : Force_N;
		attribute locked : Boolean;
	}

	item def TetherTension {
		attribute tension : Force_N;
		attribute paidOutLength : Length_m;
		attribute locked : Boolean;
	}

	item def VerticalMotion {
		attribute heightChange : Length_m;
		attribute speed : Speed_m_per_s;
		attribute acceleration : Acceleration_m_per_s2;
		attribute directionUp : Boolean;
	}

	item def MotionProfile {
		attribute targetHeight : Length_m;
		attribute cruiseSpeed : Speed_m_per_s;
		attribute maximumAcceleration : Acceleration_m_per_s2;
		attribute stopDistance : Length_m;
	}

	item def ControlCommand {
		attribute commandedForce : Force_N;
		attribute commandedSpeed : Speed_m_per_s;
		attribute enable : Boolean;
		attribute lock : Boolean;
	}

	port def ElectricalPowerInputPort {
		in item power : ElectricalPower;
	}

	port def ElectricalPowerOutputPort {
		out item power : ElectricalPower;
	}

	port def BatteryStatusPort {
		out item batteryState : BatteryState;
	}

	port def ClimberOperatorInterfacePort {
		in item command : ClimbCommand;
		out item status : ClimberStatus;
	}

	port def OperatorConsolePort {
		out item command : ClimbCommand;
		in item status : ClimberStatus;
	}

	port def ControlCommandInputPort {
		in item control : ControlCommand;
	}

	port def ControlCommandOutputPort {
		out item control : ControlCommand;
	}

	port def StatusInputPort {
		in item status : ClimberStatus;
	}

	port def StatusOutputPort {
		out item status : ClimberStatus;
	}

	port def SurfaceProviderPort {
		out item surfaceContact : SurfaceContact;
	}

	port def AnchorInterfacePort {
		in item surfaceContact : SurfaceContact;
		out item anchorLoad : AnchorLoad;
	}

	port def TetherPort {
		inout item tension : TetherTension;
	}

	port def MotionPort {
		out item motion : VerticalMotion;
	}

	action def SupplyElectricalPower {
		out item power : ElectricalPower;
		out item batteryState : BatteryState;
	}

	action def ReadOperatorCommand {
		in item operator : ClimberOperator;
		out item command : ClimbCommand;
	}

	action def ComputeClimbPlan {
		in item command : ClimbCommand;
		in item status : ClimberStatus;
		out item profile : MotionProfile;
	}

	action def EngageAnchor {
		in item surfaceContact : SurfaceContact;
		in item control : ControlCommand;
		out item anchorLoad : AnchorLoad;
	}

	action def DriveVerticalMotion {
		in item profile : MotionProfile;
		in item power : ElectricalPower;
		out item motion : VerticalMotion;
	}

	action def RegulateTether {
		in item motion : VerticalMotion;
		inout item tension : TetherTension;
	}

	action def MonitorSafety {
		in item anchorLoad : AnchorLoad;
		in item tension : TetherTension;
		in item batteryState : BatteryState;
		out item status : ClimberStatus;
	}

	action def TransportClimberVertically {
		in item operator : ClimberOperator;
		in item command : ClimbCommand;
		in item leftSurface : SurfaceContact;
		in item rightSurface : SurfaceContact;
		out item motion : VerticalMotion;
		out item status : ClimberStatus;

		action readCommand : ReadOperatorCommand;
		then action computePlan : ComputeClimbPlan;
		then action engageLeftAnchor : EngageAnchor;
		then action engageRightAnchor : EngageAnchor;
		then action driveMotion : DriveVerticalMotion;
		then action regulateTether : RegulateTether;
		then action monitorSafety : MonitorSafety;
	}

	action def HoldClimberStationary {
		in item leftAnchorLoad : AnchorLoad;
		in item rightAnchorLoad : AnchorLoad;
		inout item tetherTension : TetherTension;
		out item status : ClimberStatus;
	}

	action def ExecuteEmergencyStop {
		in item motion : VerticalMotion;
		out item status : ClimberStatus;
	}

	state def ClimberOperatingStates {
		state stowed;
		state ready;
		state anchoring;
		state climbing;
		state holding;
		state descending;
		state emergencyStopping;
		state faulted;

		transition stowed_to_ready first stowed then ready;
		transition ready_to_anchoring first ready then anchoring;
		transition anchoring_to_climbing first anchoring then climbing;
		transition climbing_to_holding first climbing then holding;
		transition holding_to_climbing first holding then climbing;
		transition holding_to_descending first holding then descending;
		transition descending_to_holding first descending then holding;
		transition climbing_to_emergencyStopping first climbing then emergencyStopping;
		transition descending_to_emergencyStopping first descending then emergencyStopping;
		transition emergencyStopping_to_faulted first emergencyStopping then faulted;
		transition faulted_to_ready first faulted then ready;
	}

	part def Frame {
		attribute structuralMass : Mass_kg = 8.0;
		attribute maximumStructuralLoad : Force_N = 2500.0;
		attribute railLength : Length_m = 1.2;
	}

	part def BatteryPack {
		attribute capacity : Energy_Wh = 720.0;
		attribute nominalVoltage : Voltage_V = 48.0;
		attribute maximumOutputPower : Power_W = 1200.0;
		attribute mass : Mass_kg = 5.5;

		port chargeIn : ElectricalPowerInputPort;
		port powerOut : ElectricalPowerOutputPort;
		port statusOut : BatteryStatusPort;

		perform action supplyPower : SupplyElectricalPower;
	}

	part def ClimbController {
		attribute controlLoopPeriod : Time_s = 0.02;
		attribute maximumAllowedSpeed : Speed_m_per_s = 0.60;
		attribute maximumAllowedAcceleration : Acceleration_m_per_s2 = 0.40;

		port operatorInterface : ClimberOperatorInterfacePort;
		port batteryStatusIn : BatteryStatusPort;
		port leftAnchorCommandOut : ControlCommandOutputPort;
		port rightAnchorCommandOut : ControlCommandOutputPort;
		port winchCommandOut : ControlCommandOutputPort;
		port tetherCommandOut : ControlCommandOutputPort;
		port statusOut : StatusOutputPort;

		perform action computePlan : ComputeClimbPlan;
		perform action monitorSafety : MonitorSafety;
	}

	part def SurfaceSensorSuite {
		attribute sensingRange : Length_m = 0.20;
		attribute updatePeriod : Time_s = 0.05;

		port leftSurfaceIn : SurfaceProviderPort;
		port rightSurfaceIn : SurfaceProviderPort;
		port statusOut : StatusOutputPort;
	}

	part def AnchorGripper {
		attribute maximumAttachmentForce : Force_N = 1800.0;
		attribute minimumRequiredAttachmentForce : Force_N = 1500.0;
		attribute engagementTime : Time_s = 0.8;
		attribute mass : Mass_kg = 2.2;

		port commandIn : ControlCommandInputPort;
		port powerIn : ElectricalPowerInputPort;
		port anchorInterface : AnchorInterfacePort;

		perform action engage : EngageAnchor;
	}

	part def WinchDrive {
		attribute ratedLiftForce : Force_N = 1600.0;
		attribute maximumLiftSpeed : Speed_m_per_s = 0.60;
		attribute motorPower : Power_W = 900.0;
		attribute spoolRadius : Length_m = 0.06;
		attribute mass : Mass_kg = 4.8;

		port commandIn : ControlCommandInputPort;
		port powerIn : ElectricalPowerInputPort;
		port motionOut : MotionPort;

		perform action driveMotion : DriveVerticalMotion;
	}

	part def SafetyTetherSubsystem {
		attribute maximumTetherLoad : Force_N = 2200.0;
		attribute minimumHoldTension : Force_N = 200.0;
		attribute maximumTetherLength : Length_m = 30.0;
		attribute brakeEngagementTime : Time_s = 0.15;
		attribute mass : Mass_kg = 3.0;

		port commandIn : ControlCommandInputPort;
		port tetherInterface : TetherPort;

		perform action regulateTether : RegulateTether;
	}

	part def OperatorHarness {
		attribute harnessMass : Mass_kg = 1.6;
		attribute ratedHarnessLoad : Force_N = 2200.0;

		port tetherInterface : TetherPort;
		port motionInterface : MotionPort;
	}

	part def Climber {
		attribute ratedPayload : Mass_kg = 120.0;
		attribute systemMass : Mass_kg = 27.0;
		attribute maximumVerticalSpeed : Speed_m_per_s = 0.60;
		attribute nominalVerticalSpeed : Speed_m_per_s = 0.35;
		attribute minimumAttachmentForce : Force_N = 1500.0;
		attribute maximumSupportedHeight : Length_m = 30.0;
		attribute minimumBatteryEnergyForClimb : Energy_Wh = 180.0;

		port operatorInterface : ClimberOperatorInterfacePort;
		port chargePort : ElectricalPowerInputPort;
		port leftAnchor : AnchorInterfacePort;
		port rightAnchor : AnchorInterfacePort;
		port tetherPort : TetherPort;
		port motionPort : MotionPort;

		part frame : Frame;
		part battery : BatteryPack;
		part controller : ClimbController;
		part sensorSuite : SurfaceSensorSuite;
		part leftGripper : AnchorGripper;
		part rightGripper : AnchorGripper;
		part winch : WinchDrive;
		part tether : SafetyTetherSubsystem;
		part harness : OperatorHarness;

		connect chargePort to battery.chargeIn;
		connect battery.powerOut to controller.operatorInterface;
		connect battery.powerOut to leftGripper.powerIn;
		connect battery.powerOut to rightGripper.powerIn;
		connect battery.powerOut to winch.powerIn;
		connect battery.statusOut to controller.batteryStatusIn;
		connect operatorInterface to controller.operatorInterface;
		connect controller.leftAnchorCommandOut to leftGripper.commandIn;
		connect controller.rightAnchorCommandOut to rightGripper.commandIn;
		connect controller.winchCommandOut to winch.commandIn;
		connect controller.tetherCommandOut to tether.commandIn;
		connect leftAnchor to leftGripper.anchorInterface;
		connect rightAnchor to rightGripper.anchorInterface;
		connect tether.tetherInterface to harness.tetherInterface;
		connect harness.tetherInterface to tetherPort;
		connect winch.motionOut to harness.motionInterface;
		connect winch.motionOut to motionPort;

		perform action primaryFunction : TransportClimberVertically;
		perform action holdPosition : HoldClimberStationary;
		perform action emergencyStop : ExecuteEmergencyStop;

		exhibit state operatingStates : ClimberOperatingStates;
	}

	part def Operator {
		attribute totalMass : Mass_kg = 85.0;

		port console : OperatorConsolePort;

		perform action commandClimb : ReadOperatorCommand;
	}

	part def ClimbingRoute {
		attribute routeHeight : Length_m = 20.0;
		attribute averageSlope : Angle_deg = 90.0;
		attribute allowableSurfaceLoad : Force_N = 3000.0;

		port leftSurface : SurfaceProviderPort;
		port rightSurface : SurfaceProviderPort;
	}

	part def ChargingSupply {
		attribute outputVoltage : Voltage_V = 48.0;
		attribute maximumOutputCurrent : Current_A = 10.0;
		attribute maximumOutputPower : Power_W = 480.0;

		port powerOut : ElectricalPowerOutputPort;
	}

	part def ClimberMission {
		part operator : Operator;
		part route : ClimbingRoute;
		part climber : Climber;
		part charger : ChargingSupply;

		connect operator.console to climber.operatorInterface;
		connect route.leftSurface to climber.leftAnchor;
		connect route.rightSurface to climber.rightAnchor;
		connect charger.powerOut to climber.chargePort;
	}

	constraint def PayloadWithinCapacity {
		in payloadMass : Mass_kg;
		in ratedPayload : Mass_kg;

		constraint {
			payloadMass <= ratedPayload
		}
	}

	constraint def AttachmentForceAdequate {
		in attachmentForce : Force_N;
		in minimumAttachmentForce : Force_N;

		constraint {
			attachmentForce >= minimumAttachmentForce
		}
	}

	constraint def SafeSpeedEnvelope {
		in commandedSpeed : Speed_m_per_s;
		in maximumVerticalSpeed : Speed_m_per_s;

		constraint {
			commandedSpeed <= maximumVerticalSpeed
		}
	}

	requirement def PrimaryFunctionRequirement {
		subject climber : Climber;

		require constraint {
			climber.ratedPayload >= 100.0 and
			climber.maximumVerticalSpeed >= 0.25 and
			climber.maximumSupportedHeight >= 10.0 and
			climber.minimumAttachmentForce >= 1500.0
		}
	}

	requirement def SafetyHoldingRequirement {
		subject climber : Climber;

		require constraint {
			climber.minimumAttachmentForce >= 1500.0 and
			climber.ratedPayload <= 120.0
		}
	}

	requirement def EnergyAvailabilityRequirement {
		subject climber : Climber;

		require constraint {
			climber.minimumBatteryEnergyForClimb >= 180.0
		}
	}

	part personalVerticalClimber : Climber;

	part demonstrationMission : ClimberMission;

	requirement primaryFunction : PrimaryFunctionRequirement {
		subject climber = personalVerticalClimber;
	}

	requirement safeHolding : SafetyHoldingRequirement {
		subject climber = personalVerticalClimber;
	}

	requirement energyAvailability : EnergyAvailabilityRequirement {
		subject climber = personalVerticalClimber;
	}

	satisfy primaryFunction by personalVerticalClimber;
	satisfy safeHolding by personalVerticalClimber;
	satisfy energyAvailability by personalVerticalClimber;
}
