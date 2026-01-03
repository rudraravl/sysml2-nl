package 'NDIR Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	
	attribute def PPMUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[1];
	}
	
	attribute def ConcentrationValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : PPMUnit;
	}
	
	attribute concentration : ConcentrationValue :> scalarQuantities;
	
	attribute def WavelengthValue :> LengthValue;
	
	attribute def IntensityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	item def GasSample {
		attribute gasConcentration : ConcentrationValue;
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
	}
	
	item def InfraredBeam {
		attribute wavelength : WavelengthValue;
		attribute intensity : IntensityValue;
	}
	
	item def DetectorSignal {
		attribute signalVoltage : Real;
		attribute signalIntensity : IntensityValue;
	}
	
	item def MeasurementData {
		attribute measuredConcentration : ConcentrationValue;
		attribute timestamp : Real;
		attribute accuracy : Real;
	}
	
	port def GasInletPort {
		in item gas : GasSample;
	}
	
	port def GasOutletPort {
		out item gas : GasSample;
	}
	
	port def OpticalPort {
		out item beam : InfraredBeam;
	}
	
	port def DetectionPort {
		in item beam : InfraredBeam;
		out item signal : DetectorSignal;
	}
	
	port def DataOutputPort {
		out item data : MeasurementData;
	}
	
	connection def OpticalConnection {
		end source : OpticalPort;
		end target : DetectionPort;
	}
	
	connection def GasFlowConnection {
		end inlet : GasInletPort;
		end outlet : GasOutletPort;
	}
	
	part def InfraredEmitter {
		port emitterPort : OpticalPort;
		
		attribute operatingTemperature : TemperatureValue;
		attribute emissionWavelength : WavelengthValue;
		attribute emissionPower : PowerValue;
		
		action emitInfrared {
			out item irBeam : InfraredBeam;
		}
	}
	
	part def OpticalBandpassFilter {
		port inputPort : OpticalPort;
		port outputPort : OpticalPort;
		
		attribute centerWavelength : WavelengthValue;
		attribute bandwidthWavelength : WavelengthValue;
		attribute transmittance : Real;
		
		action filterBeam {
			in item inputBeam : InfraredBeam;
			out item filteredBeam : InfraredBeam;
		}
	}
	
	part def GasMeasurementChamber {
		port gasInlet : GasInletPort;
		port gasOutlet : GasOutletPort;
		port opticalInput : OpticalPort;
		port opticalOutput : OpticalPort;
		
		attribute pathLength : LengthValue;
		attribute chamberVolume : Real;
		attribute windowTransmittance : Real;
		
		action absorbInfrared {
			in item incidentBeam : InfraredBeam;
			in item gasSample : GasSample;
			out item transmittedBeam : InfraredBeam;
		}
	}
	
	part def InfraredPhotodetector {
		port detectionPort : DetectionPort;
		
		attribute responsivity : Real;
		attribute detectorArea : Real;
		attribute noiseLevel : Real;
		
		action detectInfrared {
			in item irBeam : InfraredBeam;
			out item detectorSignal : DetectorSignal;
		}
	}
	
	part def ReferenceDetector {
		port referencePort : DetectionPort;
		
		attribute responsivity : Real;
		
		action measureReference {
			in item referenceBeam : InfraredBeam;
			out item referenceSignal : DetectorSignal;
		}
	}
	
	part def SignalProcessingUnit {
		port measurementSignalInput;
		port referenceSignalInput;
		port dataOutput : DataOutputPort;
		
		attribute calibrationFactor : Real;
		attribute baselineIntensity : IntensityValue;
		attribute conversionCoefficients : Real[4];
		
		action processSignals {
			in item measurementSignal : DetectorSignal;
			in item referenceSignal : DetectorSignal;
			out item measurementData : MeasurementData;
		}
		
		action calculateConcentration {
			in item transmittedIntensity : IntensityValue;
			in item referenceIntensity : IntensityValue;
			out item concentration : ConcentrationValue;
		}
		
		action compensateTemperature {
			in item rawConcentration : ConcentrationValue;
			in item temperature : TemperatureValue;
			out item compensatedConcentration : ConcentrationValue;
		}
	}
	
	part def BeamSplitter {
		port inputPort : OpticalPort;
		port measurementPort : OpticalPort;
		port referencePort : OpticalPort;
		
		attribute splitRatio : Real;
		
		action splitBeam {
			in item inputBeam : InfraredBeam;
			out item measurementBeam : InfraredBeam;
			out item referenceBeam : InfraredBeam;
		}
	}
	
	part def NDIRSensingUnit {
		port gasInput : GasInletPort;
		port gasOutput : GasOutletPort;
		port measurementOutput : DataOutputPort;
		
		part emitter : InfraredEmitter[1] {
			attribute :>> operatingTemperature = 900.0[SI::K];
			attribute :>> emissionWavelength = 4.26e-6[SI::m];
			attribute :>> emissionPower = 0.5[SI::W];
		}
		
		part opticalFilter : OpticalBandpassFilter[1] {
			attribute :>> centerWavelength = 4.26e-6[SI::m];
			attribute :>> bandwidthWavelength = 0.15e-6[SI::m];
			attribute :>> transmittance = 0.85;
		}
		
		part splitter : BeamSplitter[1] {
			attribute :>> splitRatio = 0.9;
		}
		
		part chamber : GasMeasurementChamber[1] {
			attribute :>> pathLength = 0.15[SI::m];
			attribute :>> chamberVolume = 75.0;
			attribute :>> windowTransmittance = 0.95;
		}
		
		part measurementDetector : InfraredPhotodetector[1] {
			attribute :>> responsivity = 1.2;
			attribute :>> detectorArea = 4.0;
			attribute :>> noiseLevel = 0.001;
		}
		
		part referenceDetector : ReferenceDetector[1] {
			attribute :>> responsivity = 1.2;
		}
		
		part processor : SignalProcessingUnit[1] {
			attribute :>> calibrationFactor = 1.05;
			attribute :>> conversionCoefficients = (0.0, 1.0, 0.002, -0.00001);
		}
		
		connection gasFlow : GasFlowConnection
			connect gasInput to chamber.gasInlet;
		
		connection gasExhaust : GasFlowConnection
			connect chamber.gasOutlet to gasOutput;
		
		connection emitterToFilter : OpticalConnection
			connect emitter.emitterPort to opticalFilter.inputPort;
		
		connection filterToSplitter : OpticalConnection
			connect opticalFilter.outputPort to splitter.inputPort;
		
		connection splitterToChamber : OpticalConnection
			connect splitter.measurementPort to chamber.opticalInput;
		
		connection chamberToDetector : OpticalConnection
			connect chamber.opticalOutput to measurementDetector.detectionPort;
		
		connection splitterToReference : OpticalConnection
			connect splitter.referencePort to referenceDetector.referencePort;
		
		flow from measurementDetector.detectionPort to processor.measurementSignalInput;
		flow from referenceDetector.referencePort to processor.referenceSignalInput;
		flow from processor.dataOutput to measurementOutput;
	}
	
	action def InitializeSensor {
		out item ready : Boolean;
	}
	
	action def WarmUpEmitter {
		in item targetTemp : TemperatureValue;
		out item stabilized : Boolean;
	}
	
	action def PerformZeroCalibration {
		in item zeroGas : GasSample;
		out item zeroBaseline : IntensityValue;
	}
	
	action def PerformSpanCalibration {
		in item spanGas : GasSample;
		out item spanFactor : Real;
	}
	
	action def MeasureGasConcentration {
		in item gasSample : GasSample;
		out item measurement : MeasurementData;
		
		action emit {
			out item irBeam : InfraredBeam;
		}
		then action filterIR {
			in item inputBeam : InfraredBeam;
			out item filteredBeam : InfraredBeam;
		}
		then action split {
			in item inputBeam : InfraredBeam;
			out item measurementBeam : InfraredBeam;
			out item referenceBeam : InfraredBeam;
		}
		then fork;
		
		action absorb {
			in item incidentBeam : InfraredBeam;
			in item gas : GasSample;
			out item transmittedBeam : InfraredBeam;
		}
		then action detect {
			in item irBeam : InfraredBeam;
			out item detectorSignal : DetectorSignal;
		}
		then joinNode;
		
		action detectRef {
			in item referenceBeam : InfraredBeam;
			out item referenceSignal : DetectorSignal;
		}
		then joinNode;
		
		flow from emit.irBeam to filterIR.inputBeam;
		flow from filterIR.filteredBeam to split.inputBeam;
		flow from split.measurementBeam to absorb.incidentBeam;
		bind absorb.gas = gasSample;
		flow from absorb.transmittedBeam to detect.irBeam;
		flow from split.referenceBeam to detectRef.referenceBeam;
		
		join joinNode;
		then action process {
			in item measurementSignal : DetectorSignal;
			in item referenceSignal : DetectorSignal;
			out item measurementData : MeasurementData;
		}
		
		flow from detect.detectorSignal to process.measurementSignal;
		flow from detectRef.referenceSignal to process.referenceSignal;
		bind process.measurementData = measurement;
	}
	
	action def ContinuousMonitoring {
		in item gasStream : GasSample;
		out item measurements : MeasurementData[*];
		
		action initialize : InitializeSensor {
			out item ready : Boolean;
		}
		then action warmUp : WarmUpEmitter {
			in item targetTemp : TemperatureValue;
			out item stabilized : Boolean;
		}
		then action zeroCalibrate : PerformZeroCalibration {
			in item zeroGas : GasSample;
			out item zeroBaseline : IntensityValue;
		}
		then action spanCalibrate : PerformSpanCalibration {
			in item spanGas : GasSample;
			out item spanFactor : Real;
		}
		then loop measurementCycle {
			action measure : MeasureGasConcentration {
				in item gasSample : GasSample;
				out item measurement : MeasurementData;
			}
			bind measure.gasSample = gasStream;
		}
	}
	
	state def NDIROperationalStates {
		entry; then powerOff;
		
		state powerOff;
		transition powerOn
			first powerOff
			accept PowerOnSignal
			then initializing;
		
		state initializing {
			entry action init : InitializeSensor;
		}
		transition initComplete
			first initializing
			then warmingUp;
		
		state warmingUp {
			entry action warmup : WarmUpEmitter;
		}
		transition warmupComplete
			first warmingUp
			then calibration;
		
		state calibration {
			entry; then zeroCalibration;
			
			state zeroCalibration {
				entry action zeroCal : PerformZeroCalibration;
			}
			transition zeroToSpan
				first zeroCalibration
				then spanCalibration;
			
			state spanCalibration {
				entry action spanCal : PerformSpanCalibration;
			}
		}
		transition calibrationComplete
			first calibration
			then operational;
		
		state operational {
			entry; then measuring;
			
			state measuring {
				do action measure : MeasureGasConcentration;
			}
			transition continueMeasuring
				first measuring
				then measuring;
		}
		
		transition operationalToMaintenance
			first operational
			accept MaintenanceRequest
			then maintenance;
		
		state maintenance;
		transition maintenanceToCalibration
			first maintenance
			accept RecalibrateCommand
			then calibration;
		
		transition anyToError
			first initializing, warmingUp, calibration, operational
			accept ErrorDetected
			then errorState;
		
		state errorState;
		transition errorReset
			first errorState
			accept ResetCommand
			then powerOff;
		
		transition shutdown
			first operational, maintenance
			accept ShutdownCommand
			then powerOff;
	}
	
	part ndirSensor : NDIRSensingUnit {
		attribute targetGasType : String = "CO2";
		
		perform action monitoring : ContinuousMonitoring;
		exhibit state operatingState : NDIROperationalStates;
	}
	
	requirement def AccuracyRequirement {
		doc /* The NDIR sensing unit shall measure gas concentration with accuracy within ±2% of reading or ±50 ppm, whichever is greater. */
		
		subject sensor : NDIRSensingUnit;
		
		require constraint {
			sensor.processor.dataOutput.data.accuracy <= 0.02
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The NDIR sensing unit shall provide updated measurements within 2 seconds of gas sample change. */
		
		subject sensor : NDIRSensingUnit;
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The NDIR sensing unit shall measure concentrations from 0 to 5000 ppm for CO2. */
		
		subject sensor : NDIRSensingUnit;
	}
	
	requirement def StabilityRequirement {
		doc /* The NDIR sensing unit shall maintain zero drift less than ±20 ppm per week. */
		
		subject sensor : NDIRSensingUnit;
	}
	
	requirement def OperatingTemperatureRequirement {
		doc /* The NDIR sensing unit shall operate within ambient temperature range of -10°C to +50°C. */
		
		subject sensor : NDIRSensingUnit;
	}
	
	requirement ndirSystemRequirements {
		doc /* Top-level requirements for NDIR sensing unit system. */
		
		subject sensor : NDIRSensingUnit;
		
		require accuracyReq : AccuracyRequirement {
			subject redefines sensor;
		}
		
		require responseReq : ResponseTimeRequirement {
			subject redefines sensor;
		}
		
		require rangeReq : MeasurementRangeRequirement {
			subject redefines sensor;
		}
		
		require stabilityReq : StabilityRequirement {
			subject redefines sensor;
		}
		
		require tempReq : OperatingTemperatureRequirement {
			subject redefines sensor;
		}
	}
}
