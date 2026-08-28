package 'Automated Insulin Delivery System' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def GlucoseConcentration :> ScalarValues::Real;
	attribute def GlucoseRate :> ScalarValues::Real;
	attribute def InsulinDoseValue :> ScalarValues::Real;

	enum def TrendKind {
		stable;
		rising;
		falling;
	}
	enum def CommandType {
		mealAnnouncement;
		bolusRequest;
	}
	enum def AlertType {
		hypoglycemiaWarning;
		overdoseWarning;
		systemFault;
	}
	enum def SystemMode {
		startup;
		normal;
		alarm;
		stopped;
	}

	item def GlucoseReading {
		attribute level : GlucoseConcentration;
		attribute trend : TrendKind;
		attribute rateOfChange : GlucoseRate;
	}
	item def InsulinDose {
		attribute units : InsulinDoseValue;
	}
	item def UserCommand {
		attribute commandType : CommandType;
		attribute parameter : ScalarValues::Real;
	}
	item def Alert {
		attribute alertType : AlertType;
		attribute alertText : String;
	}
	item def DisplayData {
		attribute glucose : GlucoseReading;
		attribute lastDose : InsulinDose;
		attribute systemMode : SystemMode;
	}
	item def PumpStatus {
		attribute reservoirLevel : ScalarValues::Real;
		attribute delivering : Boolean;
	}
	item def EncryptedData {
		attribute payload : String;
	}
	item def TherapyRecord {
		attribute glucose : GlucoseReading;
		attribute dose : InsulinDose;
		attribute timestamp : String;
	}

	action def SenseGlucose {
		out glucose : GlucoseReading;
	}
	action def CalculateDose {
		in glucose : GlucoseReading;
		in userCmd : UserCommand[0..*];
		out dose : InsulinDose;
	}
	action def ValidateDose {
		in proposedDose : InsulinDose;
		in glucose : GlucoseReading;
		out safeDose : InsulinDose;
		out alert : Alert;
	}
	action def DeliverInsulin {
		in dose : InsulinDose;
		out status : PumpStatus;
	}
	action def AggregateDisplay {
		in glucose : GlucoseReading;
		in dose : InsulinDose;
		in mode : SystemMode;
		out displayData : DisplayData;
	}
	action def EncryptData {
		in record : TherapyRecord;
		out encryptedData : EncryptedData;
	}

	attribute def 'SelfTestComplete';
	attribute def 'AlarmCondition';
	attribute def 'AlarmCleared';
	attribute def 'StopCommand';
	attribute def 'OverdoseDetected';
	attribute def 'LowGlucoseDetected';
	attribute def 'ConditionsResolved';

	state def SafetyStateMachine {
		entry; then Normal;
		state Normal;
		accept 'OverdoseDetected' then Warning;
		accept 'LowGlucoseDetected' then Warning;
		state Warning;
		accept 'ConditionsResolved' then Normal;
	}

	state def SystemStateMachine {
		entry; then Startup;
		state Startup;
		accept 'SelfTestComplete' then NormalOperation;
		state NormalOperation;
		accept 'AlarmCondition' then Alarm;
		state Alarm;
		accept 'AlarmCleared' then NormalOperation;
		accept 'StopCommand' then Stopped;
		state Stopped;
	}

	action def ClosedLoopControl {
		in userCmd : UserCommand[0..*];
		action sense : SenseGlucose {
			out glucose;
		}
		then action calc : CalculateDose {
			in glucose = sense.glucose;
			in userCmd = userCmd;
			out dose;
		}
		then action validate : ValidateDose {
			in proposedDose = calc.dose;
			in glucose = sense.glucose;
			out safeDose;
			out alert;
		}
		then action deliver : DeliverInsulin {
			in dose = validate.safeDose;
			out status;
		}
	}

	part def ContinuousGlucoseSensor {
		port glucoseOut {
			out glucoseReading : GlucoseReading;
		}
	}
	part def ControlAlgorithmProcessor {
		port glucoseIn {
			in glucoseReading : GlucoseReading;
		}
		port userCmdIn {
			in userCmd : UserCommand;
		}
		port doseOut {
			out insulinDose : InsulinDose;
		}
		port modeOut {
			out systemMode : SystemMode;
		}
	}
	part def SafetyMonitor {
		attribute maxDose : InsulinDoseValue = 10.0;
		attribute lowGlucose : GlucoseConcentration = 70.0;
		port doseIn {
			in proposedDose : InsulinDose;
		}
		port glucoseIn {
			in glucoseReading : GlucoseReading;
		}
		port safeDoseOut {
			out safeDose : InsulinDose;
		}
		port alertOut {
			out alert : Alert;
		}
		exhibit safetyState : SafetyStateMachine;
	}
	part def InsulinPump {
		port doseIn {
			in dose : InsulinDose;
		}
		port statusOut {
			out pumpStatus : PumpStatus;
		}
	}
	part def UserInterface {
		port displayIn {
			in displayData : DisplayData;
		}
		port cmdOut {
			out userCmd : UserCommand;
		}
		port alertIn {
			in alert : Alert;
		}
	}
	part def DataLogger {
		port recordIn {
			in therapyRecord : TherapyRecord;
		}
		port dataOut {
			out encryptedData : EncryptedData;
		}
	}
	part def WirelessCommunication {
		port dataIn {
			in encryptedData : EncryptedData;
		}
		port bleOut {
			out packet : EncryptedData;
		}
	}
	part def DisplayAggregator {
		port glucoseIn {
			in glucose : GlucoseReading;
		}
		port doseIn {
			in dose : InsulinDose;
		}
		port alertIn {
			in alert : Alert;
		}
		port modeIn {
			in mode : SystemMode;
		}
		port displayOut {
			out displayData : DisplayData;
		}
	}

	requirement def FDA_Breakthrough_Device {
		text = "The system must qualify for FDA Breakthrough Device designation, offering more effective treatment for diabetes.";
	}
	requirement def Hypoglycemia_Prevention {
		text = "The system shall prevent insulin delivery when glucose is below a safe threshold to avoid hypoglycemia.";
	}
	requirement def Overdose_Prevention {
		text = "The system shall limit the maximum insulin dose to prevent overdose.";
	}
	requirement def Data_Security {
		text = "All logged therapy data shall be encrypted before wireless transmission.";
	}

	part aidSystem {
		attribute effectiveness : ScalarValues::Real = 0.95;
		attribute hypoglycemiaEvents : Integer = 0;

		part sensor : ContinuousGlucoseSensor;
		part processor : ControlAlgorithmProcessor;
		part safetyMonitor : SafetyMonitor;
		part pump : InsulinPump;
		part ui : UserInterface;
		part logger : DataLogger;
		part wireless : WirelessCommunication;
		part displayAggregator : DisplayAggregator;

		flow glucoseToProcessor of GlucoseReading
			from sensor.glucoseOut.glucoseReading to processor.glucoseIn.glucoseReading;
		flow glucoseToSafety of GlucoseReading
			from sensor.glucoseOut.glucoseReading to safetyMonitor.glucoseIn.glucoseReading;
		flow doseToSafety of InsulinDose
			from processor.doseOut.insulinDose to safetyMonitor.doseIn.proposedDose;
		flow safeDoseToPump of InsulinDose
			from safetyMonitor.safeDoseOut.safeDose to pump.doseIn.dose;
		flow alertToUi of Alert
			from safetyMonitor.alertOut.alert to ui.alertIn.alert;
		flow userCmdToProcessor of UserCommand
			from ui.cmdOut.userCmd to processor.userCmdIn.userCmd;

		flow glucoseToAgg of GlucoseReading
			from sensor.glucoseOut.glucoseReading to displayAggregator.glucoseIn.glucose;
		flow doseToAgg of InsulinDose
			from safetyMonitor.safeDoseOut.safeDose to displayAggregator.doseIn.dose;
		flow alertToAgg of Alert
			from safetyMonitor.alertOut.alert to displayAggregator.alertIn.alert;
		flow modeToAgg of SystemMode
			from processor.modeOut.systemMode to displayAggregator.modeIn.mode;
		flow displayToUi of DisplayData
			from displayAggregator.displayOut.displayData to ui.displayIn.displayData;

		flow dataToWireless of EncryptedData
			from logger.dataOut.encryptedData to wireless.dataIn.encryptedData;

		exhibit state systemState : SystemStateMachine;
		perform closedLoop : ClosedLoopControl;
	}

	requirement 'FDA Qualification' : FDA_Breakthrough_Device {
		subject aid : aidSystem;
	}
	requirement 'Hypo Prevention Req' : Hypoglycemia_Prevention {
		subject sm : aidSystem.safetyMonitor;
	}
	requirement 'Overdose Prevention Req' : Overdose_Prevention {
		subject sm : aidSystem.safetyMonitor;
	}
	requirement 'Data Security Req' : Data_Security {
		subject log : aidSystem.logger;
	}
}
