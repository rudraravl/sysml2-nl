package 'Airspeed Indicator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DynamicPressureValue :> PressureValue;
	attribute def StaticPressureValue :> PressureValue;
	attribute def TotalPressureValue :> PressureValue;
	attribute def IndicatedAirspeedValue :> SpeedValue;
	attribute def TrueAirspeedValue :> SpeedValue;
	attribute def AirDensityValue :> MassDensityValue;
	attribute def TemperatureValue :> ThermodynamicTemperatureValue;
	attribute def AltitudeValue :> LengthValue;
	
	attribute def PowerOnSignal;
	attribute def PowerOffSignal;
	attribute def CalibrationSignal;
	
	item def PressureData {
		attribute totalPressure : TotalPressureValue;
		attribute staticPressure : StaticPressureValue;
		attribute dynamicPressure : DynamicPressureValue;
	}
	
	item def AirspeedData {
		attribute indicatedAirspeed : IndicatedAirspeedValue;
		attribute trueAirspeed : TrueAirspeedValue;
		attribute timestamp : Real;
	}
	
	item def EnvironmentalData {
		attribute airDensity : AirDensityValue;
		attribute temperature : TemperatureValue;
		attribute altitude : AltitudeValue;
	}
	
	port def PressureInputPort {
		in attribute pressureData : PressureData;
	}
	
	port def AirspeedOutputPort {
		out attribute airspeedData : AirspeedData;
	}
	
	port def EnvironmentalInputPort {
		in attribute envData : EnvironmentalData;
	}
	
	port def DisplayOutputPort {
		out attribute displaySpeed : IndicatedAirspeedValue;
	}
	
	part def PitotTube {
		doc /* Measures total pressure from ram air effect. */
		
		port totalPressureOut : PressureInputPort;
		
		attribute tubeArea : AreaValue;
		attribute heatingEnabled : Boolean;
	}
	
	part def StaticPressurePort {
		doc /* Measures ambient static pressure. */
		
		port staticPressureOut : PressureInputPort;
		
		attribute portCount : Integer;
		attribute portDiameter : LengthValue;
	}
	
	part def PressureTransducer {
		doc /* Converts pressure differential to electrical signal. */
		
		port totalPressureIn : PressureInputPort;
		port staticPressureIn : PressureInputPort;
		port pressureDataOut : PressureInputPort;
		
		attribute sensitivity : Real;
		attribute accuracy : Real;
		
		perform action convertPressure {
			in totalP : TotalPressureValue;
			in staticP : StaticPressureValue;
			out dynamicP : DynamicPressureValue;
			
			assign dynamicP := totalP - staticP;
		}
	}
	
	action def ComputeAirspeedValues {
		in attribute pressureData : PressureData;
		in attribute envData : EnvironmentalData;
		in attribute stdDensity : AirDensityValue;
		out attribute airspeedData : AirspeedData;
		
		first start;
		then action calcDynamic : CalculateDynamicPressure {
			in totalPressure = pressureData.totalPressure;
			in staticPressure = pressureData.staticPressure;
			out dynamicPressure;
		}
		then action calcIAS : ComputeIndicatedAirspeed {
			in dynamicPressure = calcDynamic.dynamicPressure;
			in standardDensity = stdDensity;
			out indicatedAirspeed;
		}
		then action calcTAS : ComputeTrueAirspeed {
			in indicatedAirspeed = calcIAS.indicatedAirspeed;
			in actualDensity = envData.airDensity;
			in standardDensity = stdDensity;
			out trueAirspeed;
		}
		then assign airspeedData.indicatedAirspeed := calcIAS.indicatedAirspeed;
		then assign airspeedData.trueAirspeed := calcTAS.trueAirspeed;
		then done;
	}
	
	part def AirDataComputer {
		doc /* Processes pressure data and computes airspeed values. */
		
		port pressureIn : PressureInputPort;
		port environmentalIn : EnvironmentalInputPort;
		port airspeedOut : AirspeedOutputPort;
		
		attribute standardAirDensity : AirDensityValue := 1.225 [kg/(m^3)];
		attribute computationRate : Real;
		
		perform action computeAirspeed : ComputeAirspeedValues {
			in pressureData = pressureIn.pressureData;
			in envData = environmentalIn.envData;
			in stdDensity = standardAirDensity;
			out airspeedData;
		}
	}
	
	part def CockpitDisplay {
		doc /* Displays airspeed information to pilot. */
		
		port airspeedIn : AirspeedOutputPort;
		port displayOut : DisplayOutputPort;
		
		attribute minDisplaySpeed : IndicatedAirspeedValue;
		attribute maxDisplaySpeed : IndicatedAirspeedValue;
		attribute displayResolution : SpeedValue;
		attribute backlightIntensity : Real;
		
		state displayStateMachine {
			entry; then powerOff;
			
			state powerOff {
				entry assign displayOut.displaySpeed := 0.0 [m/s];
			}
			
			transition powerOff_to_selfTest
				first powerOff
				accept PowerOnSignal
				then selfTest;
			
			state selfTest {
				doc /* Performs display self-test sequence. */
				entry; then testSequence;
				
				state testSequence;
			}
			
			transition selfTest_to_operational
				first selfTest
				then operational;
			
			state operational {
				entry; then displaying;
				
				state displaying {
					do action updateDisplay {
						in speedData = airspeedIn.airspeedData;
						
						assign displayOut.displaySpeed := speedData.indicatedAirspeed;
					}
				}
			}
			
			transition operational_to_powerOff
				first operational
				accept PowerOffSignal
				then powerOff;
		}
	}
	
	action def MeasureTotalPressure {
		in attribute airflowVelocity : SpeedValue;
		in attribute staticPressure : StaticPressureValue;
		out attribute totalPressure : TotalPressureValue;
	}
	
	action def MeasureStaticPressure {
		in attribute ambientPressure : PressureValue;
		out attribute staticPressure : StaticPressureValue;
	}
	
	action def CalculateDynamicPressure {
		in attribute totalPressure : TotalPressureValue;
		in attribute staticPressure : StaticPressureValue;
		out attribute dynamicPressure : DynamicPressureValue;
		
		assign dynamicPressure := totalPressure - staticPressure;
	}
	
	action def ComputeIndicatedAirspeed {
		in attribute dynamicPressure : DynamicPressureValue;
		in attribute standardDensity : AirDensityValue;
		out attribute indicatedAirspeed : IndicatedAirspeedValue;
	}
	
	action def ComputeTrueAirspeed {
		in attribute indicatedAirspeed : IndicatedAirspeedValue;
		in attribute actualDensity : AirDensityValue;
		in attribute standardDensity : AirDensityValue;
		out attribute trueAirspeed : TrueAirspeedValue;
	}
	
	action def MonitorAirspeed {
		in attribute currentSpeed : IndicatedAirspeedValue;
		in attribute minSpeed : IndicatedAirspeedValue;
		in attribute maxSpeed : IndicatedAirspeedValue;
		out attribute stallWarning : Boolean;
		out attribute overspeedWarning : Boolean;
		
		first start;
		then decide;
			if currentSpeed < minSpeed then setStallWarning;
			if currentSpeed > maxSpeed then setOverspeedWarning;
			if currentSpeed >= minSpeed and currentSpeed <= maxSpeed then clearWarnings;
		
		action setStallWarning {
			assign stallWarning := true;
			assign overspeedWarning := false;
		}
		then done;
		
		action setOverspeedWarning {
			assign stallWarning := false;
			assign overspeedWarning := true;
		}
		then done;
		
		action clearWarnings {
			assign stallWarning := false;
			assign overspeedWarning := false;
		}
		then done;
	}
	
	connection def PressureConnection {
		end source : PressureInputPort;
		end target : PressureInputPort;
	}
	
	connection def AirspeedConnection {
		end source : AirspeedOutputPort;
		end target : AirspeedOutputPort;
	}
	
	connection def EnvironmentalConnection {
		end source : EnvironmentalInputPort;
		end target : EnvironmentalInputPort;
	}
	
	part def AirspeedIndicator {
		doc /* 
		 * An airspeed indicator measures and displays the speed of an aircraft 
		 * relative to the surrounding air mass by sensing the difference between 
		 * total pressure (pitot) and static pressure, converting this differential 
		 * into indicated airspeed, and presenting the information to the pilot.
		 */
		
		port finalAirspeedOutput : AirspeedOutputPort;
		port environmentalInput : EnvironmentalInputPort;
		
		part pitotTube : PitotTube {
			attribute tubeArea = 0.0005 [m^2];
			attribute heatingEnabled = true;
		}
		
		part staticPort : StaticPressurePort {
			attribute portCount = 2;
			attribute portDiameter = 0.003 [m];
		}
		
		part transducer : PressureTransducer {
			attribute sensitivity = 0.98;
			attribute accuracy = 0.02;
		}
		
		part computer : AirDataComputer {
			attribute standardAirDensity = 1.225 [kg/(m^3)];
			attribute computationRate = 10.0;
		}
		
		part display : CockpitDisplay {
			attribute minDisplaySpeed = 20.0 [m/s];
			attribute maxDisplaySpeed = 150.0 [m/s];
			attribute displayResolution = 0.5 [m/s];
			attribute backlightIntensity = 0.8;
		}
		
		connection pitotConnection : PressureConnection
			connect pitotTube.totalPressureOut to transducer.totalPressureIn;
		
		connection staticConnection : PressureConnection
			connect staticPort.staticPressureOut to transducer.staticPressureIn;
		
		connection transducerConnection : PressureConnection
			connect transducer.pressureDataOut to computer.pressureIn;
		
		connection environmentalConnection : EnvironmentalConnection
			connect environmentalInput to computer.environmentalIn;
		
		connection computerConnection : AirspeedConnection
			connect computer.airspeedOut to display.airspeedIn;
		
		connection displayConnection : AirspeedConnection
			connect computer.airspeedOut to finalAirspeedOutput;
		
		perform action measureAndDisplayAirspeed {
			first start;
			then merge continueMeasurement;
			then action measure : ComputeAirspeedValues {
				in pressureData = transducer.pressureDataOut.pressureData;
				in envData = environmentalInput.envData;
				in stdDensity = computer.standardAirDensity;
				out airspeedData;
			}
			then action monitor : MonitorAirspeed {
				in currentSpeed = measure.airspeedData.indicatedAirspeed;
				in minSpeed = display.minDisplaySpeed;
				in maxSpeed = display.maxDisplaySpeed;
				out stallWarning;
				out overspeedWarning;
			}
			then continueMeasurement;
		}
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	
	requirement <'ASI-REQ-001'> primaryFunction : FunctionalRequirement {
		doc /* 
		 * The airspeed indicator system shall measure the differential pressure 
		 * between pitot and static sources, compute indicated and true airspeed, 
		 * and display the airspeed to the pilot continuously during flight.
		 */
	}
	
	requirement <'ASI-REQ-002'> accuracyRequirement : PerformanceRequirement {
		doc /* 
		 * The indicated airspeed shall be accurate to within ±3 knots or ±3% 
		 * of the indicated value, whichever is greater, across the operational 
		 * speed range under standard atmospheric conditions.
		 */
	}
	
	requirement <'ASI-REQ-003'> responseTime : PerformanceRequirement {
		doc /* 
		 * The airspeed indicator shall update the displayed airspeed value 
		 * at a minimum rate of 10 Hz to provide smooth and timely indication 
		 * of airspeed changes.
		 */
	}
	
	requirement <'ASI-REQ-004'> operatingRange : PerformanceRequirement {
		doc /* 
		 * The airspeed indicator shall operate accurately for indicated airspeeds 
		 * from 0 to 300 knots and altitudes from sea level to 30000 feet.
		 */
	}
	
	requirement <'ASI-REQ-005'> stallWarning : SafetyRequirement {
		doc /* 
		 * The system shall provide a warning indication when the indicated 
		 * airspeed falls below the minimum safe operating speed.
		 */
	}
	
	requirement <'ASI-REQ-006'> overspeedWarning : SafetyRequirement {
		doc /* 
		 * The system shall provide a warning indication when the indicated 
		 * airspeed exceeds the maximum safe operating speed.
		 */
	}
	
	requirement <'ASI-REQ-007'> pitotHeating : SafetyRequirement {
		doc /* 
		 * The pitot tube shall include heating capability to prevent ice 
		 * formation during flight in icing conditions.
		 */
	}
	
	requirement <'ASI-SYS-001'> systemRequirements {
		doc /* Top-level requirements for the airspeed indicator system. */
		
		subject indicatorSystem : AirspeedIndicator;
		
		assume constraint pitotStaticIntegrity {
			doc /* The pitot-static system shall be free from blockages, leaks, and contamination. */
		}
		
		assume constraint powerAvailability {
			doc /* Electrical power shall be available to the system during operation. */
		}
		
		require primaryFunction;
		require accuracyRequirement;
		require responseTime;
		require operatingRange;
		require stallWarning;
		require overspeedWarning;
		require pitotHeating;
	}
	
	part aircraftAirspeedIndicator : AirspeedIndicator;
	
	satisfy primaryFunction by aircraftAirspeedIndicator.measureAndDisplayAirspeed;
	satisfy accuracyRequirement by aircraftAirspeedIndicator.computer.computeAirspeed;
	satisfy responseTime by aircraftAirspeedIndicator.computer.computeAirspeed;
	satisfy operatingRange by aircraftAirspeedIndicator;
	satisfy stallWarning by aircraftAirspeedIndicator.measureAndDisplayAirspeed;
	satisfy overspeedWarning by aircraftAirspeedIndicator.measureAndDisplayAirspeed;
	satisfy pitotHeating by aircraftAirspeedIndicator.pitotTube;
}
