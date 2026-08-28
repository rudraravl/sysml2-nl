package SzczecinWaterPumpStation {
	import ScalarValues::*;
	import ISQ::*;

	// ---------- Value Types ----------
	def Volume :> Real {
		value : unit = VolumeUnit::m3;
	}
	def VolumetricFlowRate :> Real {
		value : unit = VolumetricFlowRateUnit::m3_per_s;
	}
	def PressureValue :> Real {
		value : unit = PressureUnit::Pa;
	}
	def RotationalSpeed :> Real {
		value : unit = RotationalSpeedUnit::rpm;
	}
	def LengthValue :> Real {
		value : unit = LengthUnit::m;
	}
	def PowerValue :> Real {
		value : unit = PowerUnit::W;
	}
	def FrequencyValue :> Real {
		value : unit = FrequencyUnit::Hz;
	}
	def PercentValue :> Real {
		value : unit = 1;
	}

	// ---------- Item Types ----------
	item def Water;
	item def ControlSignal;
	item def SensorReading {
		value value : Real;
		value timestamp : Real;
	}
	item def LevelReading :> SensorReading {
		value level : LengthValue;
	}
	item def PressureReading :> SensorReading {
		value pressure : PressureValue;
	}
	item def FlowReading :> SensorReading {
		value flowRate : VolumetricFlowRate;
	}
	item def MotorCommand {
		value targetSpeed : RotationalSpeed;
	}

	// ---------- Port Definitions ----------
	port def WaterPort {
		out item water : Water;
		in item waterIn : Water;
	}
	port def WaterOutPort {
		out item water : Water;
	}
	port def WaterInPort {
		in item water : Water;
	}
	port def LevelSignalPort {
		out item reading : LevelReading;
	}
	port def PressureSignalPort {
		out item reading : PressureReading;
	}
	port def FlowSignalPort {
		out item reading : FlowReading;
	}
	port def MotorCommandPort {
		out item command : MotorCommand;
	}
	port def MotorFeedbackPort {
		out item actualSpeed : RotationalSpeed;
	}
	port def ControlInputPort {
		in item reading : SensorReading;
	}
	port def CommandOutputPort {
		out item command : MotorCommand;
	}

	// ---------- Requirements ----------
	requirement def ReservoirSufficiency {
		doc /* The intake reservoir must maintain sufficient water to prevent pump damage. */
		subject reservoirLevel : LengthValue;
		subject minLevel : LengthValue;
		require constraint { reservoirLevel > minLevel }
	}

	requirement def PressureRegulation {
		doc /* Output pressure must be maintained near target. */
		subject measuredPressure : PressureValue;
		subject targetPressure : PressureValue;
		subject tolerance : PressureValue;
		require constraint { abs(measuredPressure - targetPressure) <= tolerance }
	}

	requirement def FlowDemandSatisfaction {
		doc /* Flow rate must meet city demand. */
		subject suppliedFlow : VolumetricFlowRate;
		subject demandedFlow : VolumetricFlowRate;
		require constraint { suppliedFlow >= demandedFlow }
	}

	requirement def EnergyEfficiency {
		doc /* Motor operates efficiently relative to load. */
		subject motorPower : PowerValue;
		subject hydraulicPower : PowerValue;
		require constraint { motorPower <= 1.25 * hydraulicPower }
	}

	requirement StationRequirements {
		subject station : SzczecinWaterPumpStation;
		satisfy ReservoirSufficiency { reservoirLevel = station.intakeReservoir.currentLevel; minLevel = station.minReservoirLevel; }
		satisfy PressureRegulation { measuredPressure = station.pressureSensor.measuredPressure; targetPressure = station.targetPressure; tolerance = station.pressureTolerance; }
		satisfy FlowDemandSatisfaction { suppliedFlow = station.flowMeter.measuredFlow; demandedFlow = station.demandedFlow; }
		satisfy EnergyEfficiency { motorPower = station.electricMotor.inputPower; hydraulicPower = station.centrifugalPump.hydraulicPower; }
	}

	// ---------- Part Definitions ----------
	part def IntakeReservoir {
		attribute capacity : Volume = 5000 [m3];
		attribute currentVolume : Volume = 4000 [m3];
		attribute currentLevel : LengthValue = 6.0 [m];
		attribute minLevel : LengthValue = 1.5 [m];
		port waterOut : WaterOutPort;
		port levelOut : LevelSignalPort;
		action updateLevel {
			in delta : VolumetricFlowRate;
			out newLevel : LengthValue;
		}
	}

	part def CentrifugalPump {
		attribute ratedFlow : VolumetricFlowRate = 0.5 [m3/s];
		attribute ratedHead : PressureValue = 600000.0 [Pa];
		attribute efficiency : PercentValue = 0.78;
		attribute hydraulicPower : PowerValue;
		port waterIn : WaterInPort;
		port waterOut : WaterOutPort;
		port shaftIn;
		action pumpWater {
			in speed : RotationalSpeed;
			in water : Water;
			out pressurizedWater : Water;
			out flowRate : VolumetricFlowRate;
			out pressure : PressureValue;
		}
	}

	part def ElectricMotor {
		attribute ratedSpeed : RotationalSpeed = 2950.0 [rpm];
		attribute ratedPower : PowerValue = 250000.0 [W];
		attribute inputPower : PowerValue;
		attribute currentSpeed : RotationalSpeed;
		port commandIn : ControlInputPort;
		port shaftOut;
		port feedbackOut : MotorFeedbackPort;
		action regulateSpeed {
			in command : MotorCommand;
			out speed : RotationalSpeed;
			out power : PowerValue;
		}
	}

	part def LevelSensor {
		attribute range : LengthValue = 10.0 [m];
		attribute accuracy : LengthValue = 0.01 [m];
		attribute measuredLevel : LengthValue;
		port levelOut : LevelSignalPort;
		action measure {
			in level : LengthValue;
			out reading : LevelReading;
		}
	}

	part def PressureSensor {
		attribute range : PressureValue = 1000000.0 [Pa];
		attribute accuracy : PressureValue = 5000.0 [Pa];
		attribute measuredPressure : PressureValue;
		port pressureOut : PressureSignalPort;
		action measure {
			in pressure : PressureValue;
			out reading : PressureReading;
		}
	}

	part def FlowMeter {
		attribute range : VolumetricFlowRate = 1.0 [m3/s];
		attribute accuracy : VolumetricFlowRate = 0.005 [m3/s];
		attribute measuredFlow : VolumetricFlowRate;
		port flowOut : FlowSignalPort;
		action measure {
			in flow : VolumetricFlowRate;
			out reading : FlowReading;
		}
	}

	part def DistributionNetwork {
		attribute demandPressure : PressureValue = 500000.0 [Pa];
		attribute demandFlow : VolumetricFlowRate = 0.4 [m3/s];
		port waterIn : WaterInPort;
	}

	part def PumpController {
		attribute targetPressure : PressureValue = 500000.0 [Pa];
		attribute pressureTolerance : PressureValue = 20000.0 [Pa];
		attribute targetFlow : VolumetricFlowRate = 0.4 [m3/s];
		attribute minReservoirLevel : LengthValue = 1.5 [m];
		attribute kp : Real = 0.00001;
		attribute ki : Real = 0.000001;
		attribute integralError : Real = 0.0;
		port levelIn : ControlInputPort;
		port pressureIn : ControlInputPort;
		port flowIn : ControlInputPort;
		port motorFeedback : ControlInputPort;
		port commandOut : CommandOutputPort;
		state def ControllerStateMachine {
			entry; then Idle;
			state Idle;
			transition t_Start when true to Running;
			state Running {
				entry { send commandOut.command.targetSpeed = 0.0 [rpm]; }
				do {
					if (levelIn.reading.value < minReservoirLevel) {
						send commandOut.command.targetSpeed = 0.0 [rpm];
					} else {
						attribute error : Real = targetPressure - pressureIn.reading.value;
						integralError = integralError + error;
						attribute newSpeed : RotationalSpeed = (kp * error + ki * integralError) * 1000.0 [rpm];
						if (newSpeed > 2950.0 [rpm]) {
							send commandOut.command.targetSpeed = 2950.0 [rpm];
						} else if (newSpeed < 0.0 [rpm]) {
							send commandOut.command.targetSpeed = 0.0 [rpm];
						} else {
							send commandOut.command.targetSpeed = newSpeed;
						}
					}
				}
			}
			transition t_LowLevel when levelIn.reading.value < minReservoirLevel to Emergency;
			state Emergency {
				entry { send commandOut.command.targetSpeed = 0.0 [rpm]; }
			}
			transition t_Resume when levelIn.reading.value > (minReservoirLevel + 0.5 [m]) to Running;
		}
		action computeCommand {
			in level : LevelReading;
			in pressure : PressureReading;
			in flow : FlowReading;
			in motorSpeed : RotationalSpeed;
			out command : MotorCommand;
		}
	}

	// ---------- Top-level System ----------
	part SzczecinWaterPumpStation {
		attribute stationName : String = "Szczecin Water Pump Station";
		attribute targetPressure : PressureValue = 500000.0 [Pa];
		attribute pressureTolerance : PressureValue = 20000.0 [Pa];
		attribute demandedFlow : VolumetricFlowRate = 0.4 [m3/s];
		attribute minReservoirLevel : LengthValue = 1.5 [m];

		part intakeReservoir : IntakeReservoir {
			port waterOut : WaterOutPort;
			port levelOut : LevelSignalPort;
		}
		part levelSensor : LevelSensor {
			port levelOut : LevelSignalPort;
		}
		part centrifugalPump : CentrifugalPump {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			port shaftIn;
		}
		part electricMotor : ElectricMotor {
			port commandIn : ControlInputPort;
			port shaftOut;
			port feedbackOut : MotorFeedbackPort;
		}
		part pressureSensor : PressureSensor {
			port pressureOut : PressureSignalPort;
		}
		part flowMeter : FlowMeter {
			port flowOut : FlowSignalPort;
		}
		part distributionNetwork : DistributionNetwork {
			port waterIn : WaterInPort;
		}
		part pumpController : PumpController {
			port levelIn : ControlInputPort;
			port pressureIn : ControlInputPort;
			port flowIn : ControlInputPort;
			port motorFeedback : ControlInputPort;
			port commandOut : CommandOutputPort;
		}

		// Connections - water flow
		connection waterFromReservoirToPump : WaterFlow connect intakeReservoir.waterOut to centrifugalPump.waterIn;
		connection waterFromPumpToNetwork : WaterFlow connect centrifugalPump.waterOut to distributionNetwork.waterIn;

		// Connections - sensor signals
		connection levelSignal connect levelSensor.levelOut to pumpController.levelIn;
		connection pressureSignal connect pressureSensor.pressureOut to pumpController.pressureIn;
		connection flowSignal connect flowMeter.flowOut to pumpController.flowIn;
		connection motorFeedbackSignal connect electricMotor.feedbackOut to pumpController.motorFeedback;

		// Connection - controller to motor
		connection motorCommand connect pumpController.commandOut to electricMotor.commandIn;

		// Connection - mechanical shaft
		connection shaftCoupling connect electricMotor.shaftOut to centrifugalPump.shaftIn;

		// Flow definitions
		flow waterFlow1 of Water from intakeReservoir.waterOut.water to centrifugalPump.waterIn.waterIn;
		flow waterFlow2 of Water from centrifugalPump.waterOut.water to distributionNetwork.waterIn.waterIn;

		// Requirements satisfaction
		satisfy StationRequirements { station = SzczecinWaterPumpStation; }
	}
}
