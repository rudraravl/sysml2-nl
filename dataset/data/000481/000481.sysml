package 'Open Flow Microperfusion System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FlowRate :> ISQ::VolumetricFlowRateValue;
	
	attribute def Pressure :> ISQ::PressureValue;
	
	attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
	
	attribute def Concentration :> Real;
	
	attribute def StartPerfusion;
	attribute def StopPerfusion;
	attribute def CollectionInterval;
	
	item def PerfusionFluid {
		attribute temperature : Temperature;
		attribute flowRate : FlowRate;
		attribute composition : String;
	}
	
	item def InterstitialSample {
		attribute analyteConcentration : Concentration;
		attribute collectionTime : ISQ::DurationValue;
		attribute sampleVolume : ISQ::VolumeValue;
	}
	
	port def FluidInPort {
		attribute inletPressure : Pressure;
		in item fluid : PerfusionFluid;
	}
	
	port def FluidOutPort {
		attribute outletPressure : Pressure;
		out item fluid : PerfusionFluid;
	}
	
	port def TissueInterfacePort {
		attribute tissuePressure : Pressure;
		attribute tissueTemperature : Temperature;
		out item deliveredFluid : PerfusionFluid;
		in item recoveredFluid : PerfusionFluid;
	}
	
	port def SamplePort {
		out item sample : InterstitialSample;
		attribute sampleVolume : ISQ::VolumeValue;
	}
	
	part def FluidReservoir {
		attribute capacity : ISQ::VolumeValue;
		attribute currentLevel : ISQ::VolumeValue;
		port outlet : FluidOutPort;
	}
	
	part def MicrofluidicPump {
		attribute targetFlowRate : FlowRate;
		attribute actualFlowRate : FlowRate;
		attribute operatingPressure : Pressure;
		port inlet : FluidInPort;
		port outlet : FluidOutPort;
	}
	
	part def MicroperfusionProbe {
		attribute probeLength : ISQ::LengthValue;
		attribute membranePoreSize : ISQ::LengthValue;
		attribute activeMembraneArea : ISQ::AreaValue;
		attribute insertionDepth : ISQ::LengthValue;
		port fluidInlet : FluidInPort;
		port tissueInterface : TissueInterfacePort;
	}
	
	part def SampleCollector {
		attribute collectionInterval : ISQ::DurationValue;
		attribute totalSamplesCollected : Integer;
		port sampleInlet : FluidInPort;
		port sampleOutput : SamplePort;
	}
	
	part def TemperatureRegulator {
		attribute setpoint : Temperature;
		attribute currentTemperature : Temperature;
		attribute heatingPower : ISQ::PowerValue;
	}
	
	part def PressureMonitor {
		attribute measuredPressure : Pressure;
		attribute alarmThreshold : Pressure;
		attribute alarmStatus : Boolean;
	}
	
	part def FlowController {
		attribute desiredFlowRate : FlowRate;
		attribute measuredFlowRate : FlowRate;
		attribute controlSignal : Real;
	}
	
	action def DeliverPerfusionFluid {
		in targetFlow : FlowRate;
		in duration : ISQ::DurationValue;
		out deliveredFluid : PerfusionFluid;
		out totalVolume : ISQ::VolumeValue;
	}
	
	action def ExchangeWithTissue {
		in perfusateIn : PerfusionFluid;
		in tissuePressure : Pressure;
		out dialysateOut : PerfusionFluid;
		out extractedAnalytes : Concentration;
	}
	
	action def CollectDialysate {
		in dialysateFluid : PerfusionFluid;
		in collectionTime : ISQ::DurationValue;
		out sample : InterstitialSample;
	}
	
	action def MonitorFlowAndPressure {
		out currentFlow : FlowRate;
		out currentPressure : Pressure;
		out systemStatus : Boolean;
	}
	
	action def RegulateTemperature {
		in targetTemp : Temperature;
		in measuredTemp : Temperature;
		out heatingCommand : ISQ::PowerValue;
	}
	
	action def PerformContinuousMicroperfusion {
		in operatingFlowRate : FlowRate;
		in operatingTemperature : Temperature;
		in sessionDuration : ISQ::DurationValue;
		out collectedSamples : InterstitialSample[0..*];
		
		first start;
		then merge continuePerfusion;
		
		then action initializeSystem {
			out ready : Boolean;
		}
		
		then action deliverPerfusate : DeliverPerfusionFluid {
			in targetFlow = operatingFlowRate;
			in duration : ISQ::DurationValue;
			out deliveredFluid : PerfusionFluid;
			out totalVolume : ISQ::VolumeValue;
		}
		
		flow deliverPerfusate.deliveredFluid to exchangeAnalytes.perfusateIn;
		
		then action exchangeAnalytes : ExchangeWithTissue {
			in perfusateIn : PerfusionFluid;
			in tissuePressure : Pressure;
			out dialysateOut : PerfusionFluid;
			out extractedAnalytes : Concentration;
		}
		
		flow exchangeAnalytes.dialysateOut to collectSample.dialysateFluid;
		
		then action collectSample : CollectDialysate {
			in dialysateFluid : PerfusionFluid;
			in collectionTime : ISQ::DurationValue;
			out sample : InterstitialSample;
		}
		
		then action monitorParameters : MonitorFlowAndPressure {
			out currentFlow : FlowRate;
			out currentPressure : Pressure;
			out systemStatus : Boolean;
		}
		
		then decide;
			if monitorParameters.systemStatus then continuePerfusion;
			if not monitorParameters.systemStatus then emergencyShutdown;
		
		action emergencyShutdown;
		then done;
		
		then action archiveSamples {
			in samples = collectedSamples;
		}
		
		then done;
	}
	
	part ofmSystem {
		attribute nominalFlowRate : FlowRate;
		attribute nominalTemperature : Temperature;
		attribute maximumPressure : Pressure;
		
		part reservoir : FluidReservoir {
			attribute :>> capacity;
			attribute :>> currentLevel;
		}
		
		part pump : MicrofluidicPump {
			attribute :>> targetFlowRate = ofmSystem.nominalFlowRate;
		}
		
		part temperatureRegulator : TemperatureRegulator {
			attribute :>> setpoint = ofmSystem.nominalTemperature;
		}
		
		part probe : MicroperfusionProbe {
			attribute :>> probeLength;
			attribute :>> membranePoreSize;
			attribute :>> activeMembraneArea;
			attribute :>> insertionDepth;
		}
		
		part pressureMonitor : PressureMonitor {
			attribute :>> alarmThreshold = ofmSystem.maximumPressure;
		}
		
		part flowController : FlowController {
			attribute :>> desiredFlowRate = ofmSystem.nominalFlowRate;
		}
		
		part collector : SampleCollector {
			attribute :>> collectionInterval;
			attribute :>> totalSamplesCollected = 0;
		}
		
		connect reservoir.outlet to pump.inlet;
		connect pump.outlet to probe.fluidInlet;
		connect probe.tissueInterface to collector.sampleInlet;
		
		perform action perfusionOperation : PerformContinuousMicroperfusion {
			in operatingFlowRate = ofmSystem.nominalFlowRate;
			in operatingTemperature = ofmSystem.nominalTemperature;
			in sessionDuration;
			out collectedSamples : InterstitialSample[0..*];
		}
	}
	
	requirement def OFMSystemRequirements {
		doc /* The open flow microperfusion system shall continuously deliver sterile 
		     * perfusion fluid through a semi-permeable membrane probe implanted in tissue, 
		     * enabling passive diffusion-based exchange of metabolites and biomarkers 
		     * from the interstitial space into the perfusate stream for real-time 
		     * biochemical monitoring without sample loss or tissue damage. */
		
		requirement continuousFlowDelivery {
			doc /* The system shall maintain continuous perfusion flow at the target rate. */
			subject ofmSystem.pump;
		}
		
		requirement temperatureControl {
			doc /* The system shall maintain perfusate temperature within physiological range. */
			subject ofmSystem.temperatureRegulator;
		}
		
		requirement pressureSafety {
			doc /* The system shall not exceed maximum safe operating pressure. */
			subject ofmSystem.pressureMonitor;
		}
		
		requirement sampleIntegrity {
			doc /* The system shall collect samples at regular intervals without contamination. */
			subject ofmSystem.collector;
		}
		
		requirement membranePermeability {
			doc /* The probe membrane shall allow selective diffusion of target analytes. */
			subject ofmSystem.probe;
		}
	}
}
