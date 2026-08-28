package ArtificialPancreas {

	import ScalarValues::*;
	import ISQ::*;

	value def GlucoseConcentration = Real { unit "mg/dL"; }
	value def InsulinAmount = Real { unit "U"; }
	value def InsulinFlowRate = Real { unit "U/min"; }
	value def BodyMass = Real { unit "kg"; }
	value def CarbohydrateMass = Real { unit "g"; }
	value def TimeMinutes = Real { unit "min"; }
	value def VolumeMilli = Real { unit "mL"; }

	item def GlucoseReading {
		value concentration : GlucoseConcentration;
		value timestamp : Time;
		attr sensorId : String;
		attr confidence : Real;
	}

	item def PredictedGlucose {
		value concentration : GlucoseConcentration;
		value horizon : TimeMinutes;
		value timestamp : Time;
	}

	item def InsulinCommand {
		value dose : InsulinAmount;
		value flowRate : InsulinFlowRate;
		attr commandId : String;
		attr priority : Integer;
	}

	item def MealEntry {
		value carbohydrates : CarbohydrateMass;
		value timestamp : Time;
		attr mealType : String;
	}

	item def BolusRequest {
		value amount : InsulinAmount;
		attr requestedBy : String;
	}

	item def AlarmEvent {
		attr alarmType : String;
		value severity : Integer;
		value timestamp : Time;
	}

	item def ModeCommand {
		attr mode : String;
		value timestamp : Time;
	}

	port def GlucoseOutPort {
		out reading : GlucoseReading;
	}

	port def GlucoseInPort {
		in reading : GlucoseReading;
	}

	port def PredictionOutPort {
		out prediction : PredictedGlucose;
	}

	port def CommandOutPort {
		out command : InsulinCommand;
	}

	port def CommandInPort {
		in command : InsulinCommand;
	}

	port def UserInputInPort {
		in meal : MealEntry;
		in bolus : BolusRequest;
		in modeCmd : ModeCommand;
		in ackAlarm : Boolean;
	}

	port def DisplayOutPort {
		out glucose : GlucoseReading;
		out activeInsulin : InsulinAmount;
		out trend : String;
		out alarm : AlarmEvent;
		out mode : String;
	}

	port def ReservoirStatusPort {
		out level : InsulinAmount;
		out occlusion : Boolean;
	}

	part def ContinuousGlucoseMonitor {
		port glucoseOut : GlucoseOutPort;
		port statusOut : ReservoirStatusPort;

		value sampleInterval : TimeMinutes = 5 [min];
		value measurementAccuracy : GlucoseConcentration = 20 [mg/dL];
		value currentReading : GlucoseConcentration;
		attr sensorId : String = "CGM-001";
		attr sensorFault : Boolean = false;

		part sensor {
			value rawGlucose : GlucoseConcentration;
			action measure : Action {
				in bodyFluid;
				out reading : GlucoseReading;
			}
			action calibrate : Action {
				in reference : GlucoseConcentration;
				out adjusted : GlucoseConcentration;
			}
		}

		part transmitter {
			attr protocol : String = "BLE";
			action transmit : Action {
				in reading : GlucoseReading;
				out sent : GlucoseReading;
			}
		}

		state cgmStateMachine {
			entry; then initializing;
			state initializing;
			transition initializing -> measuring
				when sensor.rawGlucose > 0 [mg/dL];
			state measuring {
				entry action { sensor.measure(); }
			}
			transition measuring -> transmitting
				done after 5 [min];
			state transmitting {
				entry action { transmitter.transmit(); }
			}
			transition transmitting -> measuring
				done when !sensorFault;
			transition measuring -> faulted
				when sensorFault;
			transition transmitting -> faulted
				when sensorFault;
			state faulted;
			transition faulted -> initializing
				when !sensorFault;
		}
	}

	part def InsulinPump {
		port commandIn : CommandInPort;
		port statusOut : ReservoirStatusPort;

		value reservoirCapacity : InsulinAmount = 300 [U];
		value reservoirLevel : InsulinAmount = 200 [U];
		value maxFlowRate : InsulinFlowRate = 5 [U/min];
		value deliveredThisCycle : InsulinAmount = 0 [U];
		attr occlusionDetected : Boolean = false;
		attr motorFault : Boolean = false;

		part reservoir {
			value capacity : InsulinAmount = 300 [U];
			value currentAmount : InsulinAmount;
			item insulin;
		}

		part motor {
			value speed : Real;
			action push : Action {
				in amount : InsulinAmount;
				in rate : InsulinFlowRate;
				out delivered : InsulinAmount;
			}
			action stop : Action {
				out stopped : Boolean;
			}
		}

		part infusionSet {
			attr tubeId : String;
			attr cannulaInserted : Boolean = true;
			item flowingInsulin;
		}

		state pumpStateMachine {
			entry; then idle;
			state idle;
			transition idle -> priming
				when commandIn.command.dose > 0 [U];
			state priming;
			transition priming -> delivering
				done when infusionSet.cannulaInserted;
			state delivering {
				entry action { motor.push(commandIn.command.dose, commandIn.command.flowRate); }
			}
			transition delivering -> idle
				done when deliveredThisCycle >= commandIn.command.dose;
			transition delivering -> occluded
				when occlusionDetected;
			transition idle -> occluded
				when occlusionDetected;
			state occluded;
			transition occluded -> idle
				when !occlusionDetected;
			transition any to faulted
				when motorFault;
			state faulted;
		}
	}

	part def ControlAlgorithm {
		port glucoseIn : GlucoseInPort;
		port commandOut : CommandOutPort;
		port userInput : UserInputInPort;
		port predictionOut : PredictionOutPort;

		value targetLow : GlucoseConcentration = 70 [mg/dL];
		value targetHigh : GlucoseConcentration = 180 [mg/dL];
		value criticalLow : GlucoseConcentration = 54 [mg/dL];
		value criticalHigh : GlucoseConcentration = 250 [mg/dL];
		value maxActiveInsulin : InsulinAmount = 10 [U];
		value activeInsulin : InsulinAmount = 0 [U];
		value patientWeight : BodyMass = 70 [kg];
		value insulinSensitivityFactor : Real = 50; // mg/dL per U
		value carbRatio : Real = 10; // g per U
		value predictionHorizon : TimeMinutes = 30 [min];
		value lastGlucose : GlucoseConcentration;
		value predictedGlucose : GlucoseConcentration;
		attr algorithmVersion : String = "v2.3";

		action predictGlucose : Action {
			in current : GlucoseReading;
			in active : InsulinAmount;
			in meal : MealEntry;
			out prediction : PredictedGlucose;
		}

		action calculateBasalDose : Action {
			in predicted : GlucoseConcentration;
			in target : GlucoseConcentration;
			out basal : InsulinAmount;
		}

		action calculateBolusDose : Action {
			in meal : MealEntry;
			in current : GlucoseConcentration;
			out bolus : InsulinAmount;
		}

		action checkSafetyConstraints : Action {
			in proposedDose : InsulinAmount;
			in active : InsulinAmount;
			out safeDose : InsulinAmount;
			out suspendDelivery : Boolean;
		}

		action updateActiveInsulin : Action {
			in delivered : InsulinAmount;
			in elapsed : TimeMinutes;
			out updatedActive : InsulinAmount;
		}

		state algorithmStateMachine {
			entry; then receiving;
			state receiving {
				entry action { lastGlucose = glucoseIn.reading.concentration; }
			}
			transition receiving -> predicting
				done when glucoseIn.reading != null;
			state predicting {
				entry action { predictGlucose(glucoseIn.reading, activeInsulin, userInput.meal); }
			}
			transition predicting -> dosing
				done when predictedGlucose != null;
			state dosing {
				entry action {
					calculateBasalDose(predictedGlucose, targetHigh);
					calculateBolusDose(userInput.meal, lastGlucose);
				}
			}
			transition dosing -> safetyCheck
				done when true;
			state safetyCheck {
				entry action { checkSafetyConstraints(commandOut.command.dose, activeInsulin); }
			}
			transition safetyCheck -> receiving
				done when true;
		}
	}

	part def UserInterface {
		port display : DisplayOutPort;
		port userInput : UserInputInPort;

		attr deviceType : String = "smartphone";
		attr language : String = "en";
		value displayRefreshInterval : TimeMinutes = 1 [min];

		action displayGlucose : Action {
			in reading : GlucoseReading;
		}

		action displayTrend : Action {
			in current : GlucoseConcentration;
			in previous : GlucoseConcentration;
			out trend : String;
		}

		action displayActiveInsulin : Action {
			in amount : InsulinAmount;
		}

		action displayAlarm : Action {
			in alarm : AlarmEvent;
		}

		action receiveMealEntry : Action {
			out meal : MealEntry;
		}

		action receiveBolusRequest : Action {
			out bolus : BolusRequest;
		}

		action receiveModeChange : Action {
			out modeCmd : ModeCommand;
		}

		state uiStateMachine {
			entry; then mainScreen;
			state mainScreen;
			transition mainScreen -> mealEntryScreen
				when userInput.meal != null;
			state mealEntryScreen;
			transition mealEntryScreen -> mainScreen
				done when true;
			transition mainScreen -> bolusScreen
				when userInput.bolus != null;
			state bolusScreen;
			transition bolusScreen -> mainScreen
				done when true;
			transition mainScreen -> alarmScreen
				when display.alarm.severity > 0;
			state alarmScreen;
			transition alarmScreen -> mainScreen
				when userInput.ackAlarm == true;
		}
	}

	part def ArtificialPancreasSystem {
		port userPort : UserInputInPort;
		port displayPort : DisplayOutPort;

		part cgm : ContinuousGlucoseMonitor;
		part pump : InsulinPump;
		part controller : ControlAlgorithm;
		part ui : UserInterface;

		connection cgm.glucoseOut to controller.glucoseIn;
		connection controller.commandOut to pump.commandIn;
		connection controller.predictionOut to ui.display;
		connection pump.statusOut to controller.userInput;
		connection ui.userInput to controller.userInput;
		connection ui.userInput to userPort;
		connection ui.display to displayPort;

		value systemTargetLow : GlucoseConcentration = 70 [mg/dL];
		value systemTargetHigh : GlucoseConcentration = 180 [mg/dL];
		value suspendThreshold : GlucoseConcentration = 70 [mg/dL];
		value resumeThreshold : GlucoseConcentration = 90 [mg/dL];
		attr currentMode : String = "off";

		state systemModeStateMachine {
			entry; then off;
			state off {
				entry action { currentMode = "off"; }
			}
			transition off -> manual
				when userPort.modeCmd.mode == "manual";
			transition off -> closedLoop
				when userPort.modeCmd.mode == "closedLoop";

			state manual {
				entry action { currentMode = "manual"; }
			}
			transition manual -> closedLoop
				when userPort.modeCmd.mode == "closedLoop";
			transition manual -> off
				when userPort.modeCmd.mode == "off";
			transition manual -> suspend
				when controller.glucoseIn.reading.concentration < suspendThreshold;

			state closedLoop {
				entry action { currentMode = "closedLoop"; }
			}
			transition closedLoop -> manual
				when userPort.modeCmd.mode == "manual";
			transition closedLoop -> off
				when userPort.modeCmd.mode == "off";
			transition closedLoop -> suspend
				when controller.glucoseIn.reading.concentration < suspendThreshold
					or controller.predictionOut.prediction.concentration < suspendThreshold;

			state suspend {
				entry action { currentMode = "suspend"; }
			}
			transition suspend -> closedLoop
				when controller.glucoseIn.reading.concentration > resumeThreshold
					and controller.predictionOut.prediction.concentration > resumeThreshold;
			transition suspend -> alarm
				when controller.glucoseIn.reading.concentration < 54 [mg/dL];

			state alarm {
				entry action { currentMode = "alarm"; }
			}
			transition alarm -> closedLoop
				when userPort.ackAlarm == true
					and controller.glucoseIn.reading.concentration > resumeThreshold;
			transition alarm -> manual
				when userPort.ackAlarm == true
					and controller.glucoseIn.reading.concentration <= resumeThreshold;
		}
	}

	requirement def GlucoseMonitoringRequirement {
		subject cgm : ContinuousGlucoseMonitor;
		requirement : The CGM shall measure interstitial glucose concentration every 5 minutes.
		requirement : The CGM measurement accuracy shall be within ±20 mg/dL of reference.
		requirement : The CGM shall transmit each reading to the control algorithm within 30 seconds.
	}

	requirement def InsulinDeliveryRequirement {
		subject pump : InsulinPump;
		requirement : The pump shall deliver rapid-acting insulin from a reservoir of at least 200 U.
		requirement : The pump delivery precision shall be ±0.05 U per command.
		requirement : The pump shall not exceed a maximum flow rate of 5 U/min.
		requirement : The pump shall detect occlusion and report it within 2 minutes.
	}

	requirement def ClosedLoopControlRequirement {
		subject controller : ControlAlgorithm;
		requirement : The controller shall maintain blood glucose between 70 mg/dL and 180 mg/dL.
		requirement : The controller shall predict glucose concentration 30 minutes ahead.
		requirement : The controller shall compute insulin dose using patient weight, insulin sensitivity, and carb ratio.
		requirement : The controller shall not permit active insulin to exceed 10 U.
		requirement : The controller shall incorporate meal entries and manual bolus requests into dose calculation.
	}

	requirement def SafetyRequirement {
		subject system : ArtificialPancreasSystem;
		requirement : The system shall enter suspend mode when glucose is below 70 mg/dL or predicted to fall below 70 mg/dL within 30 minutes.
		requirement : The system shall resume closed-loop operation only when glucose exceeds 90 mg/dL and is predicted to remain above 90 mg/dL.
		requirement : The system shall enter alarm mode on severe hypoglycemia (<54 mg/dL), severe hyperglycemia (>250 mg/dL), sensor failure, or pump occlusion.
		requirement : The system shall halt all insulin delivery in suspend and alarm modes.
	}

	requirement def UserInterfaceRequirement {
		subject ui : UserInterface;
		requirement : The UI shall display current glucose, trend, active insulin, and current mode.
		requirement : The UI shall refresh displayed values at least every 1 minute.
		requirement : The UI shall accept meal entries with carbohydrate amount and timestamp.
		requirement : The UI shall accept manual bolus requests.
		requirement : The UI shall allow mode changes between off, manual, and closedLoop.
		requirement : The UI shall present alarms with type and severity and require acknowledgment.
	}

	requirement def SystemIntegrationRequirement {
		subject system : ArtificialPancreasSystem;
		requirement : The CGM, Control Algorithm, Insulin Pump, and User Interface shall exchange data through defined ports.
		requirement : The system shall support off, manual, closedLoop, suspend, and alarm operating modes.
	}

	satisfy GlucoseMonitoringRequirement by cgm;
	satisfy InsulinDeliveryRequirement by pump;
	satisfy ClosedLoopControlRequirement by controller;
	satisfy SafetyRequirement by ArtificialPancreasSystem::systemModeStateMachine;
	satisfy UserInterfaceRequirement by ui;
	satisfy SystemIntegrationRequirement by ArtificialPancreasSystem;

}
