package 'Bernoulli Principle Airspeed System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def StaticPressure :> PressureValue;
	attribute def DynamicPressure :> PressureValue;
	attribute def TotalPressure :> PressureValue;
	attribute def Airspeed :> SpeedValue;
	attribute def AirDensity :> MassDensityValue;
	attribute def PitotAngle :> Real;
	
	item def PressureReading {
		attribute staticPressure : StaticPressure;
		attribute totalPressure : TotalPressure;
		attribute timestamp : Real;
	}
	
	item def AirspeedData {
		attribute indicatedAirspeed : Airspeed;
		attribute dynamicPressure : DynamicPressure;
		attribute valid : Boolean;
	}
	
	port def PressurePort {
		out item reading : PressureReading;
	}
	
	port def DataPort {
		in item airspeedData : AirspeedData;
	}
	
	action def SensePressure {
		in location : String;
		out pressure : PressureValue;
	}
	
	action def CalculateDynamicPressure {
		in totalPressure : TotalPressure;
		in staticPressure : StaticPressure;
		out dynamicPressure : DynamicPressure;
	}
	
	action def ComputeAirspeed {
		in dynamicPressure : DynamicPressure;
		in airDensity : AirDensity;
		out airspeed : Airspeed;
	}
	
	action def ValidateReading {
		in airspeed : Airspeed;
		in dynamicPressure : DynamicPressure;
		out isValid : Boolean;
	}
	
	part def PitotTube {
		attribute alignment : PitotAngle;
		attribute totalPressureTap : LengthValue;
		
		port totalPressurePort : PressurePort;
		port staticPressurePort : PressurePort;
		
		part totalPressureSensor {
			port sensingPort;
			out attribute measuredTotalPressure : TotalPressure;
		}
		
		part staticPressureSensor {
			port sensingPort;
			out attribute measuredStaticPressure : StaticPressure;
		}
		
		connect totalPressurePort to totalPressureSensor.sensingPort;
		connect staticPressurePort to staticPressureSensor.sensingPort;
	}
	
	part def AirDataComputer {
		attribute calibrationFactor : Real;
		attribute densityCorrection : Real;
		
		port pressureInputPort;
		port airspeedOutputPort : DataPort;
		
		attribute computedAirspeed : Airspeed;
		attribute computedDynamicPressure : DynamicPressure;
	}
	
	part def DisplayUnit {
		attribute displayedSpeed : Airspeed;
		attribute displayUnits : String;
		attribute updateRate : FrequencyValue;
		
		port dataInputPort : DataPort;
	}
	
	part def Atmosphere {
		attribute seaLevelDensity : AirDensity;
		attribute currentDensity : AirDensity;
		attribute temperature : TemperatureValue;
		attribute altitude : LengthValue;
	}
	
	part pitotStaticSystem {
		attribute operatingDensity : AirDensity;
		attribute minimumAirspeed : Airspeed;
		attribute maximumAirspeed : Airspeed;
		
		part pitotProbe : PitotTube {
			attribute :>> alignment = 0.0;
		}
		
		part airDataComputer : AirDataComputer {
			attribute :>> calibrationFactor = 1.0;
		}
		
		part cockpitDisplay : DisplayUnit {
			attribute :>> displayUnits = "knots";
			attribute :>> updateRate = 10.0;
		}
		
		part environment : Atmosphere {
			attribute :>> seaLevelDensity = 1.225;
			attribute :>> currentDensity = operatingDensity;
		}
		
		connect pitotProbe.totalPressurePort to airDataComputer.pressureInputPort;
		connect pitotProbe.staticPressurePort to airDataComputer.pressureInputPort;
		connect airDataComputer.airspeedOutputPort to cockpitDisplay.dataInputPort;
		
		action measureAndComputeAirspeed {
			first start;
			
			then action senseTotalPressure : SensePressure {
				in location = "pitot";
				out totalP : PressureValue;
			}
			
			flow from pitotProbe.totalPressureSensor.measuredTotalPressure to senseTotalPressure.pressure;
			
			then action senseStaticPressure : SensePressure {
				in location = "static";
				out staticP : PressureValue;
			}
			
			flow from pitotProbe.staticPressureSensor.measuredStaticPressure to senseStaticPressure.pressure;
			
			then action calculateDynamic : CalculateDynamicPressure {
				in totalPressure : TotalPressure = senseTotalPressure.totalP;
				in staticPressure : StaticPressure = senseStaticPressure.staticP;
				out qc : DynamicPressure;
			}
			
			then action computeSpeed : ComputeAirspeed {
				in dynamicPressure : DynamicPressure = calculateDynamic.qc;
				in airDensity : AirDensity = operatingDensity;
				out velocity : Airspeed;
			}
			
			then action validate : ValidateReading {
				in airspeed : Airspeed = computeSpeed.velocity;
				in dynamicPressure : DynamicPressure = calculateDynamic.qc;
				out valid : Boolean;
			}
			
			then decide;
				if validate.valid then updateDisplay;
				else rejectReading;
			
			action updateDisplay {
				assign airDataComputer.computedAirspeed := computeSpeed.velocity;
				assign airDataComputer.computedDynamicPressure := calculateDynamic.qc;
				assign cockpitDisplay.displayedSpeed := computeSpeed.velocity;
			}
			then done;
			
			action rejectReading {
				assign cockpitDisplay.displayedSpeed := 0.0;
			}
			then done;
		}
	}
	
	state def AirspeedMeasurementStates {
		entry; then initialization;
		
		state initialization {
			entry assign pitotStaticSystem.airDataComputer.computedAirspeed := 0.0;
		}
		
		transition init_to_standby
			first initialization
			accept SystemPowerOn
			then standby;
		
		state standby {
			entry assign pitotStaticSystem.cockpitDisplay.displayedSpeed := 0.0;
		}
		
		transition standby_to_active
			first standby
			accept AirflowDetected
			then activeMeasurement;
		
		state activeMeasurement {
			entry; then continuousUpdate;
			
			state continuousUpdate;
			
			do action performContinuousMeasurement {
				action executeMeasurement : pitotStaticSystem.measureAndComputeAirspeed;
			}
		}
		
		transition active_to_standby
			first activeMeasurement
			accept AirflowCeased
			then standby;
		
		transition standby_to_shutdown
			first standby
			accept SystemPowerOff
			then shutdown;
		
		state shutdown;
	}
	
	item def SystemPowerOn;
	item def SystemPowerOff;
	item def AirflowDetected;
	item def AirflowCeased;
	
	requirement def <'REQ-100'> BernoulliPrincipleApplication {
		doc /*
		The system shall apply Bernoulli's principle to measure airspeed by converting
		the difference between total pressure (stagnation pressure at the pitot tube)
		and static pressure (ambient atmospheric pressure) into dynamic pressure,
		which is directly related to the square of the airspeed.
		*/
		
		subject system : pitotStaticSystem;
		
		require constraint pressureDifferenceExists {
			doc /*
			A measurable pressure difference shall exist between total and static pressure
			when airflow is present.
			*/
			system.pitotProbe.totalPressureSensor.measuredTotalPressure >= 
			system.pitotProbe.staticPressureSensor.measuredStaticPressure
		}
	}
	
	requirement def <'REQ-101'> AirspeedAccuracy {
		doc /*
		The system shall compute airspeed with accuracy dependent on precise pressure
		differential measurement and correct air density compensation.
		*/
		
		subject computation : pitotStaticSystem.measureAndComputeAirspeed;
		
		require constraint densityKnown {
			doc /*
			The air density shall be known or estimated for accurate airspeed calculation.
			*/
			pitotStaticSystem.operatingDensity > 0.0
		}
		
		require constraint validRange {
			doc /*
			Computed airspeed shall fall within the operational range of the system.
			*/
			pitotStaticSystem.airDataComputer.computedAirspeed >= pitotStaticSystem.minimumAirspeed and
			pitotStaticSystem.airDataComputer.computedAirspeed <= pitotStaticSystem.maximumAirspeed
		}
	}
	
	requirement def <'REQ-102'> SystemPrimaryFunction {
		doc /*
		The primary function of the pitot-static system is to continuously measure
		and display aircraft airspeed by exploiting Bernoulli's principle, which
		establishes that in a moving fluid, an increase in velocity occurs simultaneously
		with a decrease in pressure. The system measures total pressure where the airflow
		is brought to rest (stagnation point) and compares it to the static ambient pressure,
		using the pressure differential to determine the dynamic pressure and thus the airspeed.
		*/
		
		subject system : pitotStaticSystem;
		
		assume constraint incompressibleFlow {
			doc /*
			The airflow is assumed to be incompressible at low subsonic speeds.
			*/
			pitotStaticSystem.maximumAirspeed < 100.0
		}
		
		assume constraint steadyState {
			doc /*
			The flow conditions are assumed to be in steady state during measurement.
			*/
			true
		}
		
		require constraint continuousOperation {
			doc /*
			The system shall provide continuous airspeed indication during flight.
			*/
			true
		}
		
		require constraint displayUpdate {
			doc /*
			The display shall update at a rate sufficient for pilot awareness.
			*/
			pitotStaticSystem.cockpitDisplay.updateRate >= 5.0
		}
	}
	
	requirement systemRequirements {
		subject system : pitotStaticSystem;
		
		require BernoulliPrincipleApplication;
		require AirspeedAccuracy;
		require SystemPrimaryFunction;
	}
}
