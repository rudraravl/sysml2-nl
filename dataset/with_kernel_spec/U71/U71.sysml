package 'Hypoglossal Nerve Stimulation System' {
	package Definitions {
		private import ISQ::*;
		private import ScalarValues::*;

		attribute def Airflow :> Real;
		attribute def BreathingRate :> Real;
		attribute def StimulationAmplitude :> Real;
		attribute def PulseWidth :> Real;
		attribute def PulseFrequency :> Real;

		attribute def BreathingData {
			attribute airflow : Airflow;
			attribute rate : BreathingRate;
		}
		attribute def ApneaEvent;
		attribute def OnCommand;
		attribute def OffCommand;
		attribute def StimulationPulse {
			attribute amplitude : StimulationAmplitude;
			attribute pulseWidth : PulseWidth;
			attribute frequency : PulseFrequency;
		}

		port def SensorOutPort {
			out breathingData : BreathingData;
			out apneaEvent : ApneaEvent;
		}
		port def IPGSensorInPort {
			in breathingData : BreathingData;
			in apneaEvent : ApneaEvent;
		}
		port def IPGStimOutPort {
			out pulse : StimulationPulse;
		}
		port def LeadInPort {
			in pulse : StimulationPulse;
		}
		port def LeadOutPort {
			out pulse : StimulationPulse;
		}
		port def ElectrodeOutPort {
			out pulse : StimulationPulse;
		}
		port def NerveInPort {
			in pulse : StimulationPulse;
		}
		port def RemoteOutPort {
			out onCmd : OnCommand;
			out offCmd : OffCommand;
		}
		port def RemoteInPort {
			in onCmd : OnCommand;
			in offCmd : OffCommand;
		}

		part def RespiratorySensor {
			port sensorOut : SensorOutPort;
		}
		part def ImplantablePulseGenerator {
			port sensorIn : IPGSensorInPort;
			port stimOut : IPGStimOutPort;
			port remoteIn : RemoteInPort;
		}
		part def StimulationLead {
			port leadIn : LeadInPort;
			port leadOut : LeadOutPort;
		}
		part def NerveCuffElectrode {
			port electrodeIn : LeadInPort;
			port electrodeOut : ElectrodeOutPort;
		}
		part def HypoglossalNerve {
			port nerveIn : NerveInPort;
		}
		part def GenioglossalMuscle;
		part def UpperAirway;
		part def RemoteControl {
			port remoteOut : RemoteOutPort;
		}

		action def MonitorBreathing {
			out breathingData : BreathingData;
		}
		action def DetectApnea {
			in breathingData : BreathingData;
			out apneaEvent : ApneaEvent;
		}
		action def GeneratePulses {
			in apneaEvent : ApneaEvent;
			out pulse : StimulationPulse;
		}
		action def StimulateNerve {
			in pulse : StimulationPulse;
		}
		action def ContractMuscle;
		action def OpenAirway;

		requirement def ApneaDetectionRequirement {
			/* The system shall continuously monitor breathing and detect apnea events during sleep. */
		}
		requirement def StimulationRequirement {
			/* The system shall deliver electrical stimulation to the hypoglossal nerve upon detecting an apnea event. */
		}
		requirement def AirwayPatencyRequirement {
			/* The system shall maintain upper airway patency by activating the genioglossal muscle. */
		}
		requirement def RemoteControlRequirement {
			/* The system shall be turned on and off by an external remote control. */
		}
		requirement def AutomaticOperationRequirement {
			/* The system shall operate automatically throughout the night without waking the patient. */
		}
	}

	package Usages {
		private import Definitions::*;

		part hnsSystem {
			part respiratorySensor : RespiratorySensor;
			part ipg : ImplantablePulseGenerator;
			part lead : StimulationLead;
			part electrode : NerveCuffElectrode;
			part nerve : HypoglossalNerve;
			part muscle : GenioglossalMuscle;
			part airway : UpperAirway;
			part remote : RemoteControl;

			connect respiratorySensor.sensorOut to ipg.sensorIn;
			connect ipg.stimOut to lead.leadIn;
			connect lead.leadOut to electrode.electrodeIn;
			connect electrode.electrodeOut to nerve.nerveIn;
			connect remote.remoteOut to ipg.remoteIn;

			flow breathingDataFlow of BreathingData
				from respiratorySensor.sensorOut.breathingData to ipg.sensorIn.breathingData;
			flow apneaEventFlow of ApneaEvent
				from respiratorySensor.sensorOut.apneaEvent to ipg.sensorIn.apneaEvent;
			flow pulseFlow of StimulationPulse
				from ipg.stimOut.pulse to lead.leadIn.pulse;
			flow leadPulseFlow of StimulationPulse
				from lead.leadOut.pulse to electrode.electrodeIn.pulse;
			flow electrodePulseFlow of StimulationPulse
				from electrode.electrodeOut.pulse to nerve.nerveIn.pulse;
			flow onCmdFlow of OnCommand
				from remote.remoteOut.onCmd to ipg.remoteIn.onCmd;
			flow offCmdFlow of OffCommand
				from remote.remoteOut.offCmd to ipg.remoteIn.offCmd;

			action therapy {
				loop {
					accept on : OnCommand;
					then action {
						action monitor : MonitorBreathing {
							out breathingData;
						}
						then action detect : DetectApnea {
							in breathingData = monitor.breathingData;
							out apneaEvent;
						}
						then action generate : GeneratePulses {
							in apneaEvent = detect.apneaEvent;
							out pulse;
						}
						then action stimulate : StimulateNerve {
							in pulse = generate.pulse;
						}
						then action contract : ContractMuscle;
						then action open : OpenAirway;
					}
					then accept off : OffCommand;
				}
			}

			satisfy ApneaDetectionRequirement by therapy;
			satisfy StimulationRequirement by therapy;
			satisfy AirwayPatencyRequirement by therapy;
			satisfy RemoteControlRequirement by therapy;
			satisfy AutomaticOperationRequirement by therapy;
		}
	}
}
