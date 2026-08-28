package 'ThinFilmDepositionControlSystem' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def ThicknessValue :> ScalarValues::Real {
		doc /* Thickness in nanometers (nm) */
	}
	attribute def FrequencyValue :> ScalarValues::Real {
		doc /* Frequency in hertz (Hz) */
	}
	attribute def RateValue :> ScalarValues::Real {
		doc /* Deposition rate in nanometers per second (nm/s) */
	}
	attribute def DensityValue :> ScalarValues::Real {
		doc /* Density in kilograms per cubic meter */
	}
	attribute def AcousticImpedanceValue :> ScalarValues::Real {
		doc /* Acoustic impedance in kg/(m^2*s) */
	}

	item def MaterialProperties {
		attribute density : DensityValue;
		attribute acousticImpedance : AcousticImpedanceValue;
	}

	item def TargetSettings {
		attribute targetThickness : ThicknessValue;
		attribute tolerance : ThicknessValue;
	}

	item def FrequencyMeasurement {
		attribute frequency : FrequencyValue;
	}

	item def ThicknessMeasurement {
		attribute thickness : ThicknessValue;
		attribute depositionRate : RateValue;
	}

	item def ShutterCommand {
		attribute command : String;
	}

	part def Operator {
		port targetPort {
			out targetOut : TargetSettings;
		}
		port materialPort {
			out materialOut : MaterialProperties;
		}
	}

	part def QuartzCrystalSensor {
		port freqPort {
			out freqOut : FrequencyMeasurement;
		}
		event occurrence frequencyMeasured;
	}

	part def FrequencyCounter {
		port freqInPort {
			in freqIn : FrequencyMeasurement;
		}
		port freqOutPort {
			out freqOut : FrequencyMeasurement;
		}
		event occurrence frequencyReceived;
		then event occurrence frequencyProcessed;
	}

	part def ThicknessCalculator {
		port freqInPort {
			in freqIn : FrequencyMeasurement;
		}
		port materialPort {
			in materialIn : MaterialProperties;
		}
		port thicknessOutPort {
			out thicknessOut : ThicknessMeasurement;
		}
		event occurrence dataReceived;
		then event occurrence calculationComplete;
	}

	part def ProcessController {
		attribute target : ThicknessValue;
		attribute tolerance : ThicknessValue;

		port settingsInPort {
			in settingsIn : TargetSettings;
		}
		port thicknessInPort {
			in thicknessIn : ThicknessMeasurement;
		}
		port shutterCmdPort {
			out shutterCmd : ShutterCommand;
		}
		port displayDataPort {
			out displayData : ThicknessMeasurement;
		}

		event occurrence settingsReceived;
		then event occurrence thicknessReceived;
		then event occurrence comparisonComplete;
		then event occurrence commandSent;
		then event occurrence displayUpdated;

		action controllerBehavior {
			action receiveSettings;
			then action receiveThickness;
			then action compareThickness;
			then action sendShutterCommand send new ShutterCommand() to shutterCmdPort;
			then action sendDisplayData send new ThicknessMeasurement() to displayDataPort;
		}
	}

	part def Shutter {
		port cmdInPort {
			in cmdIn : ShutterCommand;
		}
		event occurrence commandReceived;
		then event occurrence shutterClosed;
	}

	part def DisplayUnit {
		port dataInPort {
			in dataIn : ThicknessMeasurement;
		}
		event occurrence dataReceived;
		then event occurrence displayRefreshed;
	}

	part def DepositionSystem {
		part operator : Operator;
		part sensor : QuartzCrystalSensor;
		part counter : FrequencyCounter;
		part calculator : ThicknessCalculator;
		part controller : ProcessController;
		part shutter : Shutter;
		part display : DisplayUnit;

		flow operatorToControllerFlow of TargetSettings
			from operator.targetPort.targetOut to controller.settingsInPort.settingsIn;
		flow operatorToCalcFlow of MaterialProperties
			from operator.materialPort.materialOut to calculator.materialPort.materialIn;
		flow sensorToCounterFlow of FrequencyMeasurement
			from sensor.freqPort.freqOut to counter.freqInPort.freqIn;
		flow counterToCalcFlow of FrequencyMeasurement
			from counter.freqOutPort.freqOut to calculator.freqInPort.freqIn;
		flow calcToControllerFlow of ThicknessMeasurement
			from calculator.thicknessOutPort.thicknessOut to controller.thicknessInPort.thicknessIn;
		flow controllerToShutterFlow of ShutterCommand
			from controller.shutterCmdPort.shutterCmd to shutter.cmdInPort.cmdIn;
		flow controllerToDisplayFlow of ThicknessMeasurement
			from controller.displayDataPort.displayData to display.dataInPort.dataIn;
	}

	occurrence def DepositionControlInteraction {
		ref part system : DepositionSystem;

		message freqMsg of FrequencyMeasurement
			from system.sensor.frequencyMeasured to system.counter.frequencyReceived;
		then message processedFreqMsg of FrequencyMeasurement
			from system.counter.frequencyProcessed to system.calculator.dataReceived;
		then message thicknessMsg of ThicknessMeasurement
			from system.calculator.calculationComplete to system.controller.thicknessReceived;
		then message shutterMsg of ShutterCommand
			from system.controller.commandSent to system.shutter.commandReceived;
		then message displayMsg of ThicknessMeasurement
			from system.controller.displayUpdated to system.display.dataReceived;
	}

	requirement HighAccuracyRequirement {
		doc /* The system shall control film thickness with nanometer-level precision. */
		attribute accuracyTolerance : ThicknessValue;
	}

	requirement AutomaticStopRequirement {
		doc /* The system shall automatically stop deposition when target thickness is reached within tolerance. */
		attribute targetThickness : ThicknessValue;
		attribute tolerance : ThicknessValue;
	}

	part depositionSystem : DepositionSystem {
		satisfy HighAccuracyRequirement;
		satisfy AutomaticStopRequirement;
	}
}
