package 'Medical Emergency Crash Cart' {
	private import ScalarValues::*;
	
	attribute def HeartRate :> Real;
	attribute def BloodPressure :> Real;
	attribute def OxygenSaturation :> Real;
	attribute def ElectricalEnergy :> Real;
	attribute def OxygenFlowRate :> Real;
	attribute def Pressure :> Real;
	attribute def BatteryVoltage :> Real;
	
	attribute def 'Start Resuscitation';
	attribute def 'End Resuscitation';
	
	item def Oxygen;
	item def Medication;
	item def Epinephrine :> Medication;
	item def Atropine :> Medication;
	item def Amiodarone :> Medication;
	
	item def AirwayTool;
	item def EndotrachealTube :> AirwayTool;
	item def BagValveMask :> AirwayTool;
	item def SuctionDevice :> AirwayTool;
	
	port def PatientMonitorPort {
		out heartRate : HeartRate;
		out bloodPressure : BloodPressure;
		out oxygenSaturation : OxygenSaturation;
		out ecgRhythm : String;
	}
	
	port def DefibShockPort {
		in rhythm : String;
		out shock : ElectricalEnergy;
	}
	
	port def OxygenFlowPort {
		out oxygenFlow : Oxygen;
		attribute flowRate : OxygenFlowRate;
	}
	
	port def PowerPort {
		out power : ElectricalEnergy;
	}
	
	action def MonitorPatient {
		out hr : HeartRate;
		out bp : BloodPressure;
		out spo2 : OxygenSaturation;
		out rhythm : String;
	}
	
	action def AnalyzeRhythm {
		in rhythm : String;
		out shockAdvised : Boolean;
	}
	
	action def DeliverShock {
		in shockAdvised : Boolean;
		out energy : ElectricalEnergy;
	}
	
	action def RegulateOxygen {
		in pressure : Pressure;
		out oxygenFlow : Oxygen;
		attribute rate : OxygenFlowRate;
	}
	
	action def AdministerMedication {
		in med : Medication;
	}
	
	action def ManageAirway {
		in tool : AirwayTool;
	}
	
	action def PerformResuscitation {
		action monitor : MonitorPatient;
		action analyze : AnalyzeRhythm;
		action shock : DeliverShock;
		action administerMeds : AdministerMedication;
		action supportBreathing : RegulateOxygen;
		
		succession first monitor then analyze;
		succession first analyze then shock;
		succession first analyze then administerMeds;
		succession first monitor then supportBreathing;
	}
	
	action 'perform resuscitation' : PerformResuscitation;
	
	part def DefibrillatorMonitor {
		port monitorPort : PatientMonitorPort;
		port shockPort : DefibShockPort;
		port powerIn : PowerPort;
		
		attribute isCharged : Boolean;
		
		perform action monitorPatient : MonitorPatient;
		perform action analyzeRhythm : AnalyzeRhythm;
		perform action deliverShock : DeliverShock;
	}
	
	part def OxygenSystem {
		port oxygenOut : OxygenFlowPort;
		attribute tankPressure : Pressure;
		
		perform action regulateOxygen : RegulateOxygen;
	}
	
	part def MedicationDrawer {
		item epinephrine : Epinephrine;
		item atropine : Atropine;
		item amiodarone : Amiodarone;
		
		perform action administerMedication : AdministerMedication;
	}
	
	part def AirwayEquipment {
		item ett : EndotrachealTube;
		item bvm : BagValveMask;
		item suction : SuctionDevice;
		
		perform action manageAirway : ManageAirway;
	}
	
	part def PowerSupply {
		port powerOut : PowerPort;
		attribute batteryLevel : Real;
	}
	
	state def CartStates;
	
	state cartStates : CartStates {
		entry; then idle;
		state idle;
		accept 'Start Resuscitation' then inUse;
		state inUse {
			do 'perform resuscitation';
		}
		accept 'End Resuscitation' then idle;
	}
	
	part def CrashCart {
		part defibrillator : DefibrillatorMonitor;
		part oxygenSystem : OxygenSystem;
		part medDrawer : MedicationDrawer;
		part airwayKit : AirwayEquipment;
		part powerSupply : PowerSupply;
		
		connection def PowerConnection {
			end supplier : PowerPort;
			end consumer : PowerPort;
		}
		
		connection powerConnection : PowerConnection connect powerSupply.powerOut to defibrillator.powerIn;
	}
	
	part cart : CrashCart {
		exhibit state cartState : CartStates;
	}
	
	requirement def 'Provide Rapid Response' {
		subject c : CrashCart;
		doc /* The cart shall provide all necessary life-support equipment in one mobile platform. */
	}
	
	requirement def 'Monitor Vital Signs' {
		subject d : DefibrillatorMonitor;
		doc /* The defibrillator shall continuously monitor heart rate, blood pressure, oxygen saturation, and ECG rhythm. */
	}
	
	requirement def 'Deliver Defibrillation' {
		subject d : DefibrillatorMonitor;
		doc /* The defibrillator shall analyze the heart rhythm and deliver a controlled shock if needed. */
	}
	
	requirement def 'Provide Oxygen Support' {
		subject o : OxygenSystem;
		doc /* The oxygen system shall deliver a controlled flow of oxygen to the patient. */
	}
	
	requirement def 'Maintain Power' {
		subject p : PowerSupply;
		doc /* The power supply shall run the defibrillator and monitor away from a wall outlet. */
	}
}
