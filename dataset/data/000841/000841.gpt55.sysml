package AirPumpPumpingSubsystemModel {

	import ScalarValues::*;
	import SI::*;

	attribute def Pressure :> Real;
	attribute def DifferentialPressure :> Real;
	attribute def VolumetricFlowRate :> Real;
	attribute def MassFlowRate :> Real;
	attribute def Temperature :> Real;
	attribute def MassDensity :> Real;
	attribute def DynamicViscosity :> Real;
	attribute def ElectricalVoltage :> Real;
	attribute def ElectricalCurrent :> Real;
	attribute def ElectricalPower :> Real;
	attribute def RotationalSpeed :> Real;
	attribute def TimeDuration :> Real;
	attribute def Length :> Real;
	attribute def Efficiency :> Real;
	attribute def Fraction :> Real;

	enum def PumpOperatingMode {
		enum off;
		enum standby;
		enum priming;
		enum running;
		enum regulating;
		enum faulted;
		enum shutdown;
	}

	enum def ValvePosition {
		enum closed;
		enum open;
		enum modulating;
	}

	enum def FaultCode {
		enum noFault;
		enum lowInletPressure;
		enum highOutletPressure;
		enum blockedFilter;
		enum motorOvercurrent;
		enum sensorFailure;
		enum leakDetected;
		enum overTemperature;
	}

	enum def CommandKind {
		enum start;
		enum stop;
		enum reset;
		enum setFlow;
	}

	item def Fluid {
		attribute density: MassDensity = 1.20 [kg/m^3];
		attribute dynamicViscosity: DynamicViscosity = 0.0000181 [Pa*s];
		attribute temperature: Temperature = 293.15 [K];
		attribute absolutePressure: Pressure = 101325.0 [Pa];
	}

	item def Air :> Fluid {
		attribute oxygenVolumeFraction: Fraction = 0.2095;
		attribute nitrogenVolumeFraction: Fraction = 0.7808;
		attribute argonVolumeFraction: Fraction = 0.0093;
		attribute carbonDioxideVolumeFraction: Fraction = 0.0004;
		attribute relativeHumidity: Fraction = 0.50;
	}

	item def ElectricalEnergy {
		attribute voltage: ElectricalVoltage = 24.0 [V];
		attribute current: ElectricalCurrent = 0.0 [A];
		attribute power: ElectricalPower = 0.0 [W];
	}

	item def PumpCommand {
		attribute kind: CommandKind;
		attribute requestedFlow: VolumetricFlowRate = 0.0015 [m^3/s];
		attribute requestedOutletPressure: Pressure = 130000.0 [Pa];
	}

	item def PumpStatus {
		attribute mode: PumpOperatingMode = PumpOperatingMode::off;
		attribute measuredFlow: VolumetricFlowRate = 0.0 [m^3/s];
		attribute inletPressure: Pressure = 101325.0 [Pa];
		attribute outletPressure: Pressure = 101325.0 [Pa];
		attribute motorSpeed: RotationalSpeed = 0.0 [1/s];
		attribute fault: FaultCode = FaultCode::noFault;
	}

	port def FluidPort {
		inout item fluid: Fluid;
		attribute pressure: Pressure = 101325.0 [Pa];
		attribute temperature: Temperature = 293.15 [K];
		attribute volumetricFlowRate: VolumetricFlowRate = 0.0 [m^3/s];
	}

	port def AirPort :> FluidPort {
		inout item air: Air;
	}

	port def ElectricalPowerPort {
		in item supply: ElectricalEnergy;
		attribute voltage: ElectricalVoltage = 24.0 [V];
		attribute current: ElectricalCurrent = 0.0 [A];
		attribute power: ElectricalPower = 0.0 [W];
	}

	port def CommandPort {
		in item command: PumpCommand;
	}

	port def StatusPort {
		out item status: PumpStatus;
	}

	port def SensorOutputPort {
		out attribute measuredPressure: Pressure = 101325.0 [Pa];
		out attribute measuredFlow: VolumetricFlowRate = 0.0 [m^3/s];
		out attribute measuredTemperature: Temperature = 293.15 [K];
	}

	port def ActuatorCommandPort {
		in attribute motorSpeedCommand: RotationalSpeed = 0.0 [1/s];
		in attribute valveCommand: ValvePosition = ValvePosition::closed;
	}

	constraint def PressureRiseConstraint {
		in inletPressure: Pressure;
		in outletPressure: Pressure;
		in minimumPressureRise: DifferentialPressure;
		constraint { outletPressure - inletPressure >= minimumPressureRise }
	}

	constraint def FlowCapacityConstraint {
		in deliveredFlow: VolumetricFlowRate;
		in minimumFlow: VolumetricFlowRate;
		constraint { deliveredFlow >= minimumFlow }
	}

	constraint def MotorPowerConstraint {
		in inletPressure: Pressure;
		in outletPressure: Pressure;
		in flow: VolumetricFlowRate;
		in efficiency: Efficiency;
		in electricalPower: ElectricalPower;
		constraint { electricalPower * efficiency >= (outletPressure - inletPressure) * flow }
	}

	constraint def SafePressureConstraint {
		in outletPressure: Pressure;
		in maximumAllowablePressure: Pressure;
		constraint { outletPressure <= maximumAllowablePressure }
	}

	action def IntakeAir {
		in item upstreamAir: Air;
		out item chamberAir: Air;
		in inletPressure: Pressure;
		out intakeFlow: VolumetricFlowRate;
	}

	action def CompressAndDisplaceAir {
		in item chamberAir: Air;
		out item pressurizedAir: Air;
		in motorSpeed: RotationalSpeed;
		in inletPressure: Pressure;
		out outletPressure: Pressure;
		out deliveredFlow: VolumetricFlowRate;
	}

	action def ExhaustAirToDischarge {
		in item pressurizedAir: Air;
		out item downstreamAir: Air;
		in outletPressure: Pressure;
		out dischargeFlow: VolumetricFlowRate;
	}

	action def RegulateAirPump {
		in requestedFlow: VolumetricFlowRate;
		in measuredFlow: VolumetricFlowRate;
		in measuredOutletPressure: Pressure;
		out commandedMotorSpeed: RotationalSpeed;
		out commandedValvePosition: ValvePosition;
	}

	state def AirPumpStateMachine {
		entry; then Off;

		state Off;
		state Standby;
		state Priming;
		state Running;
		state Regulating;
		state Faulted;
		state Shutdown;

		transition Off_to_Standby
			first Off
			accept PumpCommand
			if command.kind == CommandKind::start
			then Standby;

		transition Standby_to_Priming
			first Standby
			if status.inletPressure >= 90000.0 [Pa]
			then Priming;

		transition Priming_to_Running
			first Priming
			if status.measuredFlow > 0.0002 [m^3/s]
			then Running;

		transition Running_to_Regulating
			first Running
			if status.measuredFlow != command.requestedFlow
			then Regulating;

		transition Regulating_to_Running
			first Regulating
			if status.measuredFlow >= command.requestedFlow * 0.95 and status.measuredFlow <= command.requestedFlow * 1.05
			then Running;

		transition Running_to_Shutdown
			first Running
			accept PumpCommand
			if command.kind == CommandKind::stop
			then Shutdown;

		transition Regulating_to_Shutdown
			first Regulating
			accept PumpCommand
			if command.kind == CommandKind::stop
			then Shutdown;

		transition Any_to_Faulted_from_LowInlet
			first Running
			if status.inletPressure < 85000.0 [Pa]
			then Faulted;

		transition Any_to_Faulted_from_HighOutlet
			first Running
			if status.outletPressure > 160000.0 [Pa]
			then Faulted;

		transition Faulted_to_Standby
			first Faulted
			accept PumpCommand
			if command.kind == CommandKind::reset
			then Standby;

		transition Shutdown_to_Off
			first Shutdown
			if status.motorSpeed == 0.0 [1/s]
			then Off;
	}

	part def PipeSegment {
		port inlet: AirPort;
		port outlet: AirPort;
		attribute insideDiameter: Length = 0.025 [m];
		attribute length: Length = 1.00 [m];
		attribute pressureDrop: DifferentialPressure = 100.0 [Pa];
		attribute leakageRate: VolumetricFlowRate = 0.0 [m^3/s];
	}

	part def AirFilter {
		port inlet: AirPort;
		port outlet: AirPort;
		attribute nominalPoreSize: Length = 0.000005 [m];
		attribute cleanPressureDrop: DifferentialPressure = 250.0 [Pa];
		attribute maximumPressureDrop: DifferentialPressure = 2500.0 [Pa];
		attribute retainedParticleEfficiency: Efficiency = 0.95;
		attribute cloggingFraction: Fraction = 0.0;
	}

	part def CheckValve {
		port inlet: AirPort;
		port outlet: AirPort;
		attribute crackingPressure: DifferentialPressure = 500.0 [Pa];
		attribute reverseLeakageRate: VolumetricFlowRate = 0.000001 [m^3/s];
		attribute position: ValvePosition = ValvePosition::closed;
	}

	part def ReliefValve {
		port inlet: AirPort;
		port outlet: AirPort;
		attribute setPressure: Pressure = 155000.0 [Pa];
		attribute reseatPressure: Pressure = 145000.0 [Pa];
		attribute position: ValvePosition = ValvePosition::closed;
	}

	part def IsolationValve {
		port inlet: AirPort;
		port outlet: AirPort;
		port actuator: ActuatorCommandPort;
		attribute position: ValvePosition = ValvePosition::closed;
		attribute fullOpenPressureDrop: DifferentialPressure = 80.0 [Pa];
	}

	part def PulsationDampener {
		port inlet: AirPort;
		port outlet: AirPort;
		attribute internalVolume: Real = 0.002 [m^3];
		attribute dampingRatio: Fraction = 0.70;
		attribute maximumPressure: Pressure = 160000.0 [Pa];
	}

	part def PressureSensor {
		port sensedPort: AirPort;
		port output: SensorOutputPort;
		attribute rangeMinimum: Pressure = 80000.0 [Pa];
		attribute rangeMaximum: Pressure = 170000.0 [Pa];
		attribute accuracy: DifferentialPressure = 250.0 [Pa];
		attribute samplePeriod: TimeDuration = 0.05 [s];
	}

	part def FlowSensor {
		port sensedPort: AirPort;
		port output: SensorOutputPort;
		attribute rangeMinimum: VolumetricFlowRate = 0.0 [m^3/s];
		attribute rangeMaximum: VolumetricFlowRate = 0.0030 [m^3/s];
		attribute accuracy: VolumetricFlowRate = 0.00003 [m^3/s];
		attribute samplePeriod: TimeDuration = 0.05 [s];
	}

	part def ElectricMotor {
		port powerIn: ElectricalPowerPort;
		port commandIn: ActuatorCommandPort;
		attribute nominalVoltage: ElectricalVoltage = 24.0 [V];
		attribute maximumCurrent: ElectricalCurrent = 8.0 [A];
		attribute ratedPower: ElectricalPower = 120.0 [W];
		attribute speed: RotationalSpeed = 0.0 [1/s];
		attribute maximumSpeed: RotationalSpeed = 120.0 [1/s];
		attribute efficiency: Efficiency = 0.82;
	}

	part def AirPumpHead {
		port inlet: AirPort;
		port outlet: AirPort;
		attribute sweptVolumePerCycle: Real = 0.000025 [m^3];
		attribute volumetricEfficiency: Efficiency = 0.78;
		attribute maximumOutletPressure: Pressure = 160000.0 [Pa];
		attribute minimumInletPressure: Pressure = 85000.0 [Pa];

		perform action intake: IntakeAir;
		perform action compress: CompressAndDisplaceAir;
		perform action exhaust: ExhaustAirToDischarge;
	}

	part def AirPump {
		port inlet: AirPort;
		port outlet: AirPort;
		port powerIn: ElectricalPowerPort;
		port controlIn: ActuatorCommandPort;
		port statusOut: StatusPort;

		part motor: ElectricMotor;
		part head: AirPumpHead;

		attribute ratedFlow: VolumetricFlowRate = 0.0018 [m^3/s];
		attribute minimumControllableFlow: VolumetricFlowRate = 0.00025 [m^3/s];
		attribute maximumOutletPressure: Pressure = 160000.0 [Pa];
		attribute nominalPressureRise: DifferentialPressure = 30000.0 [Pa];
		attribute overallEfficiency: Efficiency = 0.55;
		attribute mode: PumpOperatingMode = PumpOperatingMode::off;
		attribute fault: FaultCode = FaultCode::noFault;

		connect powerIn to motor.powerIn;
		connect controlIn to motor.commandIn;
		connect inlet to head.inlet;
		connect head.outlet to outlet;

		exhibit state behavior pumpStates: AirPumpStateMachine;

		assert constraint motorPowerLimit : MotorPowerConstraint {
			inletPressure = inlet.pressure;
			outletPressure = outlet.pressure;
			flow = outlet.volumetricFlowRate;
			efficiency = overallEfficiency;
			electricalPower = motor.powerIn.power;
		}

		assert constraint pumpPressureRise : PressureRiseConstraint {
			inletPressure = inlet.pressure;
			outletPressure = outlet.pressure;
			minimumPressureRise = 5000.0 [Pa];
		}
	}

	part def PumpController {
		port commandIn: CommandPort;
		port statusOut: StatusPort;
		port inletPressureIn: SensorOutputPort;
		port outletPressureIn: SensorOutputPort;
		port flowIn: SensorOutputPort;
		port pumpCommandOut: ActuatorCommandPort;
		port isolationValveCommandOut: ActuatorCommandPort;

		attribute requestedFlow: VolumetricFlowRate = 0.0015 [m^3/s];
		attribute requestedOutletPressure: Pressure = 130000.0 [Pa];
		attribute commandedMotorSpeed: RotationalSpeed = 0.0 [1/s];
		attribute mode: PumpOperatingMode = PumpOperatingMode::off;
		attribute activeFault: FaultCode = FaultCode::noFault;

		perform action regulate: RegulateAirPump;
	}

	part def AirPumpPumpingSubsystem {
		port fluidIn: AirPort;
		port fluidOut: AirPort;
		port powerIn: ElectricalPowerPort;
		port commandIn: CommandPort;
		port statusOut: StatusPort;
		port reliefExhaust: AirPort;

		part suctionLine: PipeSegment {
			attribute length = 0.75 [m];
			attribute insideDiameter = 0.025 [m];
		}

		part inletFilter: AirFilter {
			attribute nominalPoreSize = 0.000005 [m];
			attribute maximumPressureDrop = 2500.0 [Pa];
		}

		part inletCheckValve: CheckValve {
			attribute crackingPressure = 500.0 [Pa];
		}

		part inletPressureSensor: PressureSensor {
			attribute rangeMinimum = 80000.0 [Pa];
			attribute rangeMaximum = 140000.0 [Pa];
		}

		part pump: AirPump {
			attribute ratedFlow = 0.0018 [m^3/s];
			attribute maximumOutletPressure = 160000.0 [Pa];
			attribute nominalPressureRise = 30000.0 [Pa];
		}

		part dampener: PulsationDampener {
			attribute internalVolume = 0.002 [m^3];
			attribute dampingRatio = 0.70;
		}

		part outletCheckValve: CheckValve {
			attribute crackingPressure = 700.0 [Pa];
		}

		part outletPressureSensor: PressureSensor {
			attribute rangeMinimum = 90000.0 [Pa];
			attribute rangeMaximum = 170000.0 [Pa];
		}

		part flowSensor: FlowSensor {
			attribute rangeMaximum = 0.0030 [m^3/s];
		}

		part dischargeIsolationValve: IsolationValve {
			attribute position = ValvePosition::closed;
		}

		part dischargeLine: PipeSegment {
			attribute length = 1.25 [m];
			attribute insideDiameter = 0.025 [m];
		}

		part pressureReliefValve: ReliefValve {
			attribute setPressure = 155000.0 [Pa];
			attribute reseatPressure = 145000.0 [Pa];
		}

		part controller: PumpController;

		attribute deliveredFlow: VolumetricFlowRate = 0.0015 [m^3/s];
		attribute inletPressure: Pressure = 101325.0 [Pa];
		attribute outletPressure: Pressure = 130000.0 [Pa];
		attribute maximumAllowableOutletPressure: Pressure = 160000.0 [Pa];
		attribute minimumRequiredFlow: VolumetricFlowRate = 0.0012 [m^3/s];
		attribute nominalOperatingVoltage: ElectricalVoltage = 24.0 [V];
		attribute subsystemEfficiency: Efficiency = 0.48;

		connect fluidIn to suctionLine.inlet;
		connect suctionLine.outlet to inletFilter.inlet;
		connect inletFilter.outlet to inletCheckValve.inlet;
		connect inletCheckValve.outlet to inletPressureSensor.sensedPort;
		connect inletPressureSensor.sensedPort to pump.inlet;
		connect powerIn to pump.powerIn;
		connect commandIn to controller.commandIn;
		connect controller.pumpCommandOut to pump.controlIn;
		connect pump.outlet to dampener.inlet;
		connect dampener.outlet to outletCheckValve.inlet;
		connect outletCheckValve.outlet to outletPressureSensor.sensedPort;
		connect outletPressureSensor.sensedPort to flowSensor.sensedPort;
		connect flowSensor.sensedPort to dischargeIsolationValve.inlet;
		connect controller.isolationValveCommandOut to dischargeIsolationValve.actuator;
		connect dischargeIsolationValve.outlet to dischargeLine.inlet;
		connect dischargeLine.outlet to fluidOut;
		connect outletPressureSensor.sensedPort to pressureReliefValve.inlet;
		connect pressureReliefValve.outlet to reliefExhaust;
		connect inletPressureSensor.output to controller.inletPressureIn;
		connect outletPressureSensor.output to controller.outletPressureIn;
		connect flowSensor.output to controller.flowIn;
		connect controller.statusOut to statusOut;

		flow item transferredAir: Air from fluidIn to fluidOut;

		assert constraint requiredFlowCapability : FlowCapacityConstraint {
			deliveredFlow = deliveredFlow;
			minimumFlow = minimumRequiredFlow;
		}

		assert constraint safeOutletPressure : SafePressureConstraint {
			outletPressure = outletPressure;
			maximumAllowablePressure = maximumAllowableOutletPressure;
		}

		assert constraint availablePressureRise : PressureRiseConstraint {
			inletPressure = inletPressure;
			outletPressure = outletPressure;
			minimumPressureRise = 20000.0 [Pa];
		}
	}

	requirement def MoveFluidUsingAirPumpRequirement {
		subject subsystem: AirPumpPumpingSubsystem;
		require constraint { subsystem.pump.ratedFlow >= subsystem.minimumRequiredFlow }
	}

	requirement def AirAsPumpedFluidRequirement {
		subject subsystem: AirPumpPumpingSubsystem;
		require constraint { subsystem.fluidIn.fluid.density >= 0.90 [kg/m^3] and subsystem.fluidIn.fluid.density <= 1.40 [kg/m^3] }
	}

	requirement def ContinuousFlowRequirement {
		subject subsystem: AirPumpPumpingSubsystem;
		attribute requiredContinuousFlow: VolumetricFlowRate = 0.0012 [m^3/s];
		require constraint { subsystem.deliveredFlow >= requiredContinuousFlow }
	}

	requirement def OutletPressureRequirement {
		subject subsystem: AirPumpPumpingSubsystem;
		attribute minimumOutletPressure: Pressure = 125000.0 [Pa];
		attribute maximumOutletPressure: Pressure = 160000.0 [Pa];
		require constraint { subsystem.outletPressure >= minimumOutletPressure and subsystem.outletPressure <= maximumOutletPressure }
	}

	requirement def ElectricalSupplyRequirement {
		subject subsystem: AirPumpPumpingSubsystem;
		attribute requiredVoltage: ElectricalVoltage = 24.0 [V];
		attribute voltageTolerance: ElectricalVoltage = 2.0 [V];
		require constraint { subsystem.nominalOperatingVoltage >= requiredVoltage - voltageTolerance and subsystem.nominalOperatingVoltage <= requiredVoltage + voltageTolerance }
	}

	requirement def SafetyReliefRequirement {
		subject subsystem: AirPumpPumpingSubsystem;
		attribute reliefSetPressureLimit: Pressure = 155000.0 [Pa];
		require constraint { subsystem.pressureReliefValve.setPressure <= reliefSetPressureLimit }
	}

	requirement def ReverseFlowPreventionRequirement {
		subject subsystem: AirPumpPumpingSubsystem;
		require constraint { subsystem.inletCheckValve.reverseLeakageRate <= 0.000001 [m^3/s] and subsystem.outletCheckValve.reverseLeakageRate <= 0.000001 [m^3/s] }
	}

	part operationalAirPumpingSubsystem: AirPumpPumpingSubsystem {
		attribute deliveredFlow = 0.0015 [m^3/s];
		attribute inletPressure = 101325.0 [Pa];
		attribute outletPressure = 130000.0 [Pa];
		attribute minimumRequiredFlow = 0.0012 [m^3/s];
		attribute nominalOperatingVoltage = 24.0 [V];
	}

	requirement moveFluidUsingAirPump: MoveFluidUsingAirPumpRequirement {
		subject subsystem = operationalAirPumpingSubsystem;
	}

	requirement pumpedFluidIsAir: AirAsPumpedFluidRequirement {
		subject subsystem = operationalAirPumpingSubsystem;
	}

	requirement continuousFlow: ContinuousFlowRequirement {
		subject subsystem = operationalAirPumpingSubsystem;
	}

	requirement outletPressureControlled: OutletPressureRequirement {
		subject subsystem = operationalAirPumpingSubsystem;
	}

	requirement electricalSupply: ElectricalSupplyRequirement {
		subject subsystem = operationalAirPumpingSubsystem;
	}

	requirement reliefProtection: SafetyReliefRequirement {
		subject subsystem = operationalAirPumpingSubsystem;
	}

	requirement reverseFlowPrevented: ReverseFlowPreventionRequirement {
		subject subsystem = operationalAirPumpingSubsystem;
	}

	satisfy moveFluidUsingAirPump by operationalAirPumpingSubsystem.pump;
	satisfy pumpedFluidIsAir by operationalAirPumpingSubsystem;
	satisfy continuousFlow by operationalAirPumpingSubsystem.pump;
	satisfy outletPressureControlled by operationalAirPumpingSubsystem.controller;
	satisfy electricalSupply by operationalAirPumpingSubsystem.pump.motor;
	satisfy reliefProtection by operationalAirPumpingSubsystem.pressureReliefValve;
	satisfy reverseFlowPrevented by operationalAirPumpingSubsystem.inletCheckValve;
	satisfy reverseFlowPrevented by operationalAirPumpingSubsystem.outletCheckValve;
}
