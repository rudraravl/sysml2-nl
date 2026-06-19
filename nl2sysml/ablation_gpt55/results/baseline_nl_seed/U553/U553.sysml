package RotaryCompressionPumpingSubsystemModel {

	import ScalarValues::*;

	attribute def Pressure_kPa :> Real {
		attribute unit : String = "kPa";
	}

	attribute def DifferentialPressure_kPa :> Real {
		attribute unit : String = "kPa";
	}

	attribute def Temperature_degC :> Real {
		attribute unit : String = "degC";
	}

	attribute def VolumeFlowRate_L_per_min :> Real {
		attribute unit : String = "L/min";
	}

	attribute def RotationalSpeed_rpm :> Real {
		attribute unit : String = "rpm";
	}

	attribute def Torque_N_m :> Real {
		attribute unit : String = "N*m";
	}

	attribute def Power_kW :> Real {
		attribute unit : String = "kW";
	}

	attribute def Viscosity_cP :> Real {
		attribute unit : String = "cP";
	}

	attribute def Density_kg_per_m3 :> Real {
		attribute unit : String = "kg/m^3";
	}

	attribute def Volume_L :> Real {
		attribute unit : String = "L";
	}

	attribute def Time_s :> Real {
		attribute unit : String = "s";
	}

	attribute def Length_mm :> Real {
		attribute unit : String = "mm";
	}

	attribute def Current_A :> Real {
		attribute unit : String = "A";
	}

	attribute def Voltage_V :> Real {
		attribute unit : String = "V";
	}

	attribute def Efficiency_percent :> Real {
		attribute unit : String = "%";
	}

	enum def FluidCompatibility {
		enum compatible;
		enum marginal;
		enum incompatible;
	}

	enum def ValvePosition {
		enum closed;
		enum opening;
		enum open;
		enum closing;
	}

	enum def PumpMode {
		enum stopped;
		enum standby;
		enum priming;
		enum accelerating;
		enum running;
		enum bypassing;
		enum shutdown;
		enum faulted;
	}

	enum def FaultKind {
		enum noFault;
		enum lowSuctionPressure;
		enum highDischargePressure;
		enum overTemperature;
		enum motorOverCurrent;
		enum sealLeakage;
		enum lossOfPrime;
		enum sensorFailure;
		enum emergencyStop;
	}

	item def WorkingFluid {
		attribute density : Density_kg_per_m3 = 998.0;
		attribute dynamicViscosity : Viscosity_cP = 1.0;
		attribute vaporPressure : Pressure_kPa = 2.4;
		attribute bulkTemperature : Temperature_degC = 25.0;
		attribute compatibilityWithElastomers : FluidCompatibility = FluidCompatibility::compatible;
	}

	item def PumpCommand {
		attribute requestedMode : PumpMode = PumpMode::standby;
		attribute requestedSpeed : RotationalSpeed_rpm = 0.0;
		attribute resetFault : Boolean = false;
		attribute emergencyStop : Boolean = false;
	}

	item def PumpTelemetry {
		attribute actualMode : PumpMode = PumpMode::stopped;
		attribute suctionPressure : Pressure_kPa = 0.0;
		attribute dischargePressure : Pressure_kPa = 0.0;
		attribute deliveredFlow : VolumeFlowRate_L_per_min = 0.0;
		attribute casingTemperature : Temperature_degC = 25.0;
		attribute motorCurrent : Current_A = 0.0;
		attribute activeFault : FaultKind = FaultKind::noFault;
	}

	port def FluidInletPort {
		in item fluid : WorkingFluid;
		attribute staticPressure : Pressure_kPa = 101.3;
		attribute temperature : Temperature_degC = 25.0;
		attribute flowRate : VolumeFlowRate_L_per_min = 0.0;
	}

	port def FluidOutletPort {
		out item fluid : WorkingFluid;
		attribute staticPressure : Pressure_kPa = 101.3;
		attribute temperature : Temperature_degC = 25.0;
		attribute flowRate : VolumeFlowRate_L_per_min = 0.0;
	}

	port def FluidBypassPort {
		inout item fluid : WorkingFluid;
		attribute staticPressure : Pressure_kPa = 101.3;
		attribute temperature : Temperature_degC = 25.0;
		attribute flowRate : VolumeFlowRate_L_per_min = 0.0;
	}

	port def MechanicalPowerInputPort {
		in attribute shaftSpeed : RotationalSpeed_rpm = 0.0;
		in attribute shaftTorque : Torque_N_m = 0.0;
		in attribute transmittedPower : Power_kW = 0.0;
	}

	port def ElectricalPowerInputPort {
		in attribute lineVoltage : Voltage_V = 480.0;
		in attribute lineCurrent : Current_A = 0.0;
		in attribute electricalPower : Power_kW = 0.0;
	}

	port def ControlInputPort {
		in item command : PumpCommand;
	}

	port def TelemetryOutputPort {
		out item telemetry : PumpTelemetry;
	}

	port def LeakDrainPort {
		out item leakedFluid : WorkingFluid;
		attribute leakageRate : VolumeFlowRate_L_per_min = 0.0;
	}

	part def Reservoir {
		attribute usableVolume : Volume_L = 500.0;
		attribute fluidLevelVolume : Volume_L = 400.0;
		attribute headPressure : Pressure_kPa = 120.0;
		attribute fluidTemperature : Temperature_degC = 25.0;
		port outlet : FluidOutletPort;
		port returnInlet : FluidInletPort;
	}

	part def InletStrainer {
		attribute meshOpening : Length_mm = 0.5;
		attribute cleanDifferentialPressure : DifferentialPressure_kPa = 3.0;
		attribute maximumDifferentialPressure : DifferentialPressure_kPa = 25.0;
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
	}

	part def IsolationValve {
		attribute commandedPosition : ValvePosition = ValvePosition::open;
		attribute actualPosition : ValvePosition = ValvePosition::open;
		attribute pressureDropWhenOpen : DifferentialPressure_kPa = 2.0;
		port upstream : FluidInletPort;
		port downstream : FluidOutletPort;
	}

	part def CheckValve {
		attribute crackingPressure : DifferentialPressure_kPa = 8.0;
		attribute reverseLeakageRate : VolumeFlowRate_L_per_min = 0.05;
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
	}

	part def PressureReliefValve {
		attribute setPressure : Pressure_kPa = 850.0;
		attribute reseatPressure : Pressure_kPa = 760.0;
		attribute ratedReliefFlow : VolumeFlowRate_L_per_min = 120.0;
		attribute position : ValvePosition = ValvePosition::closed;
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
	}

	part def DischargeAccumulator {
		attribute gasPrechargePressure : Pressure_kPa = 500.0;
		attribute fluidCapacity : Volume_L = 20.0;
		attribute maximumWorkingPressure : Pressure_kPa = 1000.0;
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
	}

	part def PressureSensor {
		attribute measurementRangeLow : Pressure_kPa = 0.0;
		attribute measurementRangeHigh : Pressure_kPa = 1000.0;
		attribute measuredPressure : Pressure_kPa = 101.3;
		attribute responseTime : Time_s = 0.05;
		port sensedFluid : FluidBypassPort;
		port telemetry : TelemetryOutputPort;
	}

	part def TemperatureSensor {
		attribute measuredTemperature : Temperature_degC = 25.0;
		attribute measurementRangeLow : Temperature_degC = -20.0;
		attribute measurementRangeHigh : Temperature_degC = 120.0;
		attribute responseTime : Time_s = 0.10;
		port sensedFluid : FluidBypassPort;
		port telemetry : TelemetryOutputPort;
	}

	part def FlowMeter {
		attribute measuredFlow : VolumeFlowRate_L_per_min = 0.0;
		attribute ratedFlow : VolumeFlowRate_L_per_min = 150.0;
		attribute accuracyPercentOfReading : Efficiency_percent = 1.0;
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		port telemetry : TelemetryOutputPort;
	}

	part def ElectricMotor {
		attribute ratedPower : Power_kW = 15.0;
		attribute ratedSpeed : RotationalSpeed_rpm = 1800.0;
		attribute ratedTorque : Torque_N_m = 79.6;
		attribute ratedVoltage : Voltage_V = 480.0;
		attribute maximumCurrent : Current_A = 35.0;
		attribute efficiency : Efficiency_percent = 92.0;
		port electricalInput : ElectricalPowerInputPort;
		port shaftOutput : MechanicalPowerInputPort;
	}

	part def FlexibleCoupling {
		attribute ratedTorque : Torque_N_m = 120.0;
		attribute torsionalStiffness : Torque_N_m = 2500.0;
		port motorSide : MechanicalPowerInputPort;
		port pumpSide : MechanicalPowerInputPort;
	}

	part def RotaryCompressionPump {
		attribute displacementPerRevolution : Volume_L = 0.045;
		attribute nominalSpeed : RotationalSpeed_rpm = 1750.0;
		attribute minimumContinuousSpeed : RotationalSpeed_rpm = 400.0;
		attribute maximumContinuousSpeed : RotationalSpeed_rpm = 1900.0;
		attribute nominalDifferentialPressure : DifferentialPressure_kPa = 600.0;
		attribute maximumDischargePressure : Pressure_kPa = 900.0;
		attribute volumetricEfficiency : Efficiency_percent = 86.0;
		attribute mechanicalEfficiency : Efficiency_percent = 88.0;
		attribute casingTemperature : Temperature_degC = 30.0;
		attribute sealLeakageLimit : VolumeFlowRate_L_per_min = 0.10;

		port suction : FluidInletPort;
		port discharge : FluidOutletPort;
		port shaftInput : MechanicalPowerInputPort;
		port caseDrain : LeakDrainPort;
		port control : ControlInputPort;
		port telemetry : TelemetryOutputPort;

		part housing {
			attribute maximumWorkingPressure : Pressure_kPa = 1000.0;
			attribute materialCompatibility : FluidCompatibility = FluidCompatibility::compatible;
		}

		part driveRotor {
			attribute outsideDiameter : Length_mm = 82.0;
			attribute length : Length_mm = 160.0;
			attribute rotationalSpeed : RotationalSpeed_rpm = 0.0;
		}

		part idlerRotor {
			attribute outsideDiameter : Length_mm = 82.0;
			attribute length : Length_mm = 160.0;
			attribute rotationalSpeed : RotationalSpeed_rpm = 0.0;
		}

		part compressionChamber {
			attribute trappedVolumeAtInlet : Volume_L = 0.060;
			attribute trappedVolumeAtDischarge : Volume_L = 0.045;
			attribute internalSlipFlow : VolumeFlowRate_L_per_min = 6.0;
		}

		part mechanicalSeal {
			attribute allowableLeakage : VolumeFlowRate_L_per_min = 0.10;
			attribute maximumFaceTemperature : Temperature_degC = 95.0;
		}

		constraint operatingPressureLimit {
			discharge.staticPressure <= maximumDischargePressure;
		}

		constraint speedRangeWhenRunning {
			shaftInput.shaftSpeed <= maximumContinuousSpeed;
		}

		constraint sealLeakageLimitConstraint {
			caseDrain.leakageRate <= sealLeakageLimit;
		}
	}

	action def PrimePump {
		in item inletFluid : WorkingFluid;
		out item primedFluid : WorkingFluid;
		in suctionPressure : Pressure_kPa;
		out chamberFilled : Boolean;

		action openInletPath;
		action purgeGasFromCompressionChamber;
		action verifyPositiveSuctionHead;

		succession openInletPath then purgeGasFromCompressionChamber;
		succession purgeGasFromCompressionChamber then verifyPositiveSuctionHead;

		constraint primeRequiresPositiveSuction {
			suctionPressure > 40.0;
		}
	}

	action def CompressAndDisplaceFluid {
		in item suctionFluid : WorkingFluid;
		out item dischargeFluid : WorkingFluid;
		in suctionPressure : Pressure_kPa;
		in shaftSpeed : RotationalSpeed_rpm;
		out dischargePressure : Pressure_kPa;
		out deliveredFlow : VolumeFlowRate_L_per_min;

		action admitFluidToExpandingCavities;
		action trapFluidBetweenRotorsAndHousing;
		action reduceCavityVolumeByRotorMesh;
		action expelFluidToDischargePort;

		succession admitFluidToExpandingCavities then trapFluidBetweenRotorsAndHousing;
		succession trapFluidBetweenRotorsAndHousing then reduceCavityVolumeByRotorMesh;
		succession reduceCavityVolumeByRotorMesh then expelFluidToDischargePort;

		constraint compressionRaisesPressure {
			dischargePressure > suctionPressure;
		}

		constraint flowRequiresRotation {
			deliveredFlow >= 0.0;
		}
	}

	action def ShutdownPump {
		in commandedSpeed : RotationalSpeed_rpm;
		out stopped : Boolean;

		action rampMotorToZeroSpeed;
		action closeDischargeIsolationIfRequired;
		action leaveReliefPathAvailable;

		succession rampMotorToZeroSpeed then closeDischargeIsolationIfRequired;
		succession closeDischargeIsolationIfRequired then leaveReliefPathAvailable;
	}

	state def PumpControllerStateMachine {
		state stopped;
		state standby;
		state priming;
		state accelerating;
		state running;
		state bypassing;
		state shutdown;
		state faulted;

		transition initial then stopped;
		transition stopped_to_standby first stopped then standby;
		transition standby_to_priming first standby then priming;
		transition priming_to_accelerating first priming then accelerating;
		transition accelerating_to_running first accelerating then running;
		transition running_to_bypassing first running then bypassing;
		transition bypassing_to_running first bypassing then running;
		transition running_to_shutdown first running then shutdown;
		transition shutdown_to_stopped first shutdown then stopped;
		transition any_to_faulted first stopped then faulted;
		transition faulted_to_standby first faulted then standby;
	}

	part def PumpController {
		attribute commandedMode : PumpMode = PumpMode::stopped;
		attribute commandedSpeed : RotationalSpeed_rpm = 0.0;
		attribute lowSuctionTrip : Pressure_kPa = 35.0;
		attribute highDischargeTrip : Pressure_kPa = 880.0;
		attribute highTemperatureTrip : Temperature_degC = 90.0;
		attribute motorCurrentTrip : Current_A = 34.0;
		attribute activeFault : FaultKind = FaultKind::noFault;

		port commandIn : ControlInputPort;
		port telemetryOut : TelemetryOutputPort;
		port pumpCommandOut : ControlInputPort;

		state controllerState : PumpControllerStateMachine;

		constraint highPressureFaultLogic {
			highDischargeTrip < 900.0;
		}

		constraint suctionProtectionLogic {
			lowSuctionTrip > 0.0;
		}
	}

	part def RotaryCompressionPumpingSubsystem {
		attribute requiredFlowRate : VolumeFlowRate_L_per_min = 75.0;
		attribute nominalDeliveredFlow : VolumeFlowRate_L_per_min = 82.0;
		attribute minimumSuctionPressure : Pressure_kPa = 50.0;
		attribute nominalSuctionPressure : Pressure_kPa = 120.0;
		attribute nominalDischargePressure : Pressure_kPa = 720.0;
		attribute maximumAllowableDischargePressure : Pressure_kPa = 900.0;
		attribute maximumFluidTemperature : Temperature_degC = 80.0;
		attribute startupPrimeTimeLimit : Time_s = 30.0;
		attribute subsystemEfficiency : Efficiency_percent = 74.0;

		port fluidSupply : FluidInletPort;
		port fluidDelivery : FluidOutletPort;
		port electricalSupply : ElectricalPowerInputPort;
		port operatorCommand : ControlInputPort;
		port subsystemTelemetry : TelemetryOutputPort;
		port drain : LeakDrainPort;

		part supplyReservoir : Reservoir;
		part suctionIsolationValve : IsolationValve;
		part inletStrainer : InletStrainer;
		part suctionPressureSensor : PressureSensor;
		part suctionTemperatureSensor : TemperatureSensor;
		part driveMotor : ElectricMotor;
		part shaftCoupling : FlexibleCoupling;
		part rotaryCompressionPump : RotaryCompressionPump;
		part dischargeCheckValve : CheckValve;
		part dischargeAccumulator : DischargeAccumulator;
		part dischargeFlowMeter : FlowMeter;
		part dischargeIsolationValve : IsolationValve;
		part dischargePressureSensor : PressureSensor;
		part dischargeTemperatureSensor : TemperatureSensor;
		part reliefValve : PressureReliefValve;
		part controller : PumpController;

		connect fluidSupply to supplyReservoir.outlet;
		connect supplyReservoir.outlet to suctionIsolationValve.upstream;
		connect suctionIsolationValve.downstream to inletStrainer.inlet;
		connect inletStrainer.outlet to rotaryCompressionPump.suction;
		connect inletStrainer.outlet to suctionPressureSensor.sensedFluid;
		connect inletStrainer.outlet to suctionTemperatureSensor.sensedFluid;

		connect electricalSupply to driveMotor.electricalInput;
		connect driveMotor.shaftOutput to shaftCoupling.motorSide;
		connect shaftCoupling.pumpSide to rotaryCompressionPump.shaftInput;

		connect rotaryCompressionPump.discharge to dischargeCheckValve.inlet;
		connect dischargeCheckValve.outlet to dischargeAccumulator.inlet;
		connect dischargeAccumulator.outlet to dischargeFlowMeter.inlet;
		connect dischargeFlowMeter.outlet to dischargeIsolationValve.upstream;
		connect dischargeIsolationValve.downstream to fluidDelivery;

		connect dischargeCheckValve.outlet to dischargePressureSensor.sensedFluid;
		connect dischargeCheckValve.outlet to dischargeTemperatureSensor.sensedFluid;

		connect dischargeCheckValve.outlet to reliefValve.inlet;
		connect reliefValve.outlet to supplyReservoir.returnInlet;

		connect rotaryCompressionPump.caseDrain to drain;

		connect operatorCommand to controller.commandIn;
		connect controller.pumpCommandOut to rotaryCompressionPump.control;
		connect controller.telemetryOut to subsystemTelemetry;
		connect rotaryCompressionPump.telemetry to subsystemTelemetry;
		connect suctionPressureSensor.telemetry to subsystemTelemetry;
		connect suctionTemperatureSensor.telemetry to subsystemTelemetry;
		connect dischargePressureSensor.telemetry to subsystemTelemetry;
		connect dischargeTemperatureSensor.telemetry to subsystemTelemetry;
		connect dischargeFlowMeter.telemetry to subsystemTelemetry;

		perform action primingAction : PrimePump;
		perform action pumpingAction : CompressAndDisplaceFluid;
		perform action shutdownAction : ShutdownPump;

		constraint deliveredFlowCapability {
			nominalDeliveredFlow >= requiredFlowRate;
		}

		constraint suctionPressureProtection {
			nominalSuctionPressure >= minimumSuctionPressure;
		}

		constraint dischargePressureProtection {
			nominalDischargePressure < maximumAllowableDischargePressure;
		}

		constraint temperatureOperatingLimit {
			maximumFluidTemperature < 90.0;
		}

		constraint reliefValveBelowSubsystemLimit {
			reliefValve.setPressure < maximumAllowableDischargePressure;
		}

		constraint pumpRatedAboveOperatingPressure {
			rotaryCompressionPump.maximumDischargePressure >= maximumAllowableDischargePressure;
		}
	}

	requirement def FlowDeliveryRequirement {
		subject subsystem : RotaryCompressionPumpingSubsystem;

		attribute minimumContinuousFlow : VolumeFlowRate_L_per_min = 75.0;
		attribute requiredDischargePressure : Pressure_kPa = 700.0;

		require constraint {
			subsystem.nominalDeliveredFlow >= minimumContinuousFlow;
		}

		require constraint {
			subsystem.nominalDischargePressure >= requiredDischargePressure;
		}
	}

	requirement def RotaryCompressionRequirement {
		subject pump : RotaryCompressionPump;

		attribute minimumDifferentialPressure : DifferentialPressure_kPa = 550.0;
		attribute maximumDischargePressure : Pressure_kPa = 900.0;

		require constraint {
			pump.nominalDifferentialPressure >= minimumDifferentialPressure;
		}

		require constraint {
			pump.maximumDischargePressure >= maximumDischargePressure;
		}
	}

	requirement def ProtectionRequirement {
		subject subsystem : RotaryCompressionPumpingSubsystem;

		attribute highPressureTripMaximum : Pressure_kPa = 880.0;
		attribute lowSuctionTripMinimum : Pressure_kPa = 30.0;
		attribute reliefSetMaximum : Pressure_kPa = 850.0;

		require constraint {
			subsystem.controller.highDischargeTrip <= highPressureTripMaximum;
		}

		require constraint {
			subsystem.controller.lowSuctionTrip >= lowSuctionTripMinimum;
		}

		require constraint {
			subsystem.reliefValve.setPressure <= reliefSetMaximum;
		}
	}

	requirement def LeakageRequirement {
		subject pump : RotaryCompressionPump;

		attribute maximumAllowedSealLeakage : VolumeFlowRate_L_per_min = 0.10;

		require constraint {
			pump.caseDrain.leakageRate <= maximumAllowedSealLeakage;
		}
	}

	part pumpingSubsystem : RotaryCompressionPumpingSubsystem;

	requirement flowDelivery : FlowDeliveryRequirement {
		subject subsystem = pumpingSubsystem;
	}

	requirement rotaryCompressionPerformance : RotaryCompressionRequirement {
		subject pump = pumpingSubsystem.rotaryCompressionPump;
	}

	requirement automaticProtection : ProtectionRequirement {
		subject subsystem = pumpingSubsystem;
	}

	requirement sealLeakageControl : LeakageRequirement {
		subject pump = pumpingSubsystem.rotaryCompressionPump;
	}

	satisfy flowDelivery by pumpingSubsystem;
	satisfy rotaryCompressionPerformance by pumpingSubsystem.rotaryCompressionPump;
	satisfy automaticProtection by pumpingSubsystem.controller;
	satisfy sealLeakageControl by pumpingSubsystem.rotaryCompressionPump;
}
