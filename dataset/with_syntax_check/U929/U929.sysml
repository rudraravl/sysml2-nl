package 'Turn Coordinator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TurnRateValue :> AngularVelocityValue {
		doc /* Rate of turn measured in degrees per second */
	}
	
	attribute def RollAngleValue :> ISQ::AngleValue {
		doc /* Bank angle of the aircraft */
	}
	
	attribute def SlipSkidValue :> AccelerationValue {
		doc /* Lateral acceleration indicating slip or skid condition */
	}
	
	attribute def DisplayDeflectionValue :> ISQ::AngleValue {
		doc /* Visual indicator deflection angle */
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ElectricCurrentValue;
		attribute frequency : FrequencyValue;
	}
	
	port def PowerPort {
		in item power : ElectricalPower;
	}
	
	port def GyroOutputPort {
		out turnRate : TurnRateValue;
		out rollAngle : RollAngleValue;
	}
	
	port def InclinometerOutputPort {
		out lateralAccel : SlipSkidValue;
	}
	
	port def DisplayInputPort {
		in turnIndication : DisplayDeflectionValue;
		in slipIndication : DisplayDeflectionValue;
	}
	
	part def RateGyroscope {
		doc /* Gyroscopic sensor measuring aircraft turn rate and roll angle */
		
		attribute spinAxisOrientation : ISQ::AngleValue;
		attribute precessionRate : AngularVelocityValue;
		
		port powerIn : PowerPort;
		port sensorOutput : GyroOutputPort;
		
		action def MeasureTurnRate {
			in gyroSpinRate : AngularVelocityValue;
			out measuredTurnRate : TurnRateValue;
			out measuredRollAngle : RollAngleValue;
		}
		
		perform action sensing : MeasureTurnRate;
	}
	
	part def Inclinometer {
		doc /* Ball-type inclinometer measuring lateral acceleration for slip/skid indication */
		
		attribute ballMass : MassValue;
		attribute tubeRadius : LengthValue;
		attribute dampingFluid : String;
		
		port sensorOutput : InclinometerOutputPort;
		
		action def MeasureLateralAcceleration {
			in aircraftAcceleration : AccelerationValue;
			out lateralComponent : SlipSkidValue;
		}
		
		perform action measuring : MeasureLateralAcceleration;
	}
	
	part def SignalProcessor {
		doc /* Processes sensor signals and computes display commands */
		
		attribute filterTimeConstant : TimeValue;
		attribute scalingFactor : Real;
		
		port powerIn : PowerPort;
		
		action def ProcessTurnSignal {
			in rawTurnRate : TurnRateValue;
			in rawRollAngle : RollAngleValue;
			out turnDisplayAngle : DisplayDeflectionValue;
		}
		
		action def ProcessSlipSignal {
			in rawLateralAccel : SlipSkidValue;
			out slipDisplayDeflection : DisplayDeflectionValue;
		}
		
		action def FilterAndScale {
			in rawSignal : Real;
			in filterConstant : TimeValue;
			in scaleFactor : Real;
			out processedSignal : Real;
		}
	}
	
	part def InstrumentDisplay {
		doc /* Visual display showing turn rate and slip/skid indication to pilot */
		
		attribute faceIllumination : LuminousIntensityValue;
		attribute needleDeflectionLimit : ISQ::AngleValue;
		
		port powerIn : PowerPort;
		port displayData : ~DisplayInputPort;
		
		action def UpdateTurnNeedle {
			in commandAngle : DisplayDeflectionValue;
		}
		
		action def UpdateSlipBall {
			in commandDeflection : DisplayDeflectionValue;
		}
		
		action def IlluminateDisplay {
			in powerLevel : ISQ::VoltageValue;
		}
	}
	
	part def TurnCoordinator {
		doc /* 
			Flight instrument indicating rate of turn and quality of coordination.
			Provides pilot with visual cues for maintaining coordinated flight during turns.
		*/
		
		attribute nominalVoltage : ISQ::VoltageValue;
		attribute operatingTemperatureRange : TemperatureValue[2];
		attribute standardTurnRate : TurnRateValue;
		
		port externalPower : PowerPort;
		
		part gyro : RateGyroscope;
		part ball : Inclinometer;
		part processor : SignalProcessor;
		part display : InstrumentDisplay;
		
		connection powerToGyro connect externalPower to gyro.powerIn;
		connection powerToProcessor connect externalPower to processor.powerIn;
		connection powerToDisplay connect externalPower to display.powerIn;
		
		connection gyroToProcessor connect gyro.sensorOutput to processor;
		connection ballToProcessor connect ball.sensorOutput to processor;
		connection processorToDisplay connect processor to display.displayData;
		
		perform action coordinateTurn : CoordinateTurn;
		
		exhibit state operationalStates : TurnCoordinatorStateMachine;
	}
	
	attribute def PowerOffSignal;
	attribute def PowerAppliedSignal;
	attribute def PowerRemovedSignal;
	
	action def CoordinateTurn {
		doc /* 
			Primary operational behavior: continuously sense aircraft motion,
			process turn rate and slip/skid data, and display coordination information.
		*/
		
		first start;
		
		then action initialize {
			action powerUpGyro;
			then action calibrateSensors;
			then action setDisplayNeutral;
		}
		
		then merge operationLoop;
		
		then action continuousOperation {
			action senseTurnRate {
				out currentTurnRate : TurnRateValue;
				out currentRollAngle : RollAngleValue;
			}
			
			flow senseTurnRate.currentTurnRate to processTurnData.inputTurnRate;
			flow senseTurnRate.currentRollAngle to processTurnData.inputRollAngle;
			
			action senseSlipSkid {
				out currentLateralAccel : SlipSkidValue;
			}
			
			flow senseSlipSkid.currentLateralAccel to processSlipData.inputAccel;
			
			action processTurnData {
				in inputTurnRate : TurnRateValue;
				in inputRollAngle : RollAngleValue;
				out turnDisplayCommand : DisplayDeflectionValue;
			}
			
			action processSlipData {
				in inputAccel : SlipSkidValue;
				out slipDisplayCommand : DisplayDeflectionValue;
			}
			
			flow processTurnData.turnDisplayCommand to updateDisplay.turnCommand;
			flow processSlipData.slipDisplayCommand to updateDisplay.slipCommand;
			
			action updateDisplay {
				in turnCommand : DisplayDeflectionValue;
				in slipCommand : DisplayDeflectionValue;
			}
		}
		
		then operationLoop;
		
		accept powerOffSignal : PowerOffSignal;
		then done;
	}
	
	state def TurnCoordinatorStateMachine {
		entry; then unpowered;
		
		state unpowered {
			doc /* Instrument is not receiving electrical power */
		}
		
		transition unpowered_to_startup
			first unpowered
			accept powerAppliedSignal : PowerAppliedSignal
			then startup;
		
		state startup {
			doc /* Gyroscope spinning up and sensors calibrating */
			entry; then spinningUp;
			
			state spinningUp {
				attribute gyroAtSpeed : Boolean;
			}
			
			transition spinningUp_to_calibrating
				first spinningUp
				if spinningUp.gyroAtSpeed
				then calibrating;
			
			state calibrating {
				attribute calibrationComplete : Boolean;
			}
			
			transition calibrating_to_ready
				first calibrating
				if calibrating.calibrationComplete
				then ready;
			
			state ready;
		}
		
		transition startup_to_operational
			first startup.ready
			then operational;
		
		state operational {
			doc /* Normal operation: sensing, processing, and displaying */
			entry; then sensing;
			
			attribute faultDetected : Boolean;
			
			state sensing {
				do action measureMotion;
			}
			
			transition sensing_to_computing
				first sensing
				then computing;
			
			state computing {
				do action processSignals;
			}
			
			transition computing_to_displaying
				first computing
				then displaying;
			
			state displaying {
				do action driveIndicators;
			}
			
			transition displaying_to_sensing
				first displaying
				then sensing;
		}
		
		transition operational_to_unpowered
			first operational
			accept powerRemovedSignal : PowerRemovedSignal
			then unpowered;
		
		state failure {
			doc /* Instrument has detected internal fault */
			entry; then flagFailure;
			
			state flagFailure {
				do action displayFailureIndication;
			}
		}
		
		transition operational_to_failure
			first operational
			if operational.faultDetected
			then failure;
	}
	
	part aircraftInstrumentPanel {
		doc /* Context showing turn coordinator installed in aircraft */
		
		part turnCoordinatorInstrument : TurnCoordinator;
		
		part aircraftPowerBus {
			port powerOutput : ~PowerPort;
		}
		
		connection instrumentPower connect 
			aircraftPowerBus.powerOutput to turnCoordinatorInstrument.externalPower;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	requirement def EnvironmentalRequirement;
	
	requirement <'TC-FUNC-001'> primaryFunction : FunctionalRequirement {
		doc /* 
			The turn coordinator shall indicate the rate of turn and the quality 
			of coordination (slip/skid) to enable the pilot to maintain coordinated 
			flight and execute precise turning maneuvers.
		*/
		
		subject instrument : TurnCoordinator;
	}
	
	requirement <'TC-FUNC-002'> turnRateIndication : FunctionalRequirement {
		doc /* 
			The turn coordinator shall display the aircraft's rate of turn 
			proportional to the yaw rate about the vertical axis.
		*/
		
		subject instrument : TurnCoordinator;
		assume primaryFunction;
	}
	
	requirement <'TC-FUNC-003'> slipSkidIndication : FunctionalRequirement {
		doc /* 
			The turn coordinator shall display lateral acceleration to indicate 
			slip or skid conditions during turns.
		*/
		
		subject instrument : TurnCoordinator;
		assume primaryFunction;
	}
	
	requirement <'TC-PERF-001'> turnRateAccuracy : PerformanceRequirement {
		doc /* 
			Turn rate indication shall be accurate to within ±2 degrees per second 
			across the operational range.
		*/
		
		subject gyro : RateGyroscope;
		
		require constraint accuracyLimit {
			doc /* Measurement error <= 2 deg/s */
		}
	}
	
	requirement <'TC-PERF-002'> responseTime : PerformanceRequirement {
		doc /* 
			The instrument shall respond to turn rate changes with a time constant 
			not exceeding 0.5 seconds.
		*/
		
		subject processor : SignalProcessor;
		
		require constraint timeConstantLimit {
			processor.filterTimeConstant <= 0.5 [SI::s]
		}
	}
	
	requirement <'TC-PERF-003'> startupTime : PerformanceRequirement {
		doc /* 
			The turn coordinator shall reach operational status within 
			60 seconds of power application.
		*/
		
		subject instrument : TurnCoordinator;
	}
	
	requirement <'TC-SAFE-001'> failureIndication : SafetyRequirement {
		doc /* 
			The instrument shall provide clear and unambiguous indication 
			of internal failure or unreliable data.
		*/
		
		subject display : InstrumentDisplay;
	}
	
	requirement <'TC-SAFE-002'> powerFailure : SafetyRequirement {
		doc /* 
			Loss of electrical power shall result in the instrument display 
			returning to a neutral, non-misleading position.
		*/
		
		subject instrument : TurnCoordinator;
	}
	
	requirement <'TC-ENV-001'> temperatureRange : EnvironmentalRequirement {
		doc /* 
			The turn coordinator shall operate correctly across the temperature 
			range of -40°C to +70°C.
		*/
		
		subject instrument : TurnCoordinator;
	}
	
	requirement <'TC-ENV-002'> vibrationTolerance : EnvironmentalRequirement {
		doc /* 
			The instrument shall withstand aircraft vibration levels per 
			DO-160 Section 8 Category S standards.
		*/
		
		subject instrument : TurnCoordinator;
	}
	
	requirement <'TC-ENV-003'> powerSupply : EnvironmentalRequirement {
		doc /* 
			The turn coordinator shall operate on standard aircraft electrical 
			power: 14V DC or 28V DC ±10%, or 115V AC 400Hz.
		*/
		
		subject instrument : TurnCoordinator;
		
		require constraint voltageRange {
			doc /* Nominal voltage with tolerance */
		}
	}
}
