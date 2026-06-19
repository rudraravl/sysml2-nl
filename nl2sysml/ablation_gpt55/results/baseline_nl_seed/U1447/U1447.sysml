package MarineChronometerSpecification {
	import ScalarValues::*;

	attribute def TimeSecond :> Real {
		attribute unitSymbol : String = "s";
	}

	attribute def TimeSecondPerDay :> Real {
		attribute unitSymbol : String = "s/day";
	}

	attribute def FrequencyHertz :> Real {
		attribute unitSymbol : String = "Hz";
	}

	attribute def TorqueNewtonMeter :> Real {
		attribute unitSymbol : String = "N*m";
	}

	attribute def EnergyJoule :> Real {
		attribute unitSymbol : String = "J";
	}

	attribute def AngleDegree :> Real {
		attribute unitSymbol : String = "deg";
	}

	attribute def TemperatureCelsius :> Real {
		attribute unitSymbol : String = "degC";
	}

	attribute def DurationHour :> Real {
		attribute unitSymbol : String = "h";
	}

	attribute def Percentage :> Real {
		attribute unitSymbol : String = "%";
	}

	item def TorqueFlow {
		attribute torque : TorqueNewtonMeter;
	}

	item def StoredEnergy {
		attribute energy : EnergyJoule;
		attribute reserveRemaining : DurationHour;
	}

	item def BalanceImpulse {
		attribute impulseAngle : AngleDegree;
		attribute impulseEnergy : EnergyJoule;
	}

	item def OscillationRate {
		attribute frequency : FrequencyHertz;
		attribute rateError : TimeSecondPerDay;
	}

	item def TickPulse {
		attribute period : TimeSecond;
		attribute sequenceNumber : Integer;
	}

	item def HandPosition {
		attribute hourHandAngle : AngleDegree;
		attribute minuteHandAngle : AngleDegree;
		attribute secondHandAngle : AngleDegree;
	}

	item def TimeReading {
		attribute hour : Integer;
		attribute minute : Integer;
		attribute second : TimeSecond;
		attribute timeScale : String = "GMT";
		attribute uncertainty : TimeSecond;
	}

	item def WindingRotation {
		attribute turns : Real;
		attribute appliedTorque : TorqueNewtonMeter;
	}

	item def TimeSettingCommand {
		attribute targetHour : Integer;
		attribute targetMinute : Integer;
		attribute targetSecond : TimeSecond;
		attribute timeScale : String = "GMT";
	}

	item def RateAdjustmentCommand {
		attribute regulatorChange : AngleDegree;
		attribute desiredDailyRateError : TimeSecondPerDay;
	}

	item def AmbientCondition {
		attribute temperature : TemperatureCelsius;
		attribute humidity : Percentage;
		attribute shipMotionLevel : Real;
	}

	port def TorqueInPort {
		in item torqueIn : TorqueFlow;
	}

	port def TorqueOutPort {
		out item torqueOut : TorqueFlow;
	}

	port def EnergyInPort {
		in item energyIn : StoredEnergy;
	}

	port def EnergyOutPort {
		out item energyOut : StoredEnergy;
	}

	port def ImpulseInPort {
		in item impulseIn : BalanceImpulse;
	}

	port def ImpulseOutPort {
		out item impulseOut : BalanceImpulse;
	}

	port def RateInPort {
		in item rateIn : OscillationRate;
	}

	port def RateOutPort {
		out item rateOut : OscillationRate;
	}

	port def TickInPort {
		in item tickIn : TickPulse;
	}

	port def TickOutPort {
		out item tickOut : TickPulse;
	}

	port def HandPositionInPort {
		in item handPositionIn : HandPosition;
	}

	port def HandPositionOutPort {
		out item handPositionOut : HandPosition;
	}

	port def TimeDisplayOutPort {
		out item displayedTime : TimeReading;
	}

	port def TimeDisplayInPort {
		in item observedTime : TimeReading;
	}

	port def WindingInputPort {
		in item winding : WindingRotation;
	}

	port def SettingInputPort {
		in item setting : TimeSettingCommand;
	}

	port def RateAdjustmentInputPort {
		in item adjustment : RateAdjustmentCommand;
	}

	port def EnvironmentInputPort {
		in item ambient : AmbientCondition;
	}

	action def WindMainspring {
		in item rotation : WindingRotation;
		out item storedEnergy : StoredEnergy;
	}

	action def ReleaseControlledEnergy {
		in item storedEnergy : StoredEnergy;
		out item torque : TorqueFlow;
	}

	action def RegulateEscapement {
		in item driveTorque : TorqueFlow;
		in item balanceRate : OscillationRate;
		out item impulse : BalanceImpulse;
		out item tick : TickPulse;
	}

	action def OscillateBalance {
		in item impulse : BalanceImpulse;
		in item ambient : AmbientCondition;
		out item rate : OscillationRate;
	}

	action def CountTicks {
		in item tick : TickPulse;
		out item handPosition : HandPosition;
	}

	action def IndicateReferenceTime {
		in item handPosition : HandPosition;
		out item timeReading : TimeReading;
	}

	action def SetReferenceTime {
		in item command : TimeSettingCommand;
		out item handPosition : HandPosition;
	}

	action def AdjustDailyRate {
		in item command : RateAdjustmentCommand;
		out item regulatedRate : OscillationRate;
	}

	action def MaintainReferenceTime {
		in item energy : StoredEnergy;
		in item ambient : AmbientCondition;
		out item referenceTime : TimeReading;
	}

	state def ChronometerOperatingState {
		entry; then stopped;

		state stopped;
		state winding;
		state running;
		state setting;
		state rateAdjusting;
		state lowPower;
		state protectedStorage;

		transition stopped_to_winding first stopped then winding;
		transition winding_to_running first winding then running;
		transition running_to_setting first running then setting;
		transition setting_to_running first setting then running;
		transition running_to_rateAdjusting first running then rateAdjusting;
		transition rateAdjusting_to_running first rateAdjusting then running;
		transition running_to_lowPower first running then lowPower;
		transition lowPower_to_winding first lowPower then winding;
		transition running_to_protectedStorage first running then protectedStorage;
		transition protectedStorage_to_running first protectedStorage then running;
	}

	part def MainspringBarrel {
		attribute maximumReserve : DurationHour = 56.0;
		attribute minimumRunningReserve : DurationHour = 8.0;
		attribute nominalStoredEnergy : EnergyJoule = 24.0;

		port windingInput : WindingInputPort;
		port energyOut : EnergyOutPort;
		port torqueOut : TorqueOutPort;

		perform action wind : WindMainspring;
		perform action release : ReleaseControlledEnergy;
	}

	part def FuseeOrMaintainingPower {
		attribute torqueFlatteningEfficiency : Percentage = 92.0;
		attribute maximumOutputTorque : TorqueNewtonMeter = 0.018;
		attribute minimumOutputTorque : TorqueNewtonMeter = 0.012;

		port torqueIn : TorqueInPort;
		port torqueOut : TorqueOutPort;
	}

	part def GoingTrain {
		attribute wheelCount : Integer = 4;
		attribute nominalTickPeriod : TimeSecond = 0.5;

		port torqueIn : TorqueInPort;
		port torqueOut : TorqueOutPort;
		port tickIn : TickInPort;
		port handPositionOut : HandPositionOutPort;

		perform action countTicks : CountTicks;
	}

	part def DetentEscapement {
		attribute lockedDuringBalanceArc : Boolean = true;
		attribute impulseAngle : AngleDegree = 38.0;

		port torqueIn : TorqueInPort;
		port rateIn : RateInPort;
		port impulseOut : ImpulseOutPort;
		port tickOut : TickOutPort;

		perform action regulate : RegulateEscapement;
	}

	part def BalanceAndSpringOscillator {
		attribute nominalFrequency : FrequencyHertz = 2.0;
		attribute targetDailyRateError : TimeSecondPerDay = 0.0;
		attribute temperatureCompensated : Boolean = true;

		port impulseIn : ImpulseInPort;
		port ambientIn : EnvironmentInputPort;
		port adjustmentIn : RateAdjustmentInputPort;
		port rateOut : RateOutPort;

		perform action oscillate : OscillateBalance;
		perform action adjustRate : AdjustDailyRate;
	}

	part def GimbaledBoxAndCase {
		attribute maintainsLevelOrientation : Boolean = true;
		attribute maximumAllowedTilt : AngleDegree = 15.0;
		attribute shockProtection : Boolean = true;

		port ambientIn : EnvironmentInputPort;
	}

	part def DialAndHandsDisplay {
		attribute hourFormat : Integer = 24;
		attribute includesSecondsIndication : Boolean = true;

		port handPositionIn : HandPositionInPort;
		port timeOut : TimeDisplayOutPort;

		perform action indicate : IndicateReferenceTime;
	}

	part def SettingMechanism {
		attribute hackingStopsBalance : Boolean = false;

		port settingInput : SettingInputPort;
		port handPositionOut : HandPositionOutPort;

		perform action setTime : SetReferenceTime;
	}

	part def ChronometerPerformance {
		attribute dailyRateError : TimeSecondPerDay = 0.3;
		attribute maximumDailyRateError : TimeSecondPerDay = 0.5;
		attribute displayUncertainty : TimeSecond = 1.0;
		attribute powerReserve : DurationHour = 56.0;
		attribute ratedOperatingTemperatureLow : TemperatureCelsius = -5.0;
		attribute ratedOperatingTemperatureHigh : TemperatureCelsius = 40.0;
	}

	part def MarineChronometer {
		doc /* Primary high-level function: maintain and display an accurate Greenwich Mean Time reference aboard a moving vessel so that the navigator can determine longitude when combined with celestial observation. */

		attribute primaryFunction : String = "Keep and display accurate reference time at sea";
		attribute timeScale : String = "GMT";

		port windingPort : WindingInputPort;
		port settingPort : SettingInputPort;
		port rateAdjustmentPort : RateAdjustmentInputPort;
		port environmentPort : EnvironmentInputPort;
		port timeOutputPort : TimeDisplayOutPort;

		part performance : ChronometerPerformance;
		part barrel : MainspringBarrel;
		part maintainingPower : FuseeOrMaintainingPower;
		part train : GoingTrain;
		part escapement : DetentEscapement;
		part balance : BalanceAndSpringOscillator;
		part case : GimbaledBoxAndCase;
		part display : DialAndHandsDisplay;
		part settingMechanism : SettingMechanism;

		state operatingState : ChronometerOperatingState;

		perform action maintainReferenceTime : MaintainReferenceTime;

		connect windingPort to barrel.windingInput;
		connect settingPort to settingMechanism.settingInput;
		connect rateAdjustmentPort to balance.adjustmentIn;
		connect environmentPort to balance.ambientIn;
		connect environmentPort to case.ambientIn;

		connect barrel.torqueOut to maintainingPower.torqueIn;
		connect maintainingPower.torqueOut to train.torqueIn;
		connect train.torqueOut to escapement.torqueIn;
		connect escapement.impulseOut to balance.impulseIn;
		connect balance.rateOut to escapement.rateIn;
		connect escapement.tickOut to train.tickIn;
		connect train.handPositionOut to display.handPositionIn;
		connect settingMechanism.handPositionOut to display.handPositionIn;
		connect display.timeOut to timeOutputPort;
	}

	part def Navigator {
		port chronometerReadingIn : TimeDisplayInPort;
	}

	part def ShipboardEnvironment {
		attribute currentTemperature : TemperatureCelsius = 18.0;
		attribute humidity : Percentage = 70.0;
		attribute motionLevel : Real = 0.4;

		port ambientOut : EnvironmentInputPort;
	}

	part def MarineChronometerSystem {
		doc /* System context: a marine chronometer installed on a vessel and read by a navigator as a stable time reference for marine navigation. */

		part chronometer : MarineChronometer;
		part navigator : Navigator;
		part environment : ShipboardEnvironment;

		connect chronometer.timeOutputPort to navigator.chronometerReadingIn;
		connect environment.ambientOut to chronometer.environmentPort;
	}

	constraint def DailyRateAccuracyConstraint {
		in actualError : TimeSecondPerDay;
		in limit : TimeSecondPerDay;

		constraint { actualError <= limit }
	}

	constraint def PowerReserveConstraint {
		in reserve : DurationHour;
		in minimumReserve : DurationHour;

		constraint { reserve >= minimumReserve }
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The marine chronometer shall keep and display accurate GMT reference time aboard a ship to support longitude determination. */

		subject chronometer : MarineChronometer;

		require constraint {
			chronometer.performance.dailyRateError <= chronometer.performance.maximumDailyRateError
		}
	}

	requirement def ContinuousRunningRequirement {
		doc /* The chronometer shall provide sufficient power reserve for continuous shipboard operation between windings. */

		subject chronometer : MarineChronometer;

		require constraint {
			chronometer.performance.powerReserve >= chronometer.barrel.maximumReserve
		}
	}

	requirement def DisplayRequirement {
		doc /* The chronometer shall expose a readable time output with seconds indication and bounded display uncertainty. */

		subject chronometer : MarineChronometer;

		require constraint {
			chronometer.performance.displayUncertainty <= 1.0
		}
	}

	requirement primaryFunction : PrimaryFunctionRequirement {
		subject chronometer = MarineChronometerSystem::chronometer;
	}

	requirement continuousRunning : ContinuousRunningRequirement {
		subject chronometer = MarineChronometerSystem::chronometer;
	}

	requirement readableDisplay : DisplayRequirement {
		subject chronometer = MarineChronometerSystem::chronometer;
	}
}
