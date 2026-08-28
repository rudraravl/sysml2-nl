package 'Protected PCI System' {
	private import ScalarValues::*;

	attribute def HeartRateValue :> Real;
	attribute def PressureValue :> Real;
	attribute def OxygenSaturationValue :> Real;
	attribute def FlowRateValue :> Real;

	item def Blood;
	item def ContrastAgent;
	item def XRayBeam;
	item def Plaque;

	attribute def PumpCommand;
	attribute def RampUpCommand;
	attribute def WeanDownCommand;
	attribute def AlertSignal;
	attribute def StartSignal;
	attribute def StopSignal;
	attribute def ImageData;

	port def BloodFlowPort {
		out item blood : Blood;
		in item bloodReturn : Blood;
	}
	port def ContrastFlowPort {
		out item contrast : ContrastAgent;
	}
	port def XRayPort {
		out item beam : XRayBeam;
	}
	port def ControlPort {
		in command;
		out status;
	}
	port def MonitoringPort {
		out heartRate : HeartRateValue;
		out bloodPressure : PressureValue;
		out oxygenSaturation : OxygenSaturationValue;
		out alert : AlertSignal;
	}
	port def ImagePort {
		out image : ImageData;
	}
	port def ToolPort;

	action def CirculateBlood {
		in item bloodIn : Blood;
		out item bloodOut : Blood;
	}
	action def InjectContrast {
		out item contrast : ContrastAgent;
	}
	action def AcquireFluoroscopy {
		in item beam : XRayBeam;
		out image : ImageData;
	}
	action def MonitorHemodynamics {
		out heartRate : HeartRateValue;
		out bloodPressure : PressureValue;
		out oxygenSaturation : OxygenSaturationValue;
	}
	action def PerformIntervention;

	part def MechanicalCirculatorySupport {
		attribute flowRate : FlowRateValue;
		attribute maxFlowRate : FlowRateValue = 5.0;
		port bloodInPort : ~BloodFlowPort;
		port bloodOutPort : BloodFlowPort;
		port controlPort : ControlPort;

		perform action circulateBlood : CirculateBlood {
			in bloodIn = bloodInPort.blood;
			out bloodOut = bloodOutPort.blood;
		}

		exhibit state MCSStates {
			entry; then standby;
			state standby;
			accept StartSignal via controlPort
				then priming;
			state priming;
			accept PumpCommand via controlPort
				then activeSupport;
			state activeSupport {
				do circulateBlood;
			}
			accept RampUpCommand via controlPort
				then activeSupport;
			accept WeanDownCommand via controlPort
				then weaning;
			state weaning;
			accept StopSignal via controlPort
				then standby;
		}
	}

	part def GuideCatheter {
		port proximalPort : ToolPort;
		port distalPort : ToolPort;
	}
	part def GuideWire {
		port wirePort : ToolPort;
	}
	part def BalloonCatheter {
		attribute inflated : Boolean = false;
		port wirePort : ToolPort;
		port balloonPort : ToolPort;
	}
	part def CoronaryStent {
		attribute deployed : Boolean = false;
		port stentPort : ToolPort;
	}

	part def InterventionalToolSet {
		part guideCatheter : GuideCatheter;
		part guideWire : GuideWire;
		part balloonCatheter : BalloonCatheter;
		part coronaryStent : CoronaryStent;

		perform action performIntervention : PerformIntervention;
	}

	part def FluoroscopySystem {
		port contrastPort : ContrastFlowPort;
		port xrayPort : XRayPort;
		port controlPort : ControlPort;
		port imagePort : ImagePort;

		perform action injectContrast : InjectContrast {
			out contrast = contrastPort.contrast;
		}
		perform action acquireFluoroscopy : AcquireFluoroscopy {
			in beam = xrayPort.beam;
			out image = imagePort.image;
		}
	}

	part def HemodynamicMonitor {
		attribute maxHeartRate : HeartRateValue = 120;
		attribute minBloodPressure : PressureValue = 90;
		port monitoringPort : MonitoringPort;
		port controlPort : ControlPort;

		perform action monitorHemodynamics : MonitorHemodynamics {
			out heartRate = monitoringPort.heartRate;
			out bloodPressure = monitoringPort.bloodPressure;
			out oxygenSaturation = monitoringPort.oxygenSaturation;
		}

		exhibit state MonitoringStates {
			entry; then stable;
			state stable {
				do monitorHemodynamics;
			}
			accept when monitorHemodynamics.heartRate > maxHeartRate
				then unstable;
			state unstable;
			accept when monitorHemodynamics.heartRate <= maxHeartRate
				then stable;
		}
	}

	part def ControlConsole {
		port mcsControlPort : ~ControlPort;
		port fluoroControlPort : ~ControlPort;
		port monitorControlPort : ~ControlPort;
		port monitorDataPort : ~MonitoringPort;
		port imagePort : ~ImagePort;

		exhibit state ConsoleStates {
			entry; then idle;
			state idle;
			accept StartSignal
				then active;
			state active;
		}
	}

	part def Patient {
		attribute heartRate : HeartRateValue;
		attribute bloodPressure : PressureValue;
		attribute oxygenSaturation : OxygenSaturationValue;

		part leftVentricle {
			port bloodPort : BloodFlowPort;
			item blood : Blood;
		}
		part aorta {
			port bloodPort : ~BloodFlowPort;
			item blood : Blood;
		}
		part coronaryArtery {
			port accessPort : ToolPort;
			item plaque : Plaque;
		}
		part legAccess {
			port contrastPort : ~ContrastFlowPort;
			port toolPort : ToolPort;
		}
		port xrayPort : ~XRayPort;
	}

	part def ProtectedPCISystem {
		part patient : Patient;
		part mcs : MechanicalCirculatorySupport;
		part tools : InterventionalToolSet;
		part fluoro : FluoroscopySystem;
		part monitor : HemodynamicMonitor;
		part console : ControlConsole;

		flow of blood : Blood
			from patient.leftVentricle.bloodPort.blood to mcs.bloodInPort.blood;
		flow of blood : Blood
			from mcs.bloodOutPort.blood to patient.aorta.bloodPort.blood;

		connect mcs.controlPort to console.mcsControlPort;
		connect fluoro.controlPort to console.fluoroControlPort;
		connect monitor.controlPort to console.monitorControlPort;
		connect monitor.monitoringPort to console.monitorDataPort;
		connect fluoro.imagePort to console.imagePort;

		connect fluoro.contrastPort to patient.legAccess.contrastPort;
		connect fluoro.xrayPort to patient.xrayPort;

		connect tools.guideCatheter.proximalPort to patient.legAccess.toolPort;
		connect tools.guideCatheter.distalPort to patient.coronaryArtery.accessPort;
		connect tools.guideWire.wirePort to tools.guideCatheter.distalPort;
		connect tools.balloonCatheter.wirePort to tools.guideWire.wirePort;
		connect tools.coronaryStent.stentPort to tools.balloonCatheter.balloonPort;
	}

	requirement def ProtectedPCIRequirement {
		doc /* The system shall provide mechanical circulatory support during high-risk PCI to maintain hemodynamic stability while enabling precise coronary intervention and real-time monitoring. */;
	}

	part protectedPCISystem : ProtectedPCISystem;
	satisfy ProtectedPCIRequirement by protectedPCISystem;
}
