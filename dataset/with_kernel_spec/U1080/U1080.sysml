package HomeEnergyMonitor {
	doc /* This model describes a Home Energy Monitor system that tracks and displays real-time electricity consumption. */

	private import ScalarValues::*;

	attribute def VoltageReading :> Real;
	attribute def CurrentReading :> Real;
	attribute def PowerValue :> Real;
	attribute def EnergyValue :> Real;
	attribute def CostValue :> Real;
	attribute def LengthValue :> Real;
	attribute def DurationValue :> Real;

	item def SensorData {
		attribute voltage : VoltageReading;
		attribute current : CurrentReading;
	}

	item def DisplayData {
		attribute instantaneousPower : PowerValue;
		attribute totalEnergy : EnergyValue;
		attribute averagePower : PowerValue;
		attribute peakPower : PowerValue;
		attribute estimatedCost : CostValue;
		attribute alertActive : Boolean;
	}

	item def AlertSignal {
		attribute active : Boolean;
	}

	port def VoltageOutPort {
		out voltageReading : VoltageReading;
	}
	port def CurrentOutPort {
		out currentReading : CurrentReading;
	}
	port def VoltageInPort {
		in voltageReading : VoltageReading;
	}
	port def CurrentInPort {
		in currentReading : CurrentReading;
	}
	port def DisplayDataOutPort {
		out displayData : DisplayData;
	}
	port def DisplayDataInPort {
		in displayData : DisplayData;
	}
	port def AlertOutPort {
		out alertSignal : AlertSignal;
	}
	port def AlertInPort {
		in alertSignal : AlertSignal;
	}

	interface def VoltageInterface {
		end voltageOut : VoltageOutPort;
		end voltageIn : VoltageInPort;
		flow voltageOut.voltageReading to voltageIn.voltageReading;
	}
	interface def CurrentInterface {
		end currentOut : CurrentOutPort;
		end currentIn : CurrentInPort;
		flow currentOut.currentReading to currentIn.currentReading;
	}
	interface def DisplayInterface {
		end displayOut : DisplayDataOutPort;
		end displayIn : DisplayDataInPort;
		flow displayOut.displayData to displayIn.displayData;
	}
	interface def AlertInterface {
		end alertOut : AlertOutPort;
		end alertIn : AlertInPort;
		flow alertOut.alertSignal to alertIn.alertSignal;
	}

	action def ReadSensors {
		out voltage : VoltageReading;
		out current : CurrentReading;
	}
	action def ComputePower {
		in voltage : VoltageReading;
		in current : CurrentReading;
		out power : PowerValue;
	}
	action def UpdateMetrics {
		in power : PowerValue;
		inout totalEnergy : EnergyValue;
		inout peakPower : PowerValue;
		inout averagePower : PowerValue;
		inout currentDailyCost : CostValue;
		inout samplingCount : Integer;
		in costPerKWh : CostValue;
	}
	action def CheckThresholds {
		in power : PowerValue;
		in dailyCost : CostValue;
		in maxPower : PowerValue;
		in maxCost : CostValue;
		out alertActive : Boolean;
	}
	action def SendDisplay {
		in power : PowerValue;
		in totalEnergy : EnergyValue;
		in averagePower : PowerValue;
		in peakPower : PowerValue;
		in estimatedCost : CostValue;
		in alertActive : Boolean;
		out displayData : DisplayData;
	}
	action def TriggerAlert {
		in alertActive : Boolean;
		out alertSignal : AlertSignal;
	}
	action def ActivateAlerts;
	action def DeactivateAlerts;

	part def VoltageSensor {
		port voltageOut : VoltageOutPort;
	}
	part def CurrentSensor {
		port currentOut : CurrentOutPort;
	}

	part def Processor {
		port voltageIn : VoltageInPort;
		port currentIn : CurrentInPort;
		port displayDataOut : DisplayDataOutPort;
		port alertOut : AlertOutPort;

		attribute maxPowerThreshold : PowerValue = 5000;
		attribute maxDailyCostThreshold : CostValue = 10.0;
		attribute costPerKWh : CostValue = 0.15;
		attribute samplingInterval : DurationValue = 1.0;
		attribute totalEnergy : EnergyValue = 0.0;
		attribute peakPower : PowerValue = 0.0;
		attribute averagePower : PowerValue = 0.0;
		attribute currentDailyCost : CostValue = 0.0;
		attribute samplingCount : Integer = 0;
		attribute alertActive : Boolean = false;
		attribute currentPower : PowerValue = 0.0;

		behavior processBehavior {
			action readSensors : ReadSensors;
			then action computePower : ComputePower;
			then action updateMetrics : UpdateMetrics;
			then action checkThresholds : CheckThresholds;
			then action triggerAlert : TriggerAlert;
			then action sendDisplay : SendDisplay;
		}
	}

	part def Display {
		attribute screenSize : LengthValue = 7.0;
		port displayDataIn : DisplayDataInPort;
	}

	part def VisualAlert {
		attribute active : Boolean = false;
	}
	part def AudioAlert {
		attribute active : Boolean = false;
	}

	part def NotificationModule {
		port alertIn : AlertInPort;
		part visualAlert : VisualAlert;
		part audioAlert : AudioAlert;

		behavior alertBehavior {
			action activateAlerts : ActivateAlerts;
			then action deactivateAlerts : DeactivateAlerts;
		}
	}

	requirement def MeasureElectricity {
		doc /* The system shall continuously measure voltage and current from the main power supply. */
	}
	requirement def ComputeMetrics {
		doc /* The processing unit shall calculate instantaneous power, total energy, average power, peak power, and estimated cost. */
	}
	requirement def AlertOnHighUsage {
		doc /* The system shall issue a visual and audio alert when power consumption exceeds user-defined thresholds. */
	}
	requirement def DisplayInfo {
		doc /* The system shall present energy information to the homeowner on a dedicated display. */
	}

	part def HomeEnergyMonitorSystem {
		part voltageSensor : VoltageSensor;
		part currentSensor : CurrentSensor;
		part processor : Processor;
		part display : Display;
		part notification : NotificationModule;

		interface voltageConnection : VoltageInterface
			connect voltageSensor.voltageOut to processor.voltageIn;
		interface currentConnection : CurrentInterface
			connect currentSensor.currentOut to processor.currentIn;
		interface displayConnection : DisplayInterface
			connect processor.displayDataOut to display.displayDataIn;
		interface alertConnection : AlertInterface
			connect processor.alertOut to notification.alertIn;
	}

	requirement req_measure : MeasureElectricity {
		satisfied by HomeEnergyMonitorSystem::voltageSensor, HomeEnergyMonitorSystem::currentSensor;
	}
	requirement req_compute : ComputeMetrics {
		satisfied by HomeEnergyMonitorSystem::processor;
	}
	requirement req_alert : AlertOnHighUsage {
		satisfied by HomeEnergyMonitorSystem::processor, HomeEnergyMonitorSystem::notification;
	}
	requirement req_display : DisplayInfo {
		satisfied by HomeEnergyMonitorSystem::display;
	}

	part homeEnergyMonitor : HomeEnergyMonitorSystem;
}
