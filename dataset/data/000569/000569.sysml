package 'Charcot Shower Hydrotherapy System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def WaterTemperature :> ThermodynamicTemperatureValue;
	attribute def WaterPressure :> PressureValue;
	attribute def WaterFlowRate :> VolumeFlowRateValue;
	attribute def TreatmentDuration :> TimeValue;
	attribute def ValvePosition :> Real;

	attribute def TherapyParameters {
		attribute hotTemperature : WaterTemperature;
		attribute coldTemperature : WaterTemperature;
		attribute hotPhaseDuration : TreatmentDuration;
		attribute coldPhaseDuration : TreatmentDuration;
		attribute numberOfCycles : Integer;
		attribute targetPressure : WaterPressure;
	}

	item def Water {
		attribute temperature : WaterTemperature;
		attribute pressure : WaterPressure;
		attribute flowRate : WaterFlowRate;
	}

	port def WaterSupplyPort {
		out item hotWater : Water;
		out item coldWater : Water;
	}

	port def MixedWaterPort {
		out item mixedWater : Water;
	}

	port def ControlPort {
		in attribute setpoint : WaterTemperature;
		in attribute pressureSetpoint : WaterPressure;
		out attribute valveCommand : ValvePosition;
	}

	port def TherapyCommandPort {
		in attribute therapyParams : TherapyParameters;
		in attribute startCommand : ScalarValues::Boolean;
		in attribute stopCommand : ScalarValues::Boolean;
		out attribute currentPhase : String;
	}

	part def WaterHeater {
		port waterIn : WaterSupplyPort;
		port hotWaterOut : MixedWaterPort;
		attribute targetTemperature : WaterTemperature;
		attribute heatingPower : PowerValue;
	}

	part def WaterChiller {
		port waterIn : WaterSupplyPort;
		port coldWaterOut : MixedWaterPort;
		attribute targetTemperature : WaterTemperature;
		attribute coolingCapacity : PowerValue;
	}

	part def MixingValveAssembly {
		port hotWaterIn : MixedWaterPort;
		port coldWaterIn : MixedWaterPort;
		port mixedWaterOut : MixedWaterPort;
		port controlInput : ControlPort;
		attribute hotValvePosition : ValvePosition;
		attribute coldValvePosition : ValvePosition;
	}

	part def PressureRegulator {
		port waterIn : MixedWaterPort;
		port waterOut : MixedWaterPort;
		attribute regulatedPressure : WaterPressure;
		attribute maxPressure : WaterPressure;
	}

	part def JetNozzleArray {
		port waterIn : MixedWaterPort;
		attribute numberOfJets : Integer;
		attribute jetDiameter : LengthValue;
		attribute sprayAngle : Real;
	}

	part def TherapyControlUnit {
		port therapyCommand : TherapyCommandPort;
		port valveControl : ControlPort;
		attribute activeTherapy : TherapyParameters;
		attribute currentCycleNumber : Integer;
		attribute isHotPhase : ScalarValues::Boolean;
		attribute elapsedTime : TreatmentDuration;
	}

	part def TemperatureSensor {
		port waterMonitor : MixedWaterPort;
		attribute measuredTemperature : WaterTemperature;
		attribute accuracy : WaterTemperature;
	}

	part def PressureSensor {
		port waterMonitor : MixedWaterPort;
		attribute measuredPressure : WaterPressure;
		attribute accuracy : WaterPressure;
	}

	part def SafetyShutoffValve {
		port waterIn : MixedWaterPort;
		port waterOut : MixedWaterPort;
		port emergencyControl : ControlPort;
		attribute isOpen : ScalarValues::Boolean;
		attribute maxSafeTemperature : WaterTemperature;
	}

	action def HeatWater {
		in coldWaterInput : Water;
		in targetTemp : WaterTemperature;
		out heatedWater : Water;
	}

	action def ChillWater {
		in warmWaterInput : Water;
		in targetTemp : WaterTemperature;
		out chilledWater : Water;
	}

	action def MixWaterStreams {
		in hotStream : Water;
		in coldStream : Water;
		in hotValvePos : ValvePosition;
		in coldValvePos : ValvePosition;
		out mixedStream : Water;
	}

	action def RegulatePressure {
		in inputWater : Water;
		in targetPressure : WaterPressure;
		out regulatedWater : Water;
	}

	action def MonitorTemperature {
		in waterStream : Water;
		out currentTemperature : WaterTemperature;
	}

	action def CalculateValvePosition {
		in currentTemp : WaterTemperature;
		in targetTemp : WaterTemperature;
		out hotValvePosition : ValvePosition;
		out coldValvePosition : ValvePosition;
	}

	action def DeliverContrastTherapy {
		in therapySettings : TherapyParameters;
		out treatmentComplete : ScalarValues::Boolean;

		first start;
		then merge beginCycle;

		action initializeTreatment {
			out cycleCounter : Integer := 0;
			out phaseIsHot : ScalarValues::Boolean := true;
		}

		then beginCycle;

		then decide;
			if initializeTreatment.cycleCounter < therapySettings.numberOfCycles then executeHotPhase;
			if initializeTreatment.cycleCounter >= therapySettings.numberOfCycles then completeTreatment;

		action executeHotPhase {
			in hotTemp : WaterTemperature := therapySettings.hotTemperature;
			in duration : TreatmentDuration := therapySettings.hotPhaseDuration;
			out phaseOutput : Water;

			action setHotTemperature {
				in targetTemp : WaterTemperature := hotTemp;
				out valveSettings : ValvePosition;
			}

			then action maintainHotPhase {
				in phaseDuration : TreatmentDuration := duration;
				out phaseWater : Water;
			}
		}

		then action executeColdPhase {
			in coldTemp : WaterTemperature := therapySettings.coldTemperature;
			in duration : TreatmentDuration := therapySettings.coldPhaseDuration;
			out phaseOutput : Water;

			action setColdTemperature {
				in targetTemp : WaterTemperature := coldTemp;
				out valveSettings : ValvePosition;
			}

			then action maintainColdPhase {
				in phaseDuration : TreatmentDuration := duration;
				out phaseWater : Water;
			}
		}

		then action incrementCycleCount {
			in currentCount : Integer := initializeTreatment.cycleCounter;
			out updatedCount : Integer := currentCount + 1;
		}

		then assign initializeTreatment.cycleCounter := incrementCycleCount.updatedCount;
		then beginCycle;

		action completeTreatment {
			out complete : ScalarValues::Boolean := true;
		}

		then done;
	}

	state def CharcotShowerStates {
		entry action enterState;
		do action activeState;
		exit action exitState;

		state Standby {
			doc /* System is powered but inactive, awaiting therapy initiation. */
		}

		state Initializing {
			doc /* System is preparing water supplies and verifying safety conditions. */
			entry action checkSafety;
			do action primeWaterLines;
		}

		state HotPhaseActive {
			doc /* Delivering hot water therapy at specified temperature and pressure. */
			entry action activateHotWater;
			do action maintainHotTemperature;
		}

		state ColdPhaseActive {
			doc /* Delivering cold water therapy at specified temperature and pressure. */
			entry action activateColdWater;
			do action maintainColdTemperature;
		}

		state TransitioningPhase {
			doc /* Switching between hot and cold phases. */
			do action adjustValves;
		}

		state EmergencyShutdown {
			doc /* Safety shutdown due to temperature or pressure fault. */
			entry action closeAllValves;
			do action drainSystem;
		}

		state TreatmentComplete {
			doc /* Therapy cycle completed successfully. */
			entry action returnToStandby;
		}

		transition first then Standby;

		transition Standby then Initializing
			accept startCommand : ScalarValues::Boolean;

		transition Initializing then HotPhaseActive
			if checkSafety.safetyVerified;

		transition HotPhaseActive then TransitioningPhase
			if maintainHotTemperature.phaseDurationElapsed;

		transition TransitioningPhase then ColdPhaseActive
			if adjustValves.transitionComplete;

		transition ColdPhaseActive then TransitioningPhase
			if maintainColdTemperature.phaseDurationElapsed;

		transition TransitioningPhase then HotPhaseActive
			if adjustValves.nextCycleRequired;

		transition ColdPhaseActive then TreatmentComplete
			if maintainColdTemperature.allCyclesComplete;

		transition TreatmentComplete then Standby;

		transition HotPhaseActive then EmergencyShutdown
			accept emergencyStop : ScalarValues::Boolean;

		transition ColdPhaseActive then EmergencyShutdown
			accept emergencyStop : ScalarValues::Boolean;

		transition EmergencyShutdown then Standby
			if drainSystem.systemSafe;
	}

	part def CharcotShowerSystem;

	part charcotShowerSystem : CharcotShowerSystem {
		doc /* 
		A Charcot shower is a specialized hydrotherapy system that delivers alternating 
		streams of hot and cold water at controlled pressure to provide therapeutic contrast 
		treatment. Its primary function is to administer programmed cycles of thermal contrast 
		therapy by rapidly alternating between hot water (typically 38-42°C) and cold water 
		(typically 10-18°C) delivered through high-pressure jets. This thermal cycling promotes 
		circulation, reduces inflammation, stimulates the nervous system, and provides pain 
		relief through controlled vascular response. The system precisely controls water 
		temperature, pressure, cycle timing, and number of repetitions to deliver safe and 
		effective therapeutic treatment.
		*/

		port facilityWaterSupply : WaterSupplyPort;
		port therapyControl : TherapyCommandPort;

		part heater : WaterHeater {
			targetTemperature := 40 [degC];
			heatingPower := 12 [kW];
		}

		part chiller : WaterChiller {
			targetTemperature := 15 [degC];
			coolingCapacity := 8 [kW];
		}

		part mixingValve : MixingValveAssembly;

		part pressureReg : PressureRegulator {
			regulatedPressure := 300 [kPa];
			maxPressure := 500 [kPa];
		}

		part nozzles : JetNozzleArray {
			numberOfJets := 12;
			jetDiameter := 3 [mm];
			sprayAngle := 25.0;
		}

		part controller : TherapyControlUnit {
			currentCycleNumber := 0;
			isHotPhase := true;
		}

		part tempSensor : TemperatureSensor {
			accuracy := 0.5 [degC];
		}

		part pressureSensor : PressureSensor {
			accuracy := 5 [kPa];
		}

		part safetyValve : SafetyShutoffValve {
			isOpen := false;
			maxSafeTemperature := 45 [degC];
		}

		connect facilityWaterSupply to heater.waterIn;
		connect facilityWaterSupply to chiller.waterIn;
		connect heater.hotWaterOut to mixingValve.hotWaterIn;
		connect chiller.coldWaterOut to mixingValve.coldWaterIn;
		connect mixingValve.mixedWaterOut to safetyValve.waterIn;
		connect safetyValve.waterOut to pressureReg.waterIn;
		connect pressureReg.waterOut to nozzles.waterIn;
		connect controller.valveControl to mixingValve.controlInput;
		connect therapyControl to controller.therapyCommand;
		connect tempSensor.waterMonitor to pressureReg.waterOut;
		connect pressureSensor.waterMonitor to pressureReg.waterOut;

		perform action deliverTherapy : DeliverContrastTherapy;

		exhibit state operationalState : CharcotShowerStates;
	}

	requirement def TherapeuticRequirement;
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;

	requirement <'REQ-001'> contrastTherapyDelivery : TherapeuticRequirement {
		doc /* 
		The system shall deliver alternating hot and cold water therapy in programmed 
		cycles to provide effective contrast hydrotherapy treatment.
		*/
		subject charcotShowerSystem;
		require hotWaterTemperatureRange;
		require coldWaterTemperatureRange;
		require cycleTimingControl;
	}

	requirement <'REQ-002'> hotWaterTemperatureRange : TherapeuticRequirement {
		doc /* 
		Hot water phase shall maintain temperature between 38°C and 42°C 
		with accuracy of ±0.5°C.
		*/
		subject charcotShowerSystem.heater;
	}

	requirement <'REQ-003'> coldWaterTemperatureRange : TherapeuticRequirement {
		doc /* 
		Cold water phase shall maintain temperature between 10°C and 18°C 
		with accuracy of ±0.5°C.
		*/
		subject charcotShowerSystem.chiller;
	}

	requirement <'REQ-004'> cycleTimingControl : PerformanceRequirement {
		doc /* 
		System shall support configurable hot phase duration (60-300 seconds) 
		and cold phase duration (15-90 seconds) with timing accuracy of ±2 seconds.
		*/
		subject charcotShowerSystem.controller;
	}

	requirement <'REQ-005'> pressureRegulation : PerformanceRequirement {
		doc /* 
		Water delivery pressure shall be regulated to 300 kPa ±25 kPa 
		at the nozzle array for consistent therapeutic effect.
		*/
		subject charcotShowerSystem.pressureReg;
	}

	requirement <'REQ-006'> temperatureTransitionSpeed : PerformanceRequirement {
		doc /* 
		Transition between hot and cold phases shall occur within 5 seconds 
		to maximize therapeutic contrast effect.
		*/
		subject charcotShowerSystem.mixingValve;
	}

	requirement <'REQ-007'> overtemperatureProtection : SafetyRequirement {
		doc /* 
		System shall automatically shut off water flow if temperature exceeds 
		45°C to prevent scalding injury.
		*/
		subject charcotShowerSystem.safetyValve;
	}

	requirement <'REQ-008'> emergencyShutoff : SafetyRequirement {
		doc /* 
		System shall provide immediate emergency shutoff capability accessible 
		within 1 second of activation.
		*/
		subject charcotShowerSystem.controller;
	}

	requirement <'REQ-009'> temperatureMonitoring : SafetyRequirement {
		doc /* 
		System shall continuously monitor water temperature with sampling 
		rate of at least 2 Hz and accuracy of ±0.5°C.
		*/
		subject charcotShowerSystem.tempSensor;
	}

	requirement <'REQ-010'> cycleProgrammability : PerformanceRequirement {
		doc /* 
		System shall support programming of 1 to 10 complete hot-cold cycles 
		per treatment session.
		*/
		subject charcotShowerSystem.controller;
	}

	satisfy contrastTherapyDelivery by charcotShowerSystem.deliverTherapy;
	satisfy hotWaterTemperatureRange by charcotShowerSystem.heater;
	satisfy coldWaterTemperatureRange by charcotShowerSystem.chiller;
	satisfy pressureRegulation by charcotShowerSystem.pressureReg;
	satisfy overtemperatureProtection by charcotShowerSystem.safetyValve;
	satisfy temperatureMonitoring by charcotShowerSystem.tempSensor;
}
