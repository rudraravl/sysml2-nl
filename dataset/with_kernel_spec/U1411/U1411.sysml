package 'Industrial Filter Press System' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import MeasurementReferences::DimensionOneValue;

	package 'Items and Values' {
		item def Slurry {
			attribute solidFraction : DimensionOneValue;
			attribute density : ISQ::DensityValue;
			attribute temperature : ISQ::TemperatureValue;
		}
		item def Filtrate {
			attribute clarity : DimensionOneValue;
			attribute flowRate : ISQ::VolumeFlowRateValue;
		}
		item def FilterCake {
			attribute moistureContent : DimensionOneValue;
			attribute mass : ISQ::MassValue;
			attribute thickness : ISQ::LengthValue;
		}
		item def WashWater {
			attribute flowRate : ISQ::VolumeFlowRateValue;
			attribute temperature : ISQ::TemperatureValue;
		}

		attribute def PressureValue :> ISQ::Pressure;
		attribute def DurationValue :> ISQ::Time;
		attribute def PercentageValue :> DimensionOneValue;
	}

	package 'Components' {
		part def FilterMedia {
			attribute poreSize : ISQ::LengthValue;
			attribute permeability : ScalarValues::Real;
		}
		part def FilterPlate {
			part media : FilterMedia[1];
			attribute plateArea : ISQ::AreaValue;
			attribute plateIndex : ScalarValues::Integer;
			port slurryFeed;
			port filtrateDrain;
		}
		part def FilterChamber {
			part plates : FilterPlate[20..100] ordered;
			attribute chamberPressure : 'Items and Values'::PressureValue;
			attribute chamberVolume : ISQ::VolumeValue;
			attribute platesSeparated : ScalarValues::Boolean = false;
			port slurryInlet;
			port filtrateOutlet;
			port cakeDischarge;
			port washInlet;
		}
		part def HydraulicSystem {
			attribute clampingForce : ISQ::ForceValue;
			attribute systemPressure : 'Items and Values'::PressureValue;
			attribute maxPressure : 'Items and Values'::PressureValue = 1500 [kPa];
			port control;
			action clamp;
			action release;
		}
		part def FeedPump {
			attribute dischargePressure : 'Items and Values'::PressureValue;
			attribute maxFlowRate : ISQ::VolumeFlowRateValue;
			port pumpIn;
			port pumpOut;
			port control;
			action pump {
				in slurry : 'Items and Values'::Slurry;
				out pressurizedSlurry : 'Items and Values'::Slurry;
			}
		}
		part def Valve {
			attribute isOpen : ScalarValues::Boolean = false;
			port valveIn;
			port valveOut;
			port control;
			action open;
			action close;
		}
		part def ControlSystem {
			attribute cycleTime : 'Items and Values'::DurationValue;
			attribute chamberFull : ScalarValues::Boolean = false;
			attribute filtrateClear : ScalarValues::Boolean = false;
			attribute clampReleased : ScalarValues::Boolean = false;
			attribute cakeDischarged : ScalarValues::Boolean = false;
			attribute mediaClean : ScalarValues::Boolean = false;
			port cmdFeedPump;
			port cmdFeedValve;
			port cmdFiltrateValve;
			port cmdHydraulic;

			state def BatchCycleControl {
				state Idle;
				state Filling;
				state Filtering;
				state Consolidating;
				state Releasing;
				state Discharging;
				state Washing;
				transition from Idle to Filling;
				transition from Filling to Filtering when chamberFull;
				transition from Filtering to Consolidating when filtrateClear;
				transition from Consolidating to Releasing after 10 [min];
				transition from Releasing to Discharging when clampReleased;
				transition from Discharging to Washing when cakeDischarged;
				transition from Washing to Idle when mediaClean;
			}
		}
	}

	package 'Assembly' {
		part def FilterPressAssembly {
			part chamber : Components::FilterChamber;
			part hydraulics : Components::HydraulicSystem;
			part pump : Components::FeedPump;
			part feedValve : Components::Valve;
			part filtrateValve : Components::Valve;
			part washValve : Components::Valve;
			part controller : Components::ControlSystem;

			port slurrySupply;
			port filtrateDischarge;
			port cakeCollection;
			port washWaterSupply;

			connection slurryFlow connect pump.pumpOut to feedValve.valveIn;
			connection feedFlow connect feedValve.valveOut to chamber.slurryInlet;
			connection filtrateFlow connect chamber.filtrateOutlet to filtrateValve.valveIn;
			connection filtrateOut connect filtrateValve.valveOut to filtrateDischarge;
			connection washFlow connect washValve.valveOut to chamber.washInlet;
			connection washSupply connect washWaterSupply to washValve.valveIn;
			connection clampConnect connect hydraulics to chamber;
			connection cmdPump connect controller.cmdFeedPump to pump.control;
			connection cmdFeedValve connect controller.cmdFeedValve to feedValve.control;
			connection cmdFiltrateValve connect controller.cmdFiltrateValve to filtrateValve.control;
			connection cmdHydraulic connect controller.cmdHydraulic to hydraulics.control;

			perform action operateCycle {
				in item slurry : 'Items and Values'::Slurry;
				in item washWater : 'Items and Values'::WashWater;
				out item filtrate : 'Items and Values'::Filtrate;
				out item cake : 'Items and Values'::FilterCake;

				action fillChamber {
					in item slurry = operateCycle::slurry;
					bind feedValve.isOpen = true;
					bind pump.dischargePressure = 100 [kPa];
					accept when controller.chamberFull;
				}
				action pressurizeAndFilter {
					out item filtrate = operateCycle::filtrate;
					bind hydraulics.systemPressure = 1500 [kPa];
					bind feedValve.isOpen = true;
					bind filtrateValve.isOpen = true;
					accept when controller.filtrateClear;
				}
				action holdPressure {
					attribute holdDuration : 'Items and Values'::DurationValue = 10 [min];
					accept after holdDuration;
				}
				action releaseAndDischarge {
					out item cake = operateCycle::cake;
					bind hydraulics.systemPressure = 0 [kPa];
					bind feedValve.isOpen = false;
					bind filtrateValve.isOpen = false;
					accept when controller.clampReleased;
					bind chamber.platesSeparated = true;
					accept when controller.cakeDischarged;
				}
				action washMedia {
					in item washWater = operateCycle::washWater;
					bind washValve.isOpen = true;
					attribute washDuration : 'Items and Values'::DurationValue = 5 [min];
					accept after washDuration;
					bind washValve.isOpen = false;
				}

				first start;
				then fillChamber;
				then pressurizeAndFilter;
				then holdPressure;
				then releaseAndDischarge;
				then washMedia;
				then done;
			}
		}
	}

	package 'Requirements' {
		requirement def FiltrateClarity {
			subject filtrate : 'Items and Values'::Filtrate;
			attribute minClarity : 'Items and Values'::PercentageValue = 0.98;
			constraint { filtrate.clarity >= minClarity }
		}
		requirement def CakeMoisture {
			subject cake : 'Items and Values'::FilterCake;
			attribute maxMoisture : 'Items and Values'::PercentageValue = 0.30;
			constraint { cake.moistureContent <= maxMoisture }
		}
		requirement def OperatingPressure {
			subject hydraulics : Components::HydraulicSystem;
			attribute maxPressure : 'Items and Values'::PressureValue = 1500 [kPa];
			constraint { hydraulics.systemPressure <= maxPressure }
		}
		requirement def CycleTime {
			subject system : 'Assembly'::FilterPressAssembly;
			attribute maxDuration : 'Items and Values'::DurationValue = 90 [min];
			constraint { system.controller.cycleTime <= maxDuration }
		}

		requirement def 'Filter Press Performance' {
			require FiltrateClarity;
			require CakeMoisture;
			require OperatingPressure;
			require CycleTime;
		}
	}

	part filterPress : 'Assembly'::FilterPressAssembly {
		satisfy 'Requirements'::FiltrateClarity;
		satisfy 'Requirements'::CakeMoisture;
		satisfy 'Requirements'::OperatingPressure;
		satisfy 'Requirements'::CycleTime;
	}
}
