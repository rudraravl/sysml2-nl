package HorsepowerBasedPowerSystemModel {
	import ScalarValues::*;

	unit def horsepower;
	unit def watt;
	unit def rpm;
	unit def percent;
	unit def second;
	unit def volt;
	unit def ampere;
	unit def degreeCelsius;
	unit def kilogram;
	unit def liter;
	unit def kilogramPerHour;
	unit def kilogramPerLiter;
	unit def megajoulePerKilogram;
	unit def newtonMeter;

	attribute def Horsepower :> Real;
	attribute def PowerWatts :> Real;
	attribute def RotationalSpeed :> Real;
	attribute def Torque :> Real;
	attribute def Percentage :> Real;
	attribute def Duration :> Real;
	attribute def Voltage :> Real;
	attribute def Current :> Real;
	attribute def Temperature :> Real;
	attribute def Mass :> Real;
	attribute def Volume :> Real;
	attribute def MassFlowRate :> Real;
	attribute def Density :> Real;
	attribute def SpecificEnergy :> Real;

	enum def PowerUnitMode {
		enum off;
		enum ready;
		enum starting;
		enum producingPower;
		enum loadFollowing;
		enum protectionShutdown;
		enum faulted;
	}

	enum def CommandKind {
		enum disable;
		enum enable;
		enum start;
		enum stop;
		enum setPower;
		enum resetFault;
	}

	enum def ProtectionReason {
		enum none;
		enum overspeed;
		enum overTemperature;
		enum lowFuelPressure;
		enum overPower;
		enum controllerFault;
	}

	item def Fuel {
		attribute lowerHeatingValue : SpecificEnergy = 42.8 [megajoulePerKilogram];
		attribute density : Density = 0.74 [kilogramPerLiter];
		attribute sulfurContent : Percentage = 0.001 [percent];
	}

	item def PowerCommand {
		attribute commandKind : CommandKind = CommandKind::setPower;
		attribute requestedOutputPower : Horsepower = 100 [horsepower];
		attribute requestedSpeed : RotationalSpeed = 1800 [rpm];
		attribute enable : Boolean = true;
	}

	item def ThrottleCommand {
		attribute throttlePosition : Percentage = 0 [percent];
		attribute requestedFuelFlow : MassFlowRate = 0 [kilogramPerHour];
	}

	item def MechanicalPower {
		attribute shaftPower : Horsepower = 0 [horsepower];
		attribute shaftSpeed : RotationalSpeed = 0 [rpm];
		attribute shaftTorque : Torque = 0 [newtonMeter];
	}

	item def ElectricalSupply {
		attribute busVoltage : Voltage = 24 [volt];
		attribute availableCurrent : Current = 20 [ampere];
	}

	item def SensorFeedback {
		attribute measuredPower : Horsepower = 0 [horsepower];
		attribute measuredSpeed : RotationalSpeed = 0 [rpm];
		attribute measuredTorque : Torque = 0 [newtonMeter];
		attribute coolantTemperature : Temperature = 25 [degreeCelsius];
		attribute fuelFlow : MassFlowRate = 0 [kilogramPerHour];
	}

	item def Telemetry {
		attribute mode : PowerUnitMode = PowerUnitMode::off;
		attribute actualOutputPower : Horsepower = 0 [horsepower];
		attribute commandedOutputPower : Horsepower = 0 [horsepower];
		attribute outputSpeed : RotationalSpeed = 0 [rpm];
		attribute controllerDemand : Percentage = 0 [percent];
		attribute protectionReason : ProtectionReason = ProtectionReason::none;
	}

	port def FuelInPort {
		in item fuel : Fuel;
	}

	port def FuelOutPort {
		out item fuel : Fuel;
	}

	port def CommandInPort {
		in item command : PowerCommand;
	}

	port def ThrottleOutPort {
		out item throttle : ThrottleCommand;
	}

	port def ThrottleInPort {
		in item throttle : ThrottleCommand;
	}

	port def MechanicalPowerInPort {
		in item mechanicalPower : MechanicalPower;
	}

	port def MechanicalPowerOutPort {
		out item mechanicalPower : MechanicalPower;
	}

	port def FeedbackInPort {
		in item feedback : SensorFeedback;
	}

	port def FeedbackOutPort {
		out item feedback : SensorFeedback;
	}

	port def TelemetryOutPort {
		out item telemetry : Telemetry;
	}

	port def ElectricalInPort {
		in item supply : ElectricalSupply;
	}

	connection def FuelLine {
		end source : FuelOutPort;
		end sink : FuelInPort;
	}

	connection def CommandLink {
		end source : CommandInPort;
		end sink : CommandInPort;
	}

	connection def ThrottleLink {
		end source : ThrottleOutPort;
		end sink : ThrottleInPort;
	}

	connection def ShaftCoupling {
		end source : MechanicalPowerOutPort;
		end sink : MechanicalPowerInPort;
	}

	connection def FeedbackLink {
		end source : FeedbackOutPort;
		end sink : FeedbackInPort;
	}

	connection def TelemetryLink {
		end source : TelemetryOutPort;
		end sink : TelemetryOutPort;
	}

	action def ConvertFuelToShaftHorsepower {
		in item fuel : Fuel;
		in item throttle : ThrottleCommand;
		out item shaftPower : MechanicalPower;
		attribute combustionEfficiency : Percentage = 34 [percent];
		attribute targetRatedPower : Horsepower = 150 [horsepower];
	}

	action def RegulateHorsepower {
		in item command : PowerCommand;
		in item feedback : SensorFeedback;
		out item throttle : ThrottleCommand;
		out item telemetry : Telemetry;
		attribute allowedTrackingError : Horsepower = 2 [horsepower];
		attribute responseTime : Duration = 1.5 [second];
	}

	action def TransmitShaftPower {
		in item inputPower : MechanicalPower;
		out item outputPower : MechanicalPower;
		attribute mechanicalEfficiency : Percentage = 97 [percent];
	}

	action def DeliverControlledHorsepower {
		in item command : PowerCommand;
		in item fuel : Fuel;
		out item outputPower : MechanicalPower;
		out item telemetry : Telemetry;
		attribute primaryFunctionPowerBasis : Horsepower = 150 [horsepower];
	}

	state def HorsepowerPowerUnitLifecycle {
		state off;
		state ready;
		state starting;
		state producingPower;
		state loadFollowing;
		state protectionShutdown;
		state faulted;

		transition initialize then off;
		transition enable first off then ready;
		transition start first ready then starting;
		transition reachRatedSpeed first starting then producingPower;
		transition followLoad first producingPower then loadFollowing;
		transition stabilize first loadFollowing then producingPower;
		transition protectiveTripFromProducing first producingPower then protectionShutdown;
		transition protectiveTripFromLoadFollowing first loadFollowing then protectionShutdown;
		transition faultDetected first protectionShutdown then faulted;
		transition reset first faulted then off;
		transition stopFromReady first ready then off;
		transition stopFromProducing first producingPower then ready;
	}

	part def FuelReservoir {
		port fuelOut : FuelOutPort;

		attribute usableFuelMass : Mass = 60 [kilogram];
		attribute usableFuelVolume : Volume = 81 [liter];
		attribute nominalFuelTemperature : Temperature = 20 [degreeCelsius];
	}

	part def PowerController {
		port commandIn : CommandInPort;
		port feedbackIn : FeedbackInPort;
		port throttleOut : ThrottleOutPort;
		port telemetryOut : TelemetryOutPort;
		port electricalIn : ElectricalInPort;

		attribute ratedCommandPower : Horsepower = 150 [horsepower];
		attribute minimumCommandPower : Horsepower = 10 [horsepower];
		attribute maximumCommandPower : Horsepower = 150 [horsepower];
		attribute trackingTolerance : Horsepower = 2 [horsepower];
		attribute controlLoopPeriod : Duration = 0.02 [second];

		perform action regulate : RegulateHorsepower;
	}

	part def SpeedGovernor {
		port throttleIn : ThrottleInPort;
		port throttleOut : ThrottleOutPort;
		port feedbackIn : FeedbackInPort;

		attribute commandedSpeed : RotationalSpeed = 1800 [rpm];
		attribute overspeedLimit : RotationalSpeed = 2100 [rpm];
		attribute droop : Percentage = 4 [percent];
	}

	part def CombustionEngine {
		port fuelIn : FuelInPort;
		port throttleIn : ThrottleInPort;
		port shaftPowerOut : MechanicalPowerOutPort;
		port feedbackOut : FeedbackOutPort;
		port electricalIn : ElectricalInPort;

		attribute ratedShaftPower : Horsepower = 150 [horsepower];
		attribute ratedShaftPowerWatts : PowerWatts = 111855 [watt];
		attribute maximumContinuousPower : Horsepower = 135 [horsepower];
		attribute peakPowerDuration : Duration = 30 [second];
		attribute idleSpeed : RotationalSpeed = 800 [rpm];
		attribute ratedSpeed : RotationalSpeed = 1800 [rpm];
		attribute maximumCoolantTemperature : Temperature = 105 [degreeCelsius];
		attribute maximumFuelFlow : MassFlowRate = 32 [kilogramPerHour];
		attribute dryMass : Mass = 410 [kilogram];

		perform action convertFuel : ConvertFuelToShaftHorsepower;
		exhibit state lifecycle : HorsepowerPowerUnitLifecycle;
	}

	part def OutputShaftAssembly {
		port powerIn : MechanicalPowerInPort;
		port powerOut : MechanicalPowerOutPort;
		port feedbackOut : FeedbackOutPort;

		attribute inputRating : Horsepower = 160 [horsepower];
		attribute continuousOutputRating : Horsepower = 150 [horsepower];
		attribute shaftSpeedRating : RotationalSpeed = 1800 [rpm];
		attribute torqueRating : Torque = 594 [newtonMeter];
		attribute transmissionEfficiency : Percentage = 97 [percent];

		perform action transmit : TransmitShaftPower;
	}

	part def HorsepowerPowerUnit {
		port operatorCommandIn : CommandInPort;
		port fuelIn : FuelInPort;
		port electricalIn : ElectricalInPort;
		port mechanicalPowerOut : MechanicalPowerOutPort;
		port telemetryOut : TelemetryOutPort;

		attribute ratedOutputPower : Horsepower = 150 [horsepower];
		attribute primaryFunctionMinimumPower : Horsepower = 100 [horsepower];
		attribute maximumContinuousOutputPower : Horsepower = 135 [horsepower];
		attribute powerTrackingTolerance : Horsepower = 2 [horsepower];
		attribute nominalOutputSpeed : RotationalSpeed = 1800 [rpm];
		attribute shutdownOverspeed : RotationalSpeed = 2100 [rpm];

		part controller : PowerController;
		part governor : SpeedGovernor;
		part engine : CombustionEngine;
		part outputShaft : OutputShaftAssembly;

		connect commandDelegation : CommandLink connect operatorCommandIn to controller.commandIn;
		connect controllerToGovernor : ThrottleLink connect controller.throttleOut to governor.throttleIn;
		connect governorToEngine : ThrottleLink connect governor.throttleOut to engine.throttleIn;
		connect fuelDelegation connect fuelIn to engine.fuelIn;
		connect engineToShaft : ShaftCoupling connect engine.shaftPowerOut to outputShaft.powerIn;
		connect shaftToExternalLoad connect outputShaft.powerOut to mechanicalPowerOut;
		connect shaftFeedback : FeedbackLink connect outputShaft.feedbackOut to controller.feedbackIn;
		connect engineFeedbackToGovernor : FeedbackLink connect engine.feedbackOut to governor.feedbackIn;
		connect telemetryDelegation connect controller.telemetryOut to telemetryOut;
		connect controllerElectrical connect electricalIn to controller.electricalIn;
		connect engineElectrical connect electricalIn to engine.electricalIn;

		perform action primaryFunction : DeliverControlledHorsepower;
		exhibit state operatingLifecycle : HorsepowerPowerUnitLifecycle;
	}

	part def HorsepowerBasedPlant {
		port operatorCommandIn : CommandInPort;
		port mechanicalPowerOut : MechanicalPowerOutPort;
		port telemetryOut : TelemetryOutPort;

		part fuelReservoir : FuelReservoir;
		part powerUnit : HorsepowerPowerUnit;

		connect plantCommand connect operatorCommandIn to powerUnit.operatorCommandIn;
		connect plantFuel : FuelLine connect fuelReservoir.fuelOut to powerUnit.fuelIn;
		connect plantPowerOutput connect powerUnit.mechanicalPowerOut to mechanicalPowerOut;
		connect plantTelemetry connect powerUnit.telemetryOut to telemetryOut;
	}

	constraint def RatedPowerAtLeastMinimum {
		in rated : Horsepower;
		in minimum : Horsepower;
		constraint { rated >= minimum }
	}

	constraint def PowerTrackingWithinTolerance {
		in requested : Horsepower;
		in actual : Horsepower;
		in tolerance : Horsepower;
		constraint { actual >= requested - tolerance and actual <= requested + tolerance }
	}

	constraint def ContinuousPowerNotAboveRated {
		in continuous : Horsepower;
		in rated : Horsepower;
		constraint { continuous <= rated }
	}

	requirement def HighLevelPrimaryFunctionRequirement {
		subject unit : HorsepowerPowerUnit;
		doc /* The system shall convert supplied fuel and an operator horsepower command into controlled mechanical shaft power at the output interface. */
		require constraint { unit.ratedOutputPower >= unit.primaryFunctionMinimumPower }
	}

	requirement def HorsepowerRatingRequirement {
		subject unit : HorsepowerPowerUnit;
		doc /* The system shall be sized and reported using horsepower as the primary power basis. */
		require constraint { unit.ratedOutputPower >= 150 [horsepower] }
	}

	requirement def PowerTrackingRequirement {
		subject unit : HorsepowerPowerUnit;
		doc /* When enabled and commanded within its rating, the unit shall regulate delivered output power to the requested horsepower within the allowed tolerance. */
		require constraint { unit.powerTrackingTolerance <= 2 [horsepower] }
	}

	requirement def ContinuousOperationRequirement {
		subject unit : HorsepowerPowerUnit;
		doc /* The continuous output capability shall not exceed the rated horsepower and shall support sustained operation below the rating. */
		require constraint { unit.maximumContinuousOutputPower <= unit.ratedOutputPower }
	}

	part horsepowerPlant : HorsepowerBasedPlant {
		part :>> powerUnit {
			attribute :>> ratedOutputPower = 150 [horsepower];
			attribute :>> primaryFunctionMinimumPower = 100 [horsepower];
			attribute :>> maximumContinuousOutputPower = 135 [horsepower];
			attribute :>> powerTrackingTolerance = 2 [horsepower];
			attribute :>> nominalOutputSpeed = 1800 [rpm];
		}
	}

	requirement primaryFunctionRequirement : HighLevelPrimaryFunctionRequirement {
		subject :>> unit = horsepowerPlant.powerUnit;
	}

	requirement ratingRequirement : HorsepowerRatingRequirement {
		subject :>> unit = horsepowerPlant.powerUnit;
	}

	requirement trackingRequirement : PowerTrackingRequirement {
		subject :>> unit = horsepowerPlant.powerUnit;
	}

	requirement continuousOperationRequirement : ContinuousOperationRequirement {
		subject :>> unit = horsepowerPlant.powerUnit;
	}

	satisfy primaryFunctionRequirement by horsepowerPlant.powerUnit;
	satisfy ratingRequirement by horsepowerPlant.powerUnit;
	satisfy trackingRequirement by horsepowerPlant.powerUnit.controller;
	satisfy continuousOperationRequirement by horsepowerPlant.powerUnit.engine;
}
