package RVDT_System {
	import ScalarValues::*;
	import ISQ::*;
	import ISQSpace::*;
	import ISQElectricity::*;
	import ISQEnergy::*;
	import ISQThermodynamics::*;
	
	// ===== Value Types =====
	
	value def AngleDeg :> Real {
		unit 'deg' = 1 [deg];
	}
	
	value def VoltageAC :> Real {
		unit 'V' = 1 [V];
	}
	
	value def FrequencyHz :> Real {
		unit 'Hz' = 1 [Hz];
	}
	
	value def TemperatureC :> Real {
		unit 'degC' = 1 [degC];
	}
	
	value def LinearityError :> Real {
		unit '%' = 1 [%];
	}
	
	value def PhaseAngle :> Real {
		unit 'deg' = 1 [deg];
	}
	
	value def CalibrationFactor :> Real {
		unit 'count/deg' = 1 [count/deg];
	}
	
	value def TemperatureCoeff :> Real {
		unit 'ppm/degC' = 1 [ppm/degC];
	}
	
	value def MagneticFluxDensity :> Real {
		unit 'T' = 1 [T];
	}
	
	value def AngularVelocity :> Real {
		unit 'deg/s' = 1 [deg/s];
	}
	
	// ===== Item Types =====
	
	item def ExcitationSignal {
		attr amplitude : VoltageAC;
		attr frequency : FrequencyHz;
		attr phase : PhaseAngle;
	}
	
	item def SecondaryVoltage {
		attr amplitude : VoltageAC;
		attr phase : PhaseAngle;
	}
	
	item def DemodulatedSignal {
		attr differentialAmplitude : VoltageAC;
		attr phaseSign : Integer;
		attr valid : Boolean;
	}
	
	item def AngleMeasurement {
		attr angle : AngleDeg;
		attr temperatureCompensated : Boolean;
		attr calibrated : Boolean;
		attr timestamp : Time;
	}
	
	item def CalibrationData {
		attr slope : CalibrationFactor;
		attr offset : AngleDeg;
		attr tempCoeff : TemperatureCoeff;
		attr referenceTemp : TemperatureC;
	}
	
	item def TemperatureReading {
		attr value : TemperatureC;
	}
	
	// ===== Port Definitions =====
	
	port def ExcitationPort {
		out excitation : ExcitationSignal;
	}
	
	port def SecondaryOutputPort {
		out secondaryA : SecondaryVoltage;
		out secondaryB : SecondaryVoltage;
	}
	
	port def DemodulatedPort {
		out demodulated : DemodulatedSignal;
	}
	
	port def MeasurementPort {
		out measurement : AngleMeasurement;
	}
	
	port def ShaftInputPort {
		in shaftAngle : AngleDeg;
		in shaftVelocity : AngularVelocity;
	}
	
	port def TemperaturePort {
		out temperature : TemperatureReading;
	}
	
	port def PowerPort {
		in supplyVoltage : VoltageAC;
		in supplyFrequency : FrequencyHz;
	}
	
	// ===== Requirements =====
	
	requirement def RVDT_Requirements {
		req OperationalRange {
			doc /* The RVDT shall measure angular position over a full 360-degree range. */
			assert constraint { self.measurementRange >= 360 [deg] }
		}
		
		req LinearityAccuracy {
			doc /* The RVDT shall maintain a linearity error of less than 0.5% of full scale. */
			assert constraint { self.maxLinearityError <= 0.5 [%] }
		}
		
		req TemperatureRange {
			doc /* The RVDT shall operate across a wide temperature spectrum from -55C to +125C. */
			assert constraint { self.minTemp <= -55 [degC] and self.maxTemp >= 125 [degC] }
		}
		
		req ExcitationCompatibility {
			doc /* The RVDT shall accept excitation frequencies from 400 Hz to 10 kHz. */
			assert constraint { self.minExcFreq <= 400 [Hz] and self.maxExcFreq >= 10000 [Hz] }
		}
		
		req ContactlessOperation {
			doc /* The RVDT shall use a contactless magnetic coupling design for long operational life. */
		}
		
		req ResponseTime {
			doc /* The RVDT shall produce a valid angle measurement within 2 ms of shaft movement. */
			assert constraint { self.maxResponseTime <= 2 [ms] }
		}
		
		attr measurementRange : AngleDeg;
		attr maxLinearityError : LinearityError;
		attr minTemp : TemperatureC;
		attr maxTemp : TemperatureC;
		attr minExcFreq : FrequencyHz;
		attr maxExcFreq : FrequencyHz;
		attr maxResponseTime : Time;
	}
	
	requirement RVDT_Spec : RVDT_Requirements {
		measurementRange = 360 [deg];
		maxLinearityError = 0.25 [%];
		minTemp = -55 [degC];
		maxTemp = 125 [degC];
		minExcFreq = 400 [Hz];
		maxExcFreq = 10000 [Hz];
		maxResponseTime = 2 [ms];
	}
	
	// ===== Parts =====
	
	part def PrimaryCoil {
		port in excitationInput : ExcitationPort;
		port out magneticField : SecondaryOutputPort;
		
		attr windingCount : Integer = 500;
		attr wireGauge : Real = 0.2 [mm];
		attr inductance : Real = 50 [mH];
		attr resistance : Real = 15 [Ohm];
		
		action def GenerateField {
			in excitation : ExcitationSignal;
			out fieldStrength : MagneticFluxDensity;
		}
		
		action generateField : GenerateField;
	}
	
	part def MagneticRotor {
		port in shaftInput : ShaftInputPort;
		port out couplingFactor : Real;
		
		attr material : String = "Ferromagnetic_Laminated_Steel";
		attr permeability : Real = 2000;
		attr maxAngle : AngleDeg = 360 [deg];
		attr currentAngle : AngleDeg;
		
		action def Rotate {
			in angle : AngleDeg;
			out coupledFlux : Real;
		}
		
		action rotate : Rotate;
	}
	
	part def SecondaryCoilPair {
		port in magneticInput : SecondaryOutputPort;
		port out voltageOutput : SecondaryOutputPort;
		
		attr coilAWindings : Integer = 450;
		attr coilBWindings : Integer = 450;
		attr coilAVoltage : VoltageAC;
		attr coilBVoltage : VoltageAC;
		
		action def InduceVoltage {
			in fluxA : MagneticFluxDensity;
			in fluxB : MagneticFluxDensity;
			out voltageA : SecondaryVoltage;
			out voltageB : SecondaryVoltage;
		}
		
		action induceVoltage : InduceVoltage;
	}
	
	part def DemodulatorCircuit {
		port in secondaryInput : SecondaryOutputPort;
		port in referenceInput : ExcitationPort;
		port out demodOutput : DemodulatedPort;
		
		attr gain : Real = 1.0;
		attr bandwidth : FrequencyHz = 5000 [Hz];
		attr phaseResolution : PhaseAngle = 0.1 [deg];
		
		action def Demodulate {
			in voltageA : SecondaryVoltage;
			in voltageB : SecondaryVoltage;
			in reference : ExcitationSignal;
			out demodulated : DemodulatedSignal;
			
			// Compute differential amplitude
			assign demodulated.differentialAmplitude = voltageA.amplitude - voltageB.amplitude;
			
			// Determine phase sign relative to reference
			decision phaseDecision {
				if voltageA.phase > reference.phase then {
					assign demodulated.phaseSign = 1;
				} else {
					assign demodulated.phaseSign = -1;
				}
			}
			assign demodulated.valid = true;
		}
		
		action demodulate : Demodulate;
	}
	
	part def AngleCalculator {
		port in demodInput : DemodulatedPort;
		port in tempInput : TemperaturePort;
		port out measurementOutput : MeasurementPort;
		
		attr calibration : CalibrationData;
		attr processingDelay : Time = 0.5 [ms];
		attr resolution : AngleDeg = 0.01 [deg];
		
		action def CalculateAngle {
			in demodulated : DemodulatedSignal;
			in temperature : TemperatureReading;
			out measurement : AngleMeasurement;
			
			attr rawAngle : AngleDeg;
			attr tempCompensatedAngle : AngleDeg;
			attr tempDelta : TemperatureC;
			
			// Apply calibration slope and offset
			assign rawAngle = demodulated.differentialAmplitude * calibration.slope + calibration.offset;
			
			// Apply temperature compensation
			assign tempDelta = temperature.value - calibration.referenceTemp;
			assign tempCompensatedAngle = rawAngle - (rawAngle * calibration.tempCoeff * tempDelta * 1e-6);
			
			assign measurement.angle = tempCompensatedAngle;
			assign measurement.temperatureCompensated = true;
			assign measurement.calibrated = true;
			assign measurement.timestamp = now();
		}
		
		action calculateAngle : CalculateAngle;
	}
	
	part def TemperatureSensor {
		port out tempOutput : TemperaturePort;
		
		attr accuracy : TemperatureC = 0.5 [degC];
		attr range : TemperatureC = 200 [degC];
		
		action def SenseTemperature {
			out temperature : TemperatureReading;
		}
		
		action senseTemperature : SenseTemperature;
	}
	
	part def ExcitationSource {
		port out excitationOutput : ExcitationPort;
		port in powerInput : PowerPort;
		
		attr nominalAmplitude : VoltageAC = 3.0 [V];
		attr nominalFrequency : FrequencyHz = 400 [Hz];
		attr stability : Real = 0.01 [%];
		
		action def GenerateExcitation {
			out excitation : ExcitationSignal;
			assign excitation.amplitude = nominalAmplitude;
			assign excitation.frequency = nominalFrequency;
			assign excitation.phase = 0 [deg];
		}
		
		action generateExcitation : GenerateExcitation;
	}
	
	part def InputShaft {
		port out shaftOutput : ShaftInputPort;
		
		attr currentAngle : AngleDeg;
		attr currentVelocity : AngularVelocity;
		attr maxTorque : Real = 0.05 [N*m];
		
		action def TransmitRotation {
			out angle : AngleDeg;
			out velocity : AngularVelocity;
		}
		
		action transmitRotation : TransmitRotation;
	}
	
	// ===== Main RVDT Assembly =====
	
	part def RVDT {
		port in power : PowerPort;
		port in shaft : ShaftInputPort;
		port out measurement : MeasurementPort;
		
		part excitationSource : ExcitationSource;
		part primaryCoil : PrimaryCoil;
		part rotor : MagneticRotor;
		part secondaryCoils : SecondaryCoilPair;
		part demodulator : DemodulatorCircuit;
		part angleCalculator : AngleCalculator;
		part temperatureSensor : TemperatureSensor;
		part inputShaft : InputShaft;
		
		// Internal connections
		connection excitationToPrimary : excitationSource.excitationOutput to primaryCoil.excitationInput;
		connection primaryToRotor : primaryCoil.magneticField to rotor.shaftInput;
		connection rotorToSecondary : rotor.couplingFactor to secondaryCoils.magneticInput;
		connection secondaryToDemod : secondaryCoils.voltageOutput to demodulator.secondaryInput;
		connection referenceToDemod : excitationSource.excitationOutput to demodulator.referenceInput;
		connection demodToCalc : demodulator.demodOutput to angleCalculator.demodInput;
		connection tempToCalc : temperatureSensor.tempOutput to angleCalculator.tempInput;
		connection shaftToRotor : inputShaft.shaftOutput to rotor.shaftInput;
		connection calcOutput : angleCalculator.measurementOutput to measurement;
		connection powerToSource : power to excitationSource.powerInput;
		connection shaftToInput : shaft to inputShaft.shaftOutput;
		
		// Requirements satisfaction
		satisfy RVDT_Spec;
		
		// ===== State Machine =====
		
		state def RVDT_States {
			entry action;
			exit action;
			
			state Idle {
				doc /* Unpowered state. No excitation is applied. All outputs are inactive. */
				entry action {
					// Power off, no measurements produced
				}
			}
			
			state Energized {
				doc /* Power is applied. Excitation source is active. System is warming up and stabilizing. */
				entry action {
					// Start excitation source
				}
				do action {
					// Monitor supply voltage and frequency stability
				}
			}
			
			state Measuring {
				doc /* Active measurement state. Shaft rotation is being tracked and angle output is valid. */
				entry action {
					// Enable demodulator and angle calculator
				}
				do action {
					// Continuously process secondary voltages and produce angle measurements
				}
				exit action {
					// Latch final measurement
				}
			}
			
			state Fault {
				doc /* Fault condition detected. Outputs are invalidated. */
				entry action {
					// Set all outputs to invalid
				}
			}
			
			transition Idle_to_Energized first Idle to Energized
				if power.supplyVoltage > 0 [V];
			
			transition Energized_to_Measuring Energized to Measuring
				if excitationSource.excitationOutput.excitation.frequency >= 400 [Hz];
			
			transition Measuring_to_Energized Measuring to Energized
				if shaft.shaftVelocity == 0 [deg/s];
			
			transition Energized_to_Idle Energized to Idle
				if power.supplyVoltage == 0 [V];
			
			transition Measuring_to_Fault Measuring to Fault
				if demodulator.demodOutput.demodulated.valid == false;
			
			transition Fault_to_Idle Fault to Idle
				if power.supplyVoltage == 0 [V];
		}
		
		state machine rvdtStateMachine : RVDT_States;
		
		// ===== Main Operational Action =====
		
		action def Operate {
			in shaftAngle : AngleDeg;
			in supplyVoltage : VoltageAC;
			in supplyFrequency : FrequencyHz;
			out angleMeasurement : AngleMeasurement;
			
			// 1. Generate excitation signal
			action generateExcitation : excitationSource.generateExcitation;
			
			// 2. Primary coil generates magnetic field
			action generateField : primaryCoil.generateField;
			
			// 3. Rotor couples magnetic field based on shaft angle
			action rotate : rotor.rotate;
			
			// 4. Secondary coils induce voltages
			action induce : secondaryCoils.induceVoltage;
			
			// 5. Demodulator extracts differential signal
			action demodulate : demodulator.demodulate;
			
			// 6. Angle calculator produces final measurement
			action calculate : angleCalculator.calculateAngle;
			
			// 7. Temperature sensor provides compensation data
			action senseTemp : temperatureSensor.senseTemperature;
			
			// Flow connections
			flow generateExcitation.excitation to generateField.excitation;
			flow generateField.fieldStrength to rotate.angle;
			flow rotate.coupledFlux to induce.fluxA;
			flow induce.voltageA to demodulate.voltageA;
			flow induce.voltageB to demodulate.voltageB;
			flow generateExcitation.excitation to demodulate.reference;
			flow demodulate.demodulated to calculate.demodulated;
			flow senseTemp.temperature to calculate.temperature;
			flow calculate.measurement to angleMeasurement;
		}
		
		action operate : Operate;
	}
	
	// ===== Context / Application =====
	
	part def AerospaceFlightControlSystem {
		part rvdt : RVDT;
		part controlSurface : part def {
			attr surfaceAngle : AngleDeg;
		}
		
		connection surfaceToRVDT : controlSurface to rvdt.shaft;
	}
	
	part def IndustrialRobotJoint {
		part rvdt : RVDT;
		part jointMotor : part def {
			attr jointAngle : AngleDeg;
		}
		
		connection motorToRVDT : jointMotor to rvdt.shaft;
	}
	
	part def PrecisionServoControl {
		part rvdt : RVDT;
		part servoMotor : part def {
			attr position : AngleDeg;
		}
		
		connection servoToRVDT : servoMotor to rvdt.shaft;
	}

}
