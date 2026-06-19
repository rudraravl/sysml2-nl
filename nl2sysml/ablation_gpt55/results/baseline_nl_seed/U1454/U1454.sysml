package MudPumpPumpingSubsystemModel {
	import ScalarValues::*;

	attribute def Pressure :> Real {
		attribute unitSymbol : String = "kPa";
	}

	attribute def Temperature :> Real {
		attribute unitSymbol : String = "degC";
	}

	attribute def VolumetricFlowRate :> Real {
		attribute unitSymbol : String = "m^3/s";
	}

	attribute def Volume :> Real {
		attribute unitSymbol : String = "m^3";
	}

	attribute def Density :> Real {
		attribute unitSymbol : String = "kg/m^3";
	}

	attribute def DynamicViscosity :> Real {
		attribute unitSymbol : String = "Pa*s";
	}

	attribute def Diameter :> Real {
		attribute unitSymbol : String = "m";
	}

	attribute def Length :> Real {
		attribute unitSymbol : String = "m";
	}

	attribute def Speed :> Real {
		attribute unitSymbol : String = "r/min";
	}

	attribute def Torque :> Real {
		attribute unitSymbol : String = "N*m";
	}

	attribute def Power :> Real {
		attribute unitSymbol : String = "kW";
	}

	attribute def Voltage :> Real {
		attribute unitSymbol : String = "V";
	}

	attribute def ElectricCurrent :> Real {
		attribute unitSymbol : String = "A";
	}

	attribute def TimeDuration :> Real {
		attribute unitSymbol : String = "s";
	}

	attribute def Acceleration :> Real {
		attribute unitSymbol : String = "m/s^2";
	}

	attribute def Mass :> Real {
		attribute unitSymbol : String = "kg";
	}

	attribute def StrokeLength :> Real {
		attribute unitSymbol : String = "m";
	}

	attribute def StrokeRate :> Real {
		attribute unitSymbol : String = "stroke/min";
	}

	attribute def Percentage :> Real {
		attribute unitSymbol : String = "%";
	}

	attribute def VibrationLevel :> Real {
		attribute unitSymbol : String = "mm/s";
	}

	enum def ValvePosition {
		enum open;
		enum closed;
		enum throttling;
	}

	enum def PumpOperatingMode {
		enum shutdown;
		enum standby;
		enum priming;
		enum running;
		enum flushing;
		enum tripped;
	}

	enum def AlarmSeverity {
		enum normal;
		enum warning;
		enum shutdown;
	}

	item def DrillingMud {
		attribute density : Density = 1200.0;
		attribute plasticViscosity : DynamicViscosity = 0.035;
		attribute temperature : Temperature = 40.0;
		attribute solidsByVolume : Percentage = 18.0;
		attribute gasCutByVolume : Percentage = 0.0;
	}

	item def ElectricPower {
		attribute lineVoltage : Voltage = 690.0;
		attribute lineCurrent : ElectricCurrent = 0.0;
		attribute realPower : Power = 0.0;
		attribute frequency : Real = 60.0;
	}

	item def MechanicalRotation {
		attribute rotationalSpeed : Speed = 0.0;
		attribute transmittedTorque : Torque = 0.0;
		attribute transmittedPower : Power = 0.0;
	}

	item def PumpCommand {
		attribute requestedMode : PumpOperatingMode = PumpOperatingMode::standby;
		attribute requestedFlowRate : VolumetricFlowRate = 0.0;
		attribute requestedStrokeRate : StrokeRate = 0.0;
		attribute emergencyStop : Boolean = false;
	}

	item def PumpStatus {
		attribute actualMode : PumpOperatingMode = PumpOperatingMode::shutdown;
		attribute measuredFlowRate : VolumetricFlowRate = 0.0;
		attribute suctionPressure : Pressure = 0.0;
		attribute dischargePressure : Pressure = 0.0;
		attribute motorPower : Power = 0.0;
		attribute alarmSeverity : AlarmSeverity = AlarmSeverity::normal;
	}

	item def PressureSignal {
		attribute measuredPressure : Pressure = 0.0;
		attribute sensorHealthy : Boolean = true;
	}

	item def FlowSignal {
		attribute measuredFlowRate : VolumetricFlowRate = 0.0;
		attribute sensorHealthy : Boolean = true;
	}

	item def TemperatureSignal {
		attribute measuredTemperature : Temperature = 0.0;
		attribute sensorHealthy : Boolean = true;
	}

	port def FluidInletPort {
		in item mud : DrillingMud;
		attribute designPressure : Pressure = 35000.0;
		attribute portDiameter : Diameter = 0.1524;
	}

	port def FluidOutletPort {
		out item mud : DrillingMud;
		attribute designPressure : Pressure = 35000.0;
		attribute portDiameter : Diameter = 0.1270;
	}

	port def BidirectionalFlushPort {
		inout item mud : DrillingMud;
		attribute designPressure : Pressure = 3500.0;
		attribute portDiameter : Diameter = 0.0508;
	}

	port def ElectricPowerInPort {
		in item electricalPower : ElectricPower;
	}

	port def ElectricPowerOutPort {
		out item electricalPower : ElectricPower;
	}

	port def MechanicalPowerInPort {
		in item rotation : MechanicalRotation;
	}

	port def MechanicalPowerOutPort {
		out item rotation : MechanicalRotation;
	}

	port def CommandInPort {
		in item command : PumpCommand;
	}

	port def CommandOutPort {
		out item command : PumpCommand;
	}

	port def StatusInPort {
		in item status : PumpStatus;
	}

	port def StatusOutPort {
		out item status : PumpStatus;
	}

	port def PressureSignalOutPort {
		out item pressureSignal : PressureSignal;
	}

	port def PressureSignalInPort {
		in item pressureSignal : PressureSignal;
	}

	port def FlowSignalOutPort {
		out item flowSignal : FlowSignal;
	}

	port def FlowSignalInPort {
		in item flowSignal : FlowSignal;
	}

	port def TemperatureSignalOutPort {
		out item temperatureSignal : TemperatureSignal;
	}

	port def TemperatureSignalInPort {
		in item temperatureSignal : TemperatureSignal;
	}

	part def MudTank {
		port outlet : FluidOutletPort;
		port returnInlet : FluidInletPort;
		attribute workingVolume : Volume = 55.0;
		attribute minimumOperatingVolume : Volume = 12.0;
		attribute normalMudTemperature : Temperature = 40.0;
		attribute containedMudDensity : Density = 1200.0;
	}

	part def PipeSegment {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		attribute nominalDiameter : Diameter = 0.1524;
		attribute segmentLength : Length = 5.0;
		attribute designPressure : Pressure = 35000.0;
		attribute pressureDropAtRatedFlow : Pressure = 120.0;
	}

	part def IsolationValve {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		attribute position : ValvePosition = ValvePosition::open;
		attribute boreDiameter : Diameter = 0.1524;
		attribute designPressure : Pressure = 35000.0;
		attribute leakageRateWhenClosed : VolumetricFlowRate = 0.000001;
	}

	part def CheckValve {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		attribute crackingPressure : Pressure = 35.0;
		attribute designPressure : Pressure = 35000.0;
		attribute reverseLeakageRate : VolumetricFlowRate = 0.000002;
	}

	part def Strainer {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		attribute screenOpening : Diameter = 0.003;
		attribute cleanPressureDrop : Pressure = 20.0;
		attribute pluggedPressureDropLimit : Pressure = 250.0;
	}

	part def PulsationDampener {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		attribute prechargePressure : Pressure = 7000.0;
		attribute gasVolume : Volume = 0.18;
		attribute maximumAllowableWorkingPressure : Pressure = 35000.0;
		attribute residualPressureRipple : Percentage = 5.0;
	}

	part def ReliefValve {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		attribute setPressure : Pressure = 33000.0;
		attribute reseatPressure : Pressure = 31000.0;
		attribute ratedReliefFlow : VolumetricFlowRate = 0.050;
		attribute position : ValvePosition = ValvePosition::closed;
	}

	part def PressureTransmitter {
		port sensedFluid : FluidInletPort;
		port signalOut : PressureSignalOutPort;
		attribute rangeLow : Pressure = 0.0;
		attribute rangeHigh : Pressure = 35000.0;
		attribute accuracyOfSpan : Percentage = 0.25;
		attribute responseTime : TimeDuration = 0.25;
	}

	part def FlowMeter {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		port signalOut : FlowSignalOutPort;
		attribute rangeLow : VolumetricFlowRate = 0.0;
		attribute rangeHigh : VolumetricFlowRate = 0.075;
		attribute accuracyOfReading : Percentage = 1.0;
	}

	part def TemperatureTransmitter {
		port sensedFluid : FluidInletPort;
		port signalOut : TemperatureSignalOutPort;
		attribute rangeLow : Temperature = 0.0;
		attribute rangeHigh : Temperature = 100.0;
		attribute accuracy : Temperature = 1.0;
	}

	part def SuctionManifold {
		port tankInlet : FluidInletPort;
		port pumpOutlet : FluidOutletPort;
		port flushPort : BidirectionalFlushPort;
		attribute manifoldDiameter : Diameter = 0.2032;
		attribute designPressure : Pressure = 3500.0;
		attribute netPositiveSuctionHeadRequired : Pressure = 50.0;
	}

	part def DischargeManifold {
		port pumpInlet : FluidInletPort;
		port standpipeOutlet : FluidOutletPort;
		port reliefOutlet : FluidOutletPort;
		attribute manifoldDiameter : Diameter = 0.1270;
		attribute designPressure : Pressure = 35000.0;
		attribute pressureRippleLimit : Percentage = 5.0;
	}

	part def PistonAssembly {
		attribute pistonDiameter : Diameter = 0.1524;
		attribute strokeLength : StrokeLength = 0.2032;
		attribute linerWearAllowance : Diameter = 0.003;
		attribute reciprocatingMass : Mass = 85.0;
	}

	part def PumpValveAssembly {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		attribute position : ValvePosition = ValvePosition::closed;
		attribute seatDiameter : Diameter = 0.1016;
		attribute maximumDifferentialPressure : Pressure = 35000.0;
	}

	part def FluidEnd {
		port suctionHeader : FluidInletPort;
		port dischargeHeader : FluidOutletPort;
		part suctionValve[3] : PumpValveAssembly;
		part dischargeValve[3] : PumpValveAssembly;
		part piston[3] : PistonAssembly;
		attribute maximumAllowableWorkingPressure : Pressure = 35000.0;
		attribute cylinderCount : Integer = 3;
		attribute volumetricEfficiency : Percentage = 92.0;
	}

	part def PowerEnd {
		port shaftIn : MechanicalPowerInPort;
		port crankOutput : MechanicalPowerOutPort;
		attribute maximumInputPower : Power = 1190.0;
		attribute gearRatio : Real = 4.55;
		attribute bearingTemperatureLimit : Temperature = 90.0;
		attribute lubricationPressureMinimum : Pressure = 250.0;
	}

	part def MudPump {
		port suctionPort : FluidInletPort;
		port dischargePort : FluidOutletPort;
		port shaftPort : MechanicalPowerInPort;
		port commandPort : CommandInPort;
		port statusPort : StatusOutPort;

		part fluidEnd : FluidEnd;
		part powerEnd : PowerEnd;

		attribute ratedFlowRate : VolumetricFlowRate = 0.050;
		attribute minimumControllableFlowRate : VolumetricFlowRate = 0.005;
		attribute ratedDischargePressure : Pressure = 30000.0;
		attribute maximumAllowableWorkingPressure : Pressure = 35000.0;
		attribute ratedStrokeRate : StrokeRate = 120.0;
		attribute minimumStrokeRate : StrokeRate = 10.0;
		attribute hydraulicEfficiency : Percentage = 88.0;
		attribute operatingMode : PumpOperatingMode = PumpOperatingMode::shutdown;
		attribute vibrationTripLevel : VibrationLevel = 12.0;

		connect suctionPort to fluidEnd.suctionHeader;
		connect fluidEnd.dischargeHeader to dischargePort;
		connect shaftPort to powerEnd.shaftIn;
	}

	part def ElectricMotor {
		port electricalIn : ElectricPowerInPort;
		port shaftOut : MechanicalPowerOutPort;
		attribute ratedPower : Power = 1250.0;
		attribute ratedVoltage : Voltage = 690.0;
		attribute ratedSpeed : Speed = 1780.0;
		attribute fullLoadCurrent : ElectricCurrent = 1180.0;
		attribute efficiency : Percentage = 96.0;
		attribute windingTemperatureLimit : Temperature = 155.0;
	}

	part def VariableFrequencyDrive {
		port electricalIn : ElectricPowerInPort;
		port electricalOut : ElectricPowerOutPort;
		port commandIn : CommandInPort;
		port statusOut : StatusOutPort;
		attribute ratedPower : Power = 1400.0;
		attribute inputVoltage : Voltage = 690.0;
		attribute outputFrequencyMinimum : Real = 5.0;
		attribute outputFrequencyMaximum : Real = 60.0;
		attribute overloadCapability : Percentage = 110.0;
	}

	part def Gearbox {
		port highSpeedShaft : MechanicalPowerInPort;
		port lowSpeedShaft : MechanicalPowerOutPort;
		attribute ratio : Real = 4.55;
		attribute ratedTorque : Torque = 85000.0;
		attribute efficiency : Percentage = 97.0;
		attribute oilTemperatureLimit : Temperature = 95.0;
	}

	part def LocalPumpController {
		port pumpCommandOut : CommandOutPort;
		port vfdCommandOut : CommandOutPort;
		port pumpStatusIn : StatusInPort;
		port vfdStatusIn : StatusInPort;
		port suctionPressureIn : PressureSignalInPort;
		port dischargePressureIn : PressureSignalInPort;
		port flowIn : FlowSignalInPort;
		port temperatureIn : TemperatureSignalInPort;

		attribute commandedFlowRate : VolumetricFlowRate = 0.032;
		attribute highDischargePressureTrip : Pressure = 33000.0;
		attribute lowSuctionPressureTrip : Pressure = 35.0;
		attribute highMudTemperatureAlarm : Temperature = 80.0;
		attribute startupPrimeTimeLimit : TimeDuration = 45.0;
		attribute flowControlTolerance : Percentage = 3.0;
	}

	part def SkidBase {
		attribute footprintLength : Length = 6.2;
		attribute footprintWidth : Length = 2.4;
		attribute dryMass : Mass = 16500.0;
		attribute maximumTransportAcceleration : Acceleration = 2.0;
	}

	action def PrimeMudPump {
		in item mudFromTank : DrillingMud;
		in attribute primeTimeLimit : TimeDuration;
		out item mudAtPumpSuction : DrillingMud;
		out attribute suctionFilled : Boolean;
	}

	action def PumpMudContinuously {
		in item mudAtSuction : DrillingMud;
		in attribute commandedFlowRate : VolumetricFlowRate;
		in attribute availableSuctionPressure : Pressure;
		out item pressurizedMud : DrillingMud;
		out attribute actualFlowRate : VolumetricFlowRate;
		out attribute dischargePressure : Pressure;
	}

	action def TripPump {
		in attribute dischargePressure : Pressure;
		in attribute suctionPressure : Pressure;
		in attribute emergencyStop : Boolean;
		out attribute motorDeenergized : Boolean;
		out attribute dischargeIsolated : Boolean;
	}

	state def PumpingSubsystemStates {
		state shutdown;
		state standby;
		state priming;
		state running;
		state flushing;
		state tripped;

		transition initial then shutdown;
		transition energize first shutdown then standby;
		transition startPrime first standby then priming;
		transition primeComplete first priming then running;
		transition requestFlush first standby then flushing;
		transition flushComplete first flushing then standby;
		transition normalStop first running then standby;
		transition tripFromPriming first priming then tripped;
		transition tripFromRunning first running then tripped;
		transition resetTrip first tripped then standby;
	}

	constraint def MinimumFlowConstraint {
		in actualFlow : VolumetricFlowRate;
		in minimumFlow : VolumetricFlowRate;
		actualFlow >= minimumFlow
	}

	constraint def MaximumPressureConstraint {
		in actualPressure : Pressure;
		in maximumPressure : Pressure;
		actualPressure <= maximumPressure
	}

	constraint def SuctionPressureConstraint {
		in suctionPressure : Pressure;
		in minimumSuctionPressure : Pressure;
		suctionPressure >= minimumSuctionPressure
	}

	part def PumpingSubsystem {
		port mudSupplyIn : FluidInletPort;
		port pressurizedMudOut : FluidOutletPort;
		port mudReturnOut : FluidOutletPort;
		port electricalSupplyIn : ElectricPowerInPort;
		port remoteCommandIn : CommandInPort;
		port remoteStatusOut : StatusOutPort;

		part skid : SkidBase;
		part suctionLine : PipeSegment;
		part suctionIsolationValve : IsolationValve;
		part suctionStrainer : Strainer;
		part suctionManifold : SuctionManifold;
		part mudPump : MudPump;
		part dischargeCheckValve : CheckValve;
		part pulsationDampener : PulsationDampener;
		part dischargeManifold : DischargeManifold;
		part dischargeFlowMeter : FlowMeter;
		part dischargeIsolationValve : IsolationValve;
		part reliefValve : ReliefValve;
		part reliefReturnLine : PipeSegment;
		part dischargeLine : PipeSegment;
		part suctionPressureTransmitter : PressureTransmitter;
		part dischargePressureTransmitter : PressureTransmitter;
		part mudTemperatureTransmitter : TemperatureTransmitter;
		part electricDrive : VariableFrequencyDrive;
		part driveMotor : ElectricMotor;
		part reductionGearbox : Gearbox;
		part controller : LocalPumpController;

		attribute nominalFlowRate : VolumetricFlowRate = 0.032;
		attribute maximumContinuousFlowRate : VolumetricFlowRate = 0.050;
		attribute minimumContinuousFlowRate : VolumetricFlowRate = 0.005;
		attribute normalSuctionPressure : Pressure = 150.0;
		attribute minimumSuctionPressure : Pressure = 35.0;
		attribute normalDischargePressure : Pressure = 24000.0;
		attribute maximumDischargePressure : Pressure = 33000.0;
		attribute fluidDesignPressure : Pressure = 35000.0;
		attribute ratedInputPower : Power = 1250.0;
		attribute operatingState : PumpOperatingMode = PumpOperatingMode::standby;
		attribute maximumPressureRipple : Percentage = 5.0;

		action prime : PrimeMudPump;
		action pumpContinuously : PumpMudContinuously;
		action trip : TripPump;
		state behavior : PumpingSubsystemStates;

		connect mudSupplyIn to suctionLine.inlet;
		connect suctionLine.outlet to suctionIsolationValve.inlet;
		connect suctionIsolationValve.outlet to suctionStrainer.inlet;
		connect suctionStrainer.outlet to suctionManifold.tankInlet;
		connect suctionManifold.pumpOutlet to mudPump.suctionPort;

		connect mudPump.dischargePort to dischargeCheckValve.inlet;
		connect dischargeCheckValve.outlet to pulsationDampener.inlet;
		connect pulsationDampener.outlet to dischargeManifold.pumpInlet;
		connect dischargeManifold.standpipeOutlet to dischargeFlowMeter.inlet;
		connect dischargeFlowMeter.outlet to dischargeIsolationValve.inlet;
		connect dischargeIsolationValve.outlet to dischargeLine.inlet;
		connect dischargeLine.outlet to pressurizedMudOut;

		connect dischargeManifold.reliefOutlet to reliefValve.inlet;
		connect reliefValve.outlet to reliefReturnLine.inlet;
		connect reliefReturnLine.outlet to mudReturnOut;

		connect electricalSupplyIn to electricDrive.electricalIn;
		connect electricDrive.electricalOut to driveMotor.electricalIn;
		connect driveMotor.shaftOut to reductionGearbox.highSpeedShaft;
		connect reductionGearbox.lowSpeedShaft to mudPump.shaftPort;

		connect remoteCommandIn to controller.pumpCommandOut;
		connect controller.pumpCommandOut to mudPump.commandPort;
		connect controller.vfdCommandOut to electricDrive.commandIn;
		connect mudPump.statusPort to controller.pumpStatusIn;
		connect electricDrive.statusOut to controller.vfdStatusIn;
		connect mudPump.statusPort to remoteStatusOut;

		connect suctionManifold.pumpOutlet to suctionPressureTransmitter.sensedFluid;
		connect suctionPressureTransmitter.signalOut to controller.suctionPressureIn;
		connect dischargeManifold.standpipeOutlet to dischargePressureTransmitter.sensedFluid;
		connect dischargePressureTransmitter.signalOut to controller.dischargePressureIn;
		connect dischargeFlowMeter.signalOut to controller.flowIn;
		connect suctionManifold.pumpOutlet to mudTemperatureTransmitter.sensedFluid;
		connect mudTemperatureTransmitter.signalOut to controller.temperatureIn;
	}

	part def MudPumpingInstallation {
		part mudTank : MudTank;
		part pumpingSubsystem : PumpingSubsystem;

		connect mudTank.outlet to pumpingSubsystem.mudSupplyIn;
		connect pumpingSubsystem.mudReturnOut to mudTank.returnInlet;
	}

	requirement def MudPumpingCapacityRequirement {
		subject subsystem : PumpingSubsystem;
		attribute requiredContinuousFlow : VolumetricFlowRate = 0.032;
		require constraint { subsystem.nominalFlowRate >= requiredContinuousFlow }
	}

	requirement def MudPumpPressureRequirement {
		subject subsystem : PumpingSubsystem;
		attribute requiredOperatingDischargePressure : Pressure = 24000.0;
		attribute maximumAllowedTripPressure : Pressure = 33000.0;
		require constraint { subsystem.normalDischargePressure >= requiredOperatingDischargePressure }
		require constraint { subsystem.maximumDischargePressure <= maximumAllowedTripPressure }
	}

	requirement def SuctionProtectionRequirement {
		subject subsystem : PumpingSubsystem;
		attribute minimumAllowedSuctionPressure : Pressure = 35.0;
		require constraint { subsystem.minimumSuctionPressure >= minimumAllowedSuctionPressure }
	}

	requirement def PressureRippleRequirement {
		subject subsystem : PumpingSubsystem;
		attribute maximumAllowedRipple : Percentage = 5.0;
		require constraint { subsystem.maximumPressureRipple <= maximumAllowedRipple }
	}

	requirement def DrivePowerRequirement {
		subject subsystem : PumpingSubsystem;
		attribute minimumRatedInputPower : Power = 1100.0;
		require constraint { subsystem.ratedInputPower >= minimumRatedInputPower }
	}

	part mudPumpingInstallation : MudPumpingInstallation;

	requirement mudPumpingCapacity : MudPumpingCapacityRequirement {
		subject subsystem : PumpingSubsystem;
	}

	requirement mudPumpPressure : MudPumpPressureRequirement {
		subject subsystem : PumpingSubsystem;
	}

	requirement suctionProtection : SuctionProtectionRequirement {
		subject subsystem : PumpingSubsystem;
	}

	requirement pressureRippleControl : PressureRippleRequirement {
		subject subsystem : PumpingSubsystem;
	}

	requirement drivePowerCapacity : DrivePowerRequirement {
		subject subsystem : PumpingSubsystem;
	}
}
