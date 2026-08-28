package 'Wearable Cardioverter Defibrillator' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		item def ECGData;
		item def ShockEnergy;
		
		enum def ArrhythmiaType {
			Normal;
			VentricularTachycardia;
			VentricularFibrillation;
		}
		
		attribute def AlertCommand;
		attribute def CancelSignal;
		attribute def ChargeCommand;
		attribute def ShockCommand;
		
		action def 'Analyze Rhythm Action' {
			in ecg : ECGData;
			out arrhythmia : ArrhythmiaType;
		}
		
		action def 'Generate Alert Action' {
			in alert : AlertCommand;
		}
		
		port def ECGOutPort {
			out ecg : ECGData;
		}
		
		port def ECGInPort {
			in ecg : ECGData;
		}
		
		port def ShockInPort {
			in shock : ShockEnergy;
		}
		
		port def ShockOutPort {
			out shock : ShockEnergy;
		}
		
		port def CancelOutPort {
			out cancel : CancelSignal;
		}
		
		port def CancelInPort {
			in cancel : CancelSignal;
		}
		
		port def AlertInPort {
			in alert : AlertCommand;
		}
		
		port def ChargeInPort {
			in charge : ChargeCommand;
		}
		
		port def ShockCmdInPort {
			in shockCmd : ShockCommand;
		}
		
		part def Patient {
			port ecgInterface : ECGOutPort;
			port therapyInterface : ShockInPort;
			port responseInterface : CancelOutPort;
			attribute isResponsive : Boolean;
		}
		
		part def ECGSensorArray {
			port skinInterface : ECGInPort;
			port deviceInterface : ECGOutPort;
			attribute electrodeCount : Integer = 4;
		}
		
		part def TherapyElectrodeArray {
			port deviceInterface : ShockInPort;
			port skinInterface : ShockOutPort;
			attribute electrodeCount : Integer = 2;
		}
		
		part def RhythmProcessor {
			port ecgIn : ECGInPort;
			attribute detectedArrhythmia : ArrhythmiaType;
			perform action 'Analyze Rhythm' : 'Analyze Rhythm Action';
		}
		
		part def AlertModule {
			port alertIn : AlertInPort;
			attribute alertTimeout : Boolean;
			perform action 'Generate Alert' : 'Generate Alert Action';
		}
		
		part def Capacitor {
			port chargeIn : ChargeInPort;
			port shockCmdIn : ShockCmdInPort;
			port shockOut : ShockOutPort;
			attribute chargeComplete : Boolean;
			attribute shockDelivered : Boolean;
		}
		
		part def BatteryPack {
			attribute capacity : Real = 20;
		}
		
		part def ControlUnit {
			port ecgIn : ECGInPort;
			port shockOut : ShockOutPort;
			port cancelIn : CancelInPort;
			
			part rhythmProcessor : RhythmProcessor;
			part alertModule : AlertModule;
			part capacitor : Capacitor;
			
			flow ecgToProcessor of ECGData from ecgIn.ecg to rhythmProcessor.ecgIn.ecg;
			flow shockFromCapacitor of ShockEnergy from capacitor.shockOut.shock to shockOut.shock;
			
			exhibit state 'Control States' {
				entry; then Monitoring;
				
				state Monitoring;
				accept when rhythmProcessor.detectedArrhythmia != ArrhythmiaType::Normal
					do send new AlertCommand() to alertModule
					then Alerting;
				
				state Alerting;
				accept CancelSignal
					then Monitoring;
				accept when alertModule.alertTimeout
					do send new ChargeCommand() to capacitor
					then Charging;
				
				state Charging;
				accept when capacitor.chargeComplete
					do send new ShockCommand() to capacitor
					then DeliveringShock;
				
				state DeliveringShock;
				accept when capacitor.shockDelivered
					then Monitoring;
			}
		}
		
		part def Garment {
			part ecgElectrodes : ECGSensorArray;
			part therapyElectrodes : TherapyElectrodeArray;
		}
		
		part def WCDDevice {
			part garment : Garment;
			part controlUnit : ControlUnit;
			part batteryPack : BatteryPack;
			
			flow ecgToControl of ECGData from garment.ecgElectrodes.deviceInterface.ecg to controlUnit.ecgIn.ecg;
			flow shockToTherapy of ShockEnergy from controlUnit.shockOut.shock to garment.therapyElectrodes.deviceInterface.shock;
		}
		
		requirement def 'Operational Requirement' {
			doc /* The rechargeable battery pack shall provide over 20 hours of continuous operation. */
			attribute minOperationTime : Real = 20;
		}
		
		requirement def 'Safety Requirement' {
			doc /* The system shall provide a patient alert before delivering a shock. */
		}
		
		requirement def 'Monitoring Requirement' {
			doc /* The system shall continuously monitor the patient's ECG signal. */
		}
		
		requirement def 'Arrhythmia Detection Requirement' {
			doc /* The system shall detect ventricular tachycardia and ventricular fibrillation. */
		}
	}
	
	import Definitions::*;
	
	package Usages {
		private import Definitions::*;
		
		part patient : Patient;
		part wcdSystem : WCDDevice;
		
		interface ecgInterface connect patient.ecgInterface to wcdSystem.garment.ecgElectrodes.skinInterface {
			flow ecgFlow of ECGData from patient.ecgInterface.ecg to wcdSystem.garment.ecgElectrodes.skinInterface.ecg;
		}
		
		interface therapyInterface connect wcdSystem.garment.therapyElectrodes.skinInterface to patient.therapyInterface {
			flow shockFlow of ShockEnergy from wcdSystem.garment.therapyElectrodes.skinInterface.shock to patient.therapyInterface.shock;
		}
		
		interface responseInterface connect patient.responseInterface to wcdSystem.controlUnit.cancelIn {
			flow cancelFlow of CancelSignal from patient.responseInterface.cancel to wcdSystem.controlUnit.cancelIn.cancel;
		}
		
		requirement 'WCD Operational Req' : 'Operational Requirement';
		requirement 'WCD Safety Req' : 'Safety Requirement';
		requirement 'WCD Monitoring Req' : 'Monitoring Requirement';
		requirement 'WCD Arrhythmia Detection Req' : 'Arrhythmia Detection Requirement';
	}
}
