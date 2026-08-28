package fMRISystemModel {
	public import ISQ::*;
	
	attribute def ScanProtocol {
		attribute numVolumes = 100;
		attribute repetitionTime : TimeValue;
		attribute sliceThickness : LengthValue;
	}
	attribute def RawKSpaceData;
	attribute def AnatomicalImage;
	attribute def FunctionalMap;
	attribute def OperatorCommand;
	attribute def SystemStatus;
	
	part def SuperconductingMagnet {
		attribute fieldStrength : MagneticFluxDensityValue = 3.0;
		port fieldOut : MagneticFluxDensityValue;
	}
	
	part def ShimCoilSystem {
		port fieldIn : MagneticFluxDensityValue;
		port fieldOut : MagneticFluxDensityValue;
	}
	
	part def GradientCoilSystem {
		port fieldIn : MagneticFluxDensityValue;
		port protocolIn : ScanProtocol;
		port fieldOut : MagneticFluxDensityValue;
	}
	
	part def RFTxCoil {
		port protocolIn : ScanProtocol;
		port pulseOut : MagneticFluxDensityValue;
	}
	
	part def RFRxCoilArray {
		attribute channelCount = 32;
		port signalOut : ElectricPotentialValue;
	}
	
	part def SignalAmplifier {
		port signalIn : ElectricPotentialValue;
		port signalOut : ElectricPotentialValue;
	}
	
	part def ReceiverDigitizer {
		port signalIn : ElectricPotentialValue;
		port dataOut : RawKSpaceData;
	}
	
	part def ImageReconstructor {
		port dataIn : RawKSpaceData;
		port imageOut : AnatomicalImage;
	}
	
	part def FunctionalAnalysisEngine {
		port imageIn : AnatomicalImage;
		port mapOut : FunctionalMap;
	}
	
	part def ControlConsole {
		port commandOut : OperatorCommand;
		port protocolOut : ScanProtocol;
		port statusIn : SystemStatus;
		port imageIn : AnatomicalImage;
		port mapIn : FunctionalMap;
	}
	
	part def PatientTable {
		port commandIn : OperatorCommand;
		port positionOut : LengthValue;
	}
	
	action def GenerateMagneticField {
		out field : MagneticFluxDensityValue;
	}
	
	action def ShimField {
		in fieldInput : MagneticFluxDensityValue;
		out uniformField : MagneticFluxDensityValue;
	}
	
	action def ApplyGradient {
		in protocol : ScanProtocol;
		out gradientField : MagneticFluxDensityValue;
	}
	
	action def TransmitRFPulse {
		in protocol : ScanProtocol;
		out rfPulse : MagneticFluxDensityValue;
	}
	
	action def ReceiveSignal {
		out signal : ElectricPotentialValue;
	}
	
	action def AmplifySignal {
		in signalInput : ElectricPotentialValue;
		out amplifiedSignal : ElectricPotentialValue;
	}
	
	action def DigitizeSignal {
		in analogSignal : ElectricPotentialValue;
		out digitalData : RawKSpaceData;
	}
	
	action def ReconstructImage {
		in rawData : RawKSpaceData;
		out image : AnatomicalImage;
	}
	
	action def AnalyzeBOLD {
		in imageSeries : AnatomicalImage;
		out functionalMap : FunctionalMap;
	}
	
	action def AcquireVolume {
		in protocol : ScanProtocol;
		out image : AnatomicalImage;
		
		action applyGradient : ApplyGradient;
		action transmitPulse : TransmitRFPulse;
		action receive : ReceiveSignal;
		action amplify : AmplifySignal;
		action digitize : DigitizeSignal;
		action reconstruct : ReconstructImage;
		
		first start;
		then applyGradient;
		then transmitPulse;
		then receive;
		then amplify;
		then digitize;
		then reconstruct;
		then done;
	}
	
	action def PerformScan {
		in protocol : ScanProtocol;
		out images : AnatomicalImage[*];
		out functionalMap : FunctionalMap;
		
		action acquireVolume : AcquireVolume;
		action analyze : AnalyzeBOLD;
		
		first acquireVolume;
		then analyze;
	}
	
	part def fMRISystem {
		part magnet : SuperconductingMagnet;
		part shim : ShimCoilSystem;
		part gradient : GradientCoilSystem;
		part rfTx : RFTxCoil;
		part rfRx : RFRxCoilArray;
		part amplifier : SignalAmplifier;
		part digitizer : ReceiverDigitizer;
		part reconstructor : ImageReconstructor;
		part analysis : FunctionalAnalysisEngine;
		part console : ControlConsole;
		part table : PatientTable;
		
		connect magnet.fieldOut to shim.fieldIn;
		connect shim.fieldOut to gradient.fieldIn;
		connect console.protocolOut to gradient.protocolIn;
		connect console.protocolOut to rfTx.protocolIn;
		connect rfRx.signalOut to amplifier.signalIn;
		connect amplifier.signalOut to digitizer.signalIn;
		connect digitizer.dataOut to reconstructor.dataIn;
		connect reconstructor.imageOut to analysis.imageIn;
		connect analysis.mapOut to console.mapIn;
		connect reconstructor.imageOut to console.imageIn;
		connect console.commandOut to table.commandIn;
		
		state operation {
			entry; then Standby;
			state Standby;
			state Calibration;
			state ActiveScanning;
			state DataProcessing;
			state Completion;
			
			transition t1
				first Standby
				accept startScan : OperatorCommand
				then Calibration;
			transition t2
				first Calibration
				accept calibrationComplete : SystemStatus
				then ActiveScanning;
			transition t3
				first ActiveScanning
				accept scanComplete : SystemStatus
				then DataProcessing;
			transition t4
				first DataProcessing
				accept processingComplete : SystemStatus
				then Completion;
			transition t5
				first Completion
				accept reset : OperatorCommand
				then Standby;
			transition t6
				first ActiveScanning
				accept abort : OperatorCommand
				then Standby;
		}
	}
	
	requirement BOLDDetectionRequirement {
		doc /* The system shall detect BOLD signal changes corresponding to neural activity using General Linear Model statistical analysis on time-series anatomical images. */
	}
	
	requirement ImageQualityRequirement {
		doc /* The system shall reconstruct anatomical brain images with sufficient spatial and temporal resolution for functional mapping using SENSE or equivalent parallel imaging algorithms. */
	}
	
	requirement MagneticFieldRequirement {
		doc /* The system shall generate a stable 3.0 Tesla magnetic field using a superconducting magnet with active shim coil field uniformity correction. */
	}
	
	requirement SignalAcquisitionRequirement {
		doc /* The system shall acquire RF signals using a 32-channel receive coil array for enhanced sensitivity and spatial coverage of the brain. */
	}
	
	requirement OperationalStateRequirement {
		doc /* The system shall operate through distinct states including Standby, Calibration, Active Scanning, Data Processing, and Completion, with operator-controlled transitions and abort capability. */
	}
	
	part fMRISystemInstance : fMRISystem {
		satisfy BOLDDetectionRequirement;
		satisfy ImageQualityRequirement;
		satisfy MagneticFieldRequirement;
		satisfy SignalAcquisitionRequirement;
		satisfy OperationalStateRequirement;
	}
}
