package HydrocollatorThermalTherapyModel {
	import ScalarValues::*;

	enum def TemperatureUnit {
		enum degC;
		enum K;
	}

	enum def PowerUnit {
		enum W;
		enum kW;
	}

	enum def VoltageUnit {
		enum V;
	}

	enum def CurrentUnit {
		enum A;
	}

	enum def FrequencyUnit {
		enum Hz;
	}

	enum def VolumeUnit {
		enum L;
		enum m3;
	}

	enum def MassUnit {
		enum kg;
	}

	enum def FlowRateUnit {
		enum L_per_min;
	}

	enum def TimeUnit {
		enum min;
		enum s;
	}

	enum def EnergyUnit {
		enum J;
	}

	enum def LengthUnit {
		enum mm;
		enum m;
	}

	enum def StatusKind {
		enum normal;
		enum warning;
		enum alarm;
		enum trip;
	}

	enum def ControlCommandKind {
		enum powerOff;
		enum powerOn;
		enum enableHeat;
		enum disableHeat;
		enum enablePump;
		enum disablePump;
		enum resetFault;
	}

	enum def PackConditionKind {
		enum cold;
		enum warming;
		enum ready;
		enum overheated;
	}

	attribute def Temperature {
		attribute value : ScalarValues::Real;
		attribute unit : TemperatureUnit;
	}

	attribute def Power {
		attribute value : ScalarValues::Real;
		attribute unit : PowerUnit;
	}

	attribute def Voltage {
		attribute value : ScalarValues::Real;
		attribute unit : VoltageUnit;
	}

	attribute def Current {
		attribute value : ScalarValues::Real;
		attribute unit : CurrentUnit;
	}

	attribute def Frequency {
		attribute value : ScalarValues::Real;
		attribute unit : FrequencyUnit;
	}

	attribute def Volume {
		attribute value : ScalarValues::Real;
		attribute unit : VolumeUnit;
	}

	attribute def Mass {
		attribute value : ScalarValues::Real;
		attribute unit : MassUnit;
	}

	attribute def FlowRate {
		attribute value : ScalarValues::Real;
		attribute unit : FlowRateUnit;
	}

	attribute def Duration {
		attribute value : ScalarValues::Real;
		attribute unit : TimeUnit;
	}

	attribute def Energy {
		attribute value : ScalarValues::Real;
		attribute unit : EnergyUnit;
	}

	attribute def Length {
		attribute value : ScalarValues::Real;
		attribute unit : LengthUnit;
	}

	item def Water {
		attribute temperature : Temperature;
		attribute volume : Volume;
		attribute contaminationIndex : ScalarValues::Real;
	}

	item def MoistHeatPack {
		attribute packTemperature : Temperature;
		attribute waterContent : Volume;
		attribute mass : Mass;
		attribute condition : PackConditionKind;
	}

	item def ElectricalPower {
		attribute voltage : Voltage;
		attribute current : Current;
		attribute frequency : Frequency;
		attribute power : Power;
	}

	item def ThermalEnergy {
		attribute heatRate : Power;
		attribute accumulatedHeat : Energy;
		attribute sourceTemperature : Temperature;
	}

	item def TemperatureMeasurement {
		attribute measuredTemperature : Temperature;
		attribute sampleAge : Duration;
		attribute valid : ScalarValues::Boolean;
	}

	item def ControlSignal {
		attribute command : ControlCommandKind;
		attribute enabled : ScalarValues::Boolean;
	}

	item def StatusSignal {
		attribute status : StatusKind;
		attribute message : ScalarValues::String;
	}

	item def PowerOnCommand;
	item def PowerOffCommand;
	item def PackInsertedEvent;
	item def PackRemovedEvent;
	item def LowWaterEvent;
	item def OverTemperatureEvent;
	item def FaultResetCommand;

	port def ElectricalPowerPort {
		inout item power : ElectricalPower;
	}

	port def ThermalPort {
		inout item heat : ThermalEnergy;
	}

	port def WaterPort {
		inout item water : Water;
	}

	port def PackTransferPort {
		inout item pack : MoistHeatPack;
	}

	port def TemperatureSignalPort {
		inout item measurement : TemperatureMeasurement;
	}

	port def ControlSignalPort {
		inout item command : ControlSignal;
	}

	port def StatusPort {
		inout item status : StatusSignal;
	}

	part def WaterBath {
		attribute capacity : Volume {
			:>> value = 30.0;
			:>> unit = VolumeUnit::L;
		}
		attribute nominalFillVolume : Volume {
			:>> value = 26.0;
			:>> unit = VolumeUnit::L;
		}
		attribute minimumSafeVolume : Volume {
			:>> value = 20.0;
			:>> unit = VolumeUnit::L;
		}
		attribute waterTemperature : Temperature {
			:>> value = 73.0;
			:>> unit = TemperatureUnit::degC;
		}
		attribute waterLevel : Volume {
			:>> value = 26.0;
			:>> unit = VolumeUnit::L;
		}
		attribute insulationThickness : Length {
			:>> value = 25.0;
			:>> unit = LengthUnit::mm;
		}

		port fillPort : WaterPort;
		port drainPort : WaterPort;
		port circulationOutlet : WaterPort;
		port circulationInlet : WaterPort;
		port heatInput : ThermalPort;
		port sensorWell : ThermalPort;
		port overTemperatureWell : ThermalPort;
		port levelSensePort : WaterPort;
	}

	part def ImmersionHeater {
		attribute ratedPower : Power {
			:>> value = 1200.0;
			:>> unit = PowerUnit::W;
		}
		attribute maximumSurfaceTemperature : Temperature {
			:>> value = 95.0;
			:>> unit = TemperatureUnit::degC;
		}
		attribute heaterEnabled : ScalarValues::Boolean = false;

		port electricalInput : ElectricalPowerPort;
		port heatOutput : ThermalPort;
	}

	part def ThermostatController {
		attribute targetTemperature : Temperature {
			:>> value = 73.0;
			:>> unit = TemperatureUnit::degC;
		}
		attribute minimumTherapyTemperature : Temperature {
			:>> value = 71.0;
			:>> unit = TemperatureUnit::degC;
		}
		attribute maximumTherapyTemperature : Temperature {
			:>> value = 74.0;
			:>> unit = TemperatureUnit::degC;
		}
		attribute overTemperatureLimit : Temperature {
			:>> value = 80.0;
			:>> unit = TemperatureUnit::degC;
		}
		attribute hysteresisBand : Temperature {
			:>> value = 1.0;
			:>> unit = TemperatureUnit::degC;
		}
		attribute controlCycleTime : Duration {
			:>> value = 2.0;
			:>> unit = TimeUnit::s;
		}

		port acInput : ElectricalPowerPort;
		port heaterPower : ElectricalPowerPort;
		port auxiliaryPower : ElectricalPowerPort;
		port temperatureInput : TemperatureSignalPort;
		port lowWaterInput : StatusPort;
		port operatorInput : ControlSignalPort;
		port statusOutput : StatusPort;
	}

	part def TemperatureSensor {
		attribute accuracy : Temperature {
			:>> value = 0.5;
			:>> unit = TemperatureUnit::degC;
		}
		attribute samplePeriod : Duration {
			:>> value = 1.0;
			:>> unit = TimeUnit::s;
		}

		port sensedBath : ThermalPort;
		port measurementOutput : TemperatureSignalPort;
	}

	part def LowWaterSensor {
		attribute tripVolume : Volume {
			:>> value = 20.0;
			:>> unit = VolumeUnit::L;
		}

		port waterContact : WaterPort;
		port levelStatus : StatusPort;
	}

	part def OverTemperatureSwitch {
		attribute tripTemperature : Temperature {
			:>> value = 82.0;
			:>> unit = TemperatureUnit::degC;
		}
		attribute resetTemperature : Temperature {
			:>> value = 76.0;
			:>> unit = TemperatureUnit::degC;
		}

		port sensedBath : ThermalPort;
		port tripStatus : StatusPort;
	}

	part def SafetyCutoff {
		attribute latched : ScalarValues::Boolean = false;

		port powerInput : ElectricalPowerPort;
		port powerOutput : ElectricalPowerPort;
		port tripInput : StatusPort;
		port resetInput : ControlSignalPort;
	}

	part def MainSwitch {
		attribute switchedOn : ScalarValues::Boolean = false;

		port lineIn : ElectricalPowerPort;
		port lineOut : ElectricalPowerPort;
		port operatorCommand : ControlSignalPort;
	}

	part def Fuse {
		attribute currentRating : Current {
			:>> value = 15.0;
			:>> unit = CurrentUnit::A;
		}

		port lineIn : ElectricalPowerPort;
		port lineOut : ElectricalPowerPort;
	}

	part def CirculationPump {
		attribute nominalFlowRate : FlowRate {
			:>> value = 4.0;
			:>> unit = FlowRateUnit::L_per_min;
		}
		attribute ratedPower : Power {
			:>> value = 40.0;
			:>> unit = PowerUnit::W;
		}

		port powerInput : ElectricalPowerPort;
		port waterIn : WaterPort;
		port waterOut : WaterPort;
	}

	part def PackRack {
		attribute packCapacity : ScalarValues::Integer = 8;
		attribute minimumSubmersionDepth : Length {
			:>> value = 50.0;
			:>> unit = LengthUnit::mm;
		}

		port waterIn : WaterPort;
		port waterOut : WaterPort;
		port packTransfer : PackTransferPort;

		part pack1 : MoistHeatPackStation;
		part pack2 : MoistHeatPackStation;
		part pack3 : MoistHeatPackStation;
		part pack4 : MoistHeatPackStation;
		part pack5 : MoistHeatPackStation;
		part pack6 : MoistHeatPackStation;
		part pack7 : MoistHeatPackStation;
		part pack8 : MoistHeatPackStation;
	}

	part def MoistHeatPackStation {
		attribute occupied : ScalarValues::Boolean = false;
		attribute dwellTimeForReadyPack : Duration {
			:>> value = 30.0;
			:>> unit = TimeUnit::min;
		}

		port packPort : PackTransferPort;
		port localWaterPort : WaterPort;
	}

	part def LidAndInsulation {
		attribute heatLossReduction : ScalarValues::Real = 0.65;
		attribute closed : ScalarValues::Boolean = true;
	}

	part def FillServicePanel {
		port fillInlet : WaterPort;
		port fillOutlet : WaterPort;
	}

	part def DrainValve {
		attribute open : ScalarValues::Boolean = false;

		port bathSide : WaterPort;
		port drainSide : WaterPort;
	}

	part def ControlPanel {
		attribute displayedSetpoint : Temperature {
			:>> value = 73.0;
			:>> unit = TemperatureUnit::degC;
		}

		port operatorCommands : ControlSignalPort;
		port controllerStatus : StatusPort;
		port displayStatus : StatusPort;
	}

	action def SenseBathTemperature {
		in item bathHeat : ThermalEnergy;
		out item measured : TemperatureMeasurement;
	}

	action def RegulateBathTemperature {
		in item measured : TemperatureMeasurement;
		in target : Temperature;
		in lowerLimit : Temperature;
		in upperLimit : Temperature;
		out item heaterCommand : ControlSignal;
	}

	action def EnableHeater {
		out item heaterCommand : ControlSignal;
	}

	action def DisableHeater {
		out item heaterCommand : ControlSignal;
	}

	action def CirculateWater {
		in item inletWater : Water;
		out item outletWater : Water;
	}

	action def HeatMoistPacks {
		in item bathWater : Water;
		in item coldPack : MoistHeatPack;
		out item readyPack : MoistHeatPack;
	}

	action def TripSafetyCutoff {
		in item faultStatus : StatusSignal;
		out item disabledPower : ElectricalPower;
	}

	part def HydrocollatorSystem {
		attribute primaryFunction : ScalarValues::String = "Heat water and maintain a controlled hot-water bath so moist heat packs are warmed to therapy-ready temperature.";
		attribute nominalSupplyVoltage : Voltage {
			:>> value = 120.0;
			:>> unit = VoltageUnit::V;
		}
		attribute nominalSupplyFrequency : Frequency {
			:>> value = 60.0;
			:>> unit = FrequencyUnit::Hz;
		}
		attribute warmupTimeFromAmbient : Duration {
			:>> value = 45.0;
			:>> unit = TimeUnit::min;
		}
		attribute ambientStartTemperature : Temperature {
			:>> value = 22.0;
			:>> unit = TemperatureUnit::degC;
		}

		port electricalSupply : ElectricalPowerPort;
		port fillWaterPort : WaterPort;
		port drainPort : WaterPort;
		port packAccess : PackTransferPort;
		port operatorCommands : ControlSignalPort;
		port userStatus : StatusPort;

		part mainSwitch : MainSwitch;
		part fuse : Fuse;
		part controller : ThermostatController;
		part safetyCutoff : SafetyCutoff;
		part heater : ImmersionHeater;
		part waterBath : WaterBath;
		part temperatureSensor : TemperatureSensor;
		part lowWaterSensor : LowWaterSensor;
		part overTemperatureSwitch : OverTemperatureSwitch;
		part circulationPump : CirculationPump;
		part packRack : PackRack;
		part lidAndInsulation : LidAndInsulation;
		part fillServicePanel : FillServicePanel;
		part drainValve : DrainValve;
		part controlPanel : ControlPanel;

		connect electricalSupply to mainSwitch.lineIn;
		connect operatorCommands to mainSwitch.operatorCommand;
		connect mainSwitch.lineOut to fuse.lineIn;
		connect fuse.lineOut to controller.acInput;
		connect controller.heaterPower to safetyCutoff.powerInput;
		connect safetyCutoff.powerOutput to heater.electricalInput;
		connect controller.auxiliaryPower to circulationPump.powerInput;

		connect heater.heatOutput to waterBath.heatInput;
		connect waterBath.sensorWell to temperatureSensor.sensedBath;
		connect temperatureSensor.measurementOutput to controller.temperatureInput;
		connect waterBath.overTemperatureWell to overTemperatureSwitch.sensedBath;
		connect overTemperatureSwitch.tripStatus to safetyCutoff.tripInput;
		connect safetyCutoff.resetInput to controlPanel.operatorCommands;

		connect waterBath.levelSensePort to lowWaterSensor.waterContact;
		connect lowWaterSensor.levelStatus to controller.lowWaterInput;

		connect fillWaterPort to fillServicePanel.fillInlet;
		connect fillServicePanel.fillOutlet to waterBath.fillPort;
		connect waterBath.drainPort to drainValve.bathSide;
		connect drainValve.drainSide to drainPort;

		connect waterBath.circulationOutlet to circulationPump.waterIn;
		connect circulationPump.waterOut to packRack.waterIn;
		connect packRack.waterOut to waterBath.circulationInlet;
		connect packAccess to packRack.packTransfer;

		connect controlPanel.operatorCommands to controller.operatorInput;
		connect controller.statusOutput to controlPanel.controllerStatus;
		connect controlPanel.displayStatus to userStatus;

		state operatingMode {
			entry; then poweredOff;

			state poweredOff;
			state fillingBath;
			state heatingToSetpoint {
				entry action enableHeater : EnableHeater;
				do action regulateBath : RegulateBathTemperature;
			}
			state readyForTherapy {
				do action circulateWater : CirculateWater;
				do action heatPacks : HeatMoistPacks;
			}
			state temperatureRecovery {
				entry action enableRecoveryHeat : EnableHeater;
				do action regulateRecovery : RegulateBathTemperature;
			}
			state standby {
				entry action disableStandbyHeat : DisableHeater;
			}
			state faultShutdown {
				entry action tripCutoff : TripSafetyCutoff;
			}

			transition powerOn
				first poweredOff
				accept PowerOnCommand
				then fillingBath;

			transition filledToSafeLevel
				first fillingBath
				if waterBath.waterLevel.value >= waterBath.minimumSafeVolume.value
				then heatingToSetpoint;

			transition readyAtSetpoint
				first heatingToSetpoint
				if waterBath.waterTemperature.value >= controller.minimumTherapyTemperature.value and waterBath.waterTemperature.value <= controller.maximumTherapyTemperature.value
				then readyForTherapy;

			transition packLoadCooling
				first readyForTherapy
				accept PackInsertedEvent
				if waterBath.waterTemperature.value < controller.minimumTherapyTemperature.value
				then temperatureRecovery;

			transition recovered
				first temperatureRecovery
				if waterBath.waterTemperature.value >= controller.targetTemperature.value
				then readyForTherapy;

			transition operatorStandby
				first readyForTherapy
				accept PowerOffCommand
				then standby;

			transition standbyPowerOff
				first standby
				accept PowerOffCommand
				then poweredOff;

			transition lowWaterFault
				first fillingBath
				accept LowWaterEvent
				then faultShutdown;

			transition overTemperatureFault
				first readyForTherapy
				accept OverTemperatureEvent
				then faultShutdown;

			transition resetAfterFault
				first faultShutdown
				accept FaultResetCommand
				then poweredOff;
		}
	}

	requirement def PrimaryFunctionRequirement {
		subject hydro : HydrocollatorSystem;

		require constraint controlledHotBath {
			hydro.waterBath.waterTemperature.value >= hydro.controller.minimumTherapyTemperature.value and
			hydro.waterBath.waterTemperature.value <= hydro.controller.maximumTherapyTemperature.value
		}

		require constraint packsCanBeSubmerged {
			hydro.packRack.packCapacity >= 1 and
			hydro.waterBath.waterLevel.value >= hydro.waterBath.minimumSafeVolume.value
		}
	}

	requirement def TemperatureControlRequirement {
		subject hydro : HydrocollatorSystem;

		require constraint therapyTemperatureBand {
			hydro.controller.minimumTherapyTemperature.value >= 71.0 and
			hydro.controller.maximumTherapyTemperature.value <= 74.0 and
			hydro.controller.targetTemperature.value >= hydro.controller.minimumTherapyTemperature.value and
			hydro.controller.targetTemperature.value <= hydro.controller.maximumTherapyTemperature.value
		}
	}

	requirement def LowWaterSafetyRequirement {
		subject hydro : HydrocollatorSystem;

		require constraint heaterDisabledBelowMinimumWater {
			hydro.waterBath.minimumSafeVolume.value >= hydro.lowWaterSensor.tripVolume.value
		}
	}

	requirement def OverTemperatureSafetyRequirement {
		subject hydro : HydrocollatorSystem;

		require constraint cutoffBelowUnsafeTemperature {
			hydro.overTemperatureSwitch.tripTemperature.value <= hydro.controller.overTemperatureLimit.value + 2.0
		}
	}

	requirement def WarmupPerformanceRequirement {
		subject hydro : HydrocollatorSystem;

		require constraint heatsFromAmbientWithinLimit {
			hydro.warmupTimeFromAmbient.value <= 60.0 and
			hydro.heater.ratedPower.value >= 1000.0
		}
	}

	part clinicHydrocollator : HydrocollatorSystem;

	requirement primaryFunction : PrimaryFunctionRequirement {
		subject hydro = clinicHydrocollator;
	}

	requirement temperatureControl : TemperatureControlRequirement {
		subject hydro = clinicHydrocollator;
	}

	requirement lowWaterSafety : LowWaterSafetyRequirement {
		subject hydro = clinicHydrocollator;
	}

	requirement overTemperatureSafety : OverTemperatureSafetyRequirement {
		subject hydro = clinicHydrocollator;
	}

	requirement warmupPerformance : WarmupPerformanceRequirement {
		subject hydro = clinicHydrocollator;
	}

	satisfy primaryFunction by clinicHydrocollator;
	satisfy temperatureControl by clinicHydrocollator.controller;
	satisfy lowWaterSafety by clinicHydrocollator.lowWaterSensor;
	satisfy overTemperatureSafety by clinicHydrocollator.overTemperatureSwitch;
	satisfy warmupPerformance by clinicHydrocollator.heater;
}
