package HydraulicPumpingSubsystemModel {
	import ScalarValues::*;
	import SI::*;

	attribute def PressureValue :> Real;
	attribute def VolumeFlowRateValue :> Real;
	attribute def TemperatureValue :> Real;
	attribute def DensityValue :> Real;
	attribute def DynamicViscosityValue :> Real;
	attribute def PowerValue :> Real;
	attribute def VoltageValue :> Real;
	attribute def CurrentValue :> Real;
	attribute def TorqueValue :> Real;
	attribute def RotationalSpeedValue :> Real;
	attribute def VolumeValue :> Real;
	attribute def LengthValue :> Real;
	attribute def EfficiencyValue :> Real;
	attribute def TimeValue :> Real;

	item def HydraulicFluid {
		attribute density : DensityValue = 860 [kg/m^3];
		attribute dynamicViscosity : DynamicViscosityValue = 0.046 [Pa*s];
		attribute nominalTemperature : TemperatureValue = 313 [K];
	}

	item def PressurizedHydraulicFluid :> HydraulicFluid {
		attribute minimumServicePressure : PressureValue = 10000000 [Pa];
		attribute maximumServicePressure : PressureValue = 16000000 [Pa];
	}

	item def ElectricalPower {
		attribute voltage : VoltageValue = 48 [V];
		attribute current : CurrentValue;
		attribute power : PowerValue;
	}

	item def RotationalPower {
		attribute torque : TorqueValue;
		attribute speed : RotationalSpeedValue;
		attribute power : PowerValue;
	}

	item def StartCommand;
	item def StopCommand;
	item def ResetCommand;

	item def PumpTelemetry {
		attribute suctionPressure : PressureValue;
		attribute dischargePressure : PressureValue;
		attribute deliveredFlowRate : VolumeFlowRateValue;
		attribute motorSpeed : RotationalSpeedValue;
		attribute fluidTemperature : TemperatureValue;
		attribute faultActive : Boolean;
	}

	item def FaultReport {
		attribute lowSuctionPressure : Boolean;
		attribute highDischargePressure : Boolean;
		attribute lowFlow : Boolean;
		attribute overTemperature : Boolean;
	}

	port def HydraulicFluidPort {
		inout item fluid : HydraulicFluid;
		attribute pressure : PressureValue;
		attribute flowRate : VolumeFlowRateValue;
		attribute temperature : TemperatureValue;
	}

	port def ElectricalPowerPort {
		inout item electricalPower : ElectricalPower;
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
	}

	port def MechanicalShaftPort {
		inout item shaftPower : RotationalPower;
		attribute torque : TorqueValue;
		attribute speed : RotationalSpeedValue;
	}

	port def CommandPort {
		inout item start : StartCommand;
		inout item stop : StopCommand;
		inout item reset : ResetCommand;
	}

	port def TelemetryPort {
		inout item telemetry : PumpTelemetry;
		inout item fault : FaultReport;
	}

	action def PrimePumpAction {
		in item inletFluid : HydraulicFluid;
		out item primedFluid : HydraulicFluid;
		in primingTime : TimeValue;
		out suctionPressure : PressureValue;
	}

	action def PumpFluidAction {
		in item inletFluid : HydraulicFluid;
		in shaftSpeed : RotationalSpeedValue;
		in inletPressure : PressureValue;
		out item outletFluid : PressurizedHydraulicFluid;
		out dischargePressure : PressureValue;
		out deliveredFlowRate : VolumeFlowRateValue;
		attribute pressureGain : PressureValue = 12000000 [Pa];
		attribute minimumDeliveredFlowRate : VolumeFlowRateValue = 0.002 [m^3/s];
	}

	action def RegulatePressureAction {
		in measuredPressure : PressureValue;
		in commandedPressure : PressureValue;
		out motorSpeedCommand : RotationalSpeedValue;
		out reliefValveOpen : Boolean;
	}

	action def StopPumpAction {
		in item fluid : HydraulicFluid;
		out stopped : Boolean;
		out residualPressure : PressureValue;
	}

	state def PumpOperatingStateMachine {
		entry; then off;

		state off;
		state standby;
		state priming;
		state running;
		state pressureRegulating;
		state stopping;
		state faulted;

		transition off_to_standby
			first off
			accept reset : ResetCommand
			then standby;

		transition standby_to_priming
			first standby
			accept start : StartCommand
			then priming;

		transition priming_to_running
			first priming
			then running;

		transition running_to_regulating
			first running
			then pressureRegulating;

		transition regulating_to_running
			first pressureRegulating
			then running;

		transition running_to_stopping
			first running
			accept stop : StopCommand
			then stopping;

		transition regulating_to_stopping
			first pressureRegulating
			accept stop : StopCommand
			then stopping;

		transition stopping_to_standby
			first stopping
			then standby;

		transition running_to_faulted
			first running
			then faulted;

		transition regulating_to_faulted
			first pressureRegulating
			then faulted;

		transition faulted_to_standby
			first faulted
			accept reset : ResetCommand
			then standby;
	}

	part def Reservoir {
		port fillDrainPort : HydraulicFluidPort;
		port outletPort : HydraulicFluidPort;
		port returnPort : HydraulicFluidPort;
		port ventPort : HydraulicFluidPort;

		attribute usableVolume : VolumeValue = 0.025 [m^3];
		attribute minimumFluidVolume : VolumeValue = 0.005 [m^3];
		attribute normalFluidTemperature : TemperatureValue = 313 [K];
		attribute maximumFluidTemperature : TemperatureValue = 353 [K];
	}

	part def SuctionFilter {
		port inlet : HydraulicFluidPort;
		port outlet : HydraulicFluidPort;

		attribute micronRating : LengthValue = 10 [um];
		attribute cleanPressureDrop : PressureValue = 15000 [Pa];
		attribute cloggedPressureDropLimit : PressureValue = 60000 [Pa];
		attribute ratedFlowRate : VolumeFlowRateValue = 0.003 [m^3/s];
	}

	part def ElectricMotor {
		port powerIn : ElectricalPowerPort;
		port shaftOut : MechanicalShaftPort;
		port commandIn : CommandPort;
		port telemetryOut : TelemetryPort;

		attribute ratedPower : PowerValue = 3500 [W];
		attribute ratedVoltage : VoltageValue = 48 [V];
		attribute ratedCurrent : CurrentValue = 80 [A];
		attribute ratedSpeed : RotationalSpeedValue = 314 [rad/s];
		attribute ratedTorque : TorqueValue = 11.1 [N*m];
		attribute efficiency : EfficiencyValue = 0.90;

		perform action regulateSpeed : RegulatePressureAction;
	}

	part def HydraulicPump {
		port suction : HydraulicFluidPort;
		port discharge : HydraulicFluidPort;
		port shaftIn : MechanicalShaftPort;
		port caseDrain : HydraulicFluidPort;

		attribute displacement : VolumeValue = 0.00001 [m^3];
		attribute ratedSpeed : RotationalSpeedValue = 314 [rad/s];
		attribute nominalFlowRate : VolumeFlowRateValue = 0.003 [m^3/s];
		attribute maximumDischargePressure : PressureValue = 16000000 [Pa];
		attribute minimumSuctionPressure : PressureValue = 80000 [Pa];
		attribute volumetricEfficiency : EfficiencyValue = 0.92;
		attribute mechanicalEfficiency : EfficiencyValue = 0.88;

		perform action pumpFluid : PumpFluidAction;
	}

	part def CheckValve {
		port inlet : HydraulicFluidPort;
		port outlet : HydraulicFluidPort;

		attribute crackingPressure : PressureValue = 50000 [Pa];
		attribute reverseLeakageFlowLimit : VolumeFlowRateValue = 0.000001 [m^3/s];
		attribute ratedPressure : PressureValue = 20000000 [Pa];
	}

	part def ReliefValve {
		port inlet : HydraulicFluidPort;
		port outlet : HydraulicFluidPort;

		attribute crackingPressure : PressureValue = 15500000 [Pa];
		attribute fullOpenPressure : PressureValue = 16500000 [Pa];
		attribute bypassFlowCapacity : VolumeFlowRateValue = 0.004 [m^3/s];

		perform action regulatePressure : RegulatePressureAction;
	}

	part def FlowSensor {
		port inlet : HydraulicFluidPort;
		port outlet : HydraulicFluidPort;
		port telemetryOut : TelemetryPort;

		attribute measurementRange : VolumeFlowRateValue = 0.005 [m^3/s];
		attribute accuracy : EfficiencyValue = 0.02;
		attribute responseTime : TimeValue = 0.05 [s];
	}

	part def PressureSensor {
		port processPort : HydraulicFluidPort;
		port telemetryOut : TelemetryPort;

		attribute measurementRange : PressureValue = 20000000 [Pa];
		attribute accuracy : EfficiencyValue = 0.01;
		attribute responseTime : TimeValue = 0.02 [s];
	}

	part def TemperatureSensor {
		port processPort : HydraulicFluidPort;
		port telemetryOut : TelemetryPort;

		attribute measurementRange : TemperatureValue = 400 [K];
		attribute accuracy : TemperatureValue = 1 [K];
		attribute responseTime : TimeValue = 0.2 [s];
	}

	part def HydraulicManifold {
		port inlet : HydraulicFluidPort;
		port serviceOutlet : HydraulicFluidPort;
		port reliefOutlet : HydraulicFluidPort;
		port instrumentPort : HydraulicFluidPort;

		attribute ratedPressure : PressureValue = 20000000 [Pa];
		attribute internalPressureDrop : PressureValue = 25000 [Pa];
	}

	part def PumpController {
		port commandIn : CommandPort;
		port motorCommandOut : CommandPort;
		port motorTelemetryIn : TelemetryPort;
		port suctionPressureIn : TelemetryPort;
		port dischargePressureIn : TelemetryPort;
		port flowTelemetryIn : TelemetryPort;
		port temperatureTelemetryIn : TelemetryPort;
		port telemetryOut : TelemetryPort;

		attribute commandedPressure : PressureValue = 12000000 [Pa];
		attribute lowSuctionPressureTrip : PressureValue = 70000 [Pa];
		attribute highDischargePressureTrip : PressureValue = 17000000 [Pa];
		attribute lowFlowTrip : VolumeFlowRateValue = 0.0015 [m^3/s];
		attribute overTemperatureTrip : TemperatureValue = 353 [K];

		perform action regulatePressure : RegulatePressureAction;
		perform action operatingMode : PumpOperatingStateMachine;
	}

	part def PumpingSubsystem {
		port fluidIn : HydraulicFluidPort;
		port fluidOut : HydraulicFluidPort;
		port powerIn : ElectricalPowerPort;
		port commandIn : CommandPort;
		port telemetryOut : TelemetryPort;

		attribute ratedFlowRate : VolumeFlowRateValue = 0.003 [m^3/s];
		attribute minimumContinuousFlowRate : VolumeFlowRateValue = 0.002 [m^3/s];
		attribute ratedOutletPressure : PressureValue = 12000000 [Pa];
		attribute maximumOutletPressure : PressureValue = 16000000 [Pa];
		attribute minimumInletPressure : PressureValue = 80000 [Pa];
		attribute maximumFluidTemperature : TemperatureValue = 353 [K];

		part reservoir : Reservoir;
		part suctionFilter : SuctionFilter;
		part motor : ElectricMotor;
		part pump : HydraulicPump;
		part dischargeManifold : HydraulicManifold;
		part outletCheckValve : CheckValve;
		part reliefValve : ReliefValve;
		part flowSensor : FlowSensor;
		part suctionPressureSensor : PressureSensor;
		part dischargePressureSensor : PressureSensor;
		part temperatureSensor : TemperatureSensor;
		part controller : PumpController;

		connection external_suction_to_reservoir connect fluidIn to reservoir.fillDrainPort;
		connection reservoir_to_filter connect reservoir.outletPort to suctionFilter.inlet;
		connection filter_to_pump_suction connect suctionFilter.outlet to pump.suction;
		connection pump_discharge_to_manifold connect pump.discharge to dischargeManifold.inlet;
		connection manifold_to_check_valve connect dischargeManifold.serviceOutlet to outletCheckValve.inlet;
		connection check_valve_to_flow_sensor connect outletCheckValve.outlet to flowSensor.inlet;
		connection flow_sensor_to_external_outlet connect flowSensor.outlet to fluidOut;
		connection manifold_to_relief_valve connect dischargeManifold.reliefOutlet to reliefValve.inlet;
		connection relief_valve_to_reservoir_return connect reliefValve.outlet to reservoir.returnPort;
		connection pump_case_drain_to_reservoir connect pump.caseDrain to reservoir.returnPort;
		connection motor_shaft_to_pump_shaft connect motor.shaftOut to pump.shaftIn;
		connection external_power_to_motor connect powerIn to motor.powerIn;
		connection external_command_to_controller connect commandIn to controller.commandIn;
		connection controller_to_motor_command connect controller.motorCommandOut to motor.commandIn;
		connection suction_sensor_process connect suctionPressureSensor.processPort to suctionFilter.outlet;
		connection discharge_sensor_process connect dischargePressureSensor.processPort to dischargeManifold.instrumentPort;
		connection temperature_sensor_process connect temperatureSensor.processPort to reservoir.returnPort;
		connection motor_telemetry_to_controller connect motor.telemetryOut to controller.motorTelemetryIn;
		connection suction_pressure_to_controller connect suctionPressureSensor.telemetryOut to controller.suctionPressureIn;
		connection discharge_pressure_to_controller connect dischargePressureSensor.telemetryOut to controller.dischargePressureIn;
		connection flow_to_controller connect flowSensor.telemetryOut to controller.flowTelemetryIn;
		connection temperature_to_controller connect temperatureSensor.telemetryOut to controller.temperatureTelemetryIn;
		connection controller_telemetry_to_external connect controller.telemetryOut to telemetryOut;

		perform action prime : PrimePumpAction;
		perform action pumpFluid : PumpFluidAction;
		perform action stopPump : StopPumpAction;
		perform action operatingMode : PumpOperatingStateMachine;
	}

	requirement def FluidTransferRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.minimumContinuousFlowRate >= 0.002 [m^3/s] }
	}

	requirement def OutletPressureRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.ratedOutletPressure >= 12000000 [Pa] and subsystem.maximumOutletPressure <= 16000000 [Pa] }
	}

	requirement def SuctionProtectionRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.minimumInletPressure >= 80000 [Pa] }
	}

	requirement def ThermalOperatingRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.maximumFluidTemperature <= 353 [K] }
	}

	requirement def ReliefProtectionRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.reliefValve.crackingPressure <= 15500000 [Pa] and subsystem.reliefValve.fullOpenPressure <= 16500000 [Pa] }
	}

	requirement def FiltrationRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.suctionFilter.micronRating <= 10 [um] and subsystem.suctionFilter.ratedFlowRate >= subsystem.ratedFlowRate }
	}

	part hydraulicPumpingSubsystem : PumpingSubsystem;

	requirement fluidTransfer : FluidTransferRequirement {
		subject subsystem = hydraulicPumpingSubsystem;
	}

	requirement outletPressure : OutletPressureRequirement {
		subject subsystem = hydraulicPumpingSubsystem;
	}

	requirement suctionProtection : SuctionProtectionRequirement {
		subject subsystem = hydraulicPumpingSubsystem;
	}

	requirement thermalOperation : ThermalOperatingRequirement {
		subject subsystem = hydraulicPumpingSubsystem;
	}

	requirement reliefProtection : ReliefProtectionRequirement {
		subject subsystem = hydraulicPumpingSubsystem;
	}

	requirement filtration : FiltrationRequirement {
		subject subsystem = hydraulicPumpingSubsystem;
	}
}
