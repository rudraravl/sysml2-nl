package 'Holographic Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	attribute def HolographicResolution :> ISQ::LengthValue;
	
	attribute def LaserWavelength :> ISQ::LengthValue;
	
	attribute def InterferenceIntensity :> ISQ::LuminousIntensityValue;
	
	attribute def PhaseShift :> Real;
	
	enum def SensorState {
		enum Idle;
		enum Initializing;
		enum Capturing;
		enum Processing;
		enum Ready;
		enum Fault;
	}
	
	item def OpticalWavefront {
		attribute wavelength : LaserWavelength;
		attribute intensity : ISQ::LuminousIntensityValue;
		attribute phaseDistribution : PhaseShift[*];
	}
	
	item def InterferencePattern {
		attribute fringeSpacing : ISQ::LengthValue;
		attribute contrastRatio : Real;
		attribute intensityDistribution : InterferenceIntensity[*];
	}
	
	item def HolographicRecord {
		attribute recordedPattern : InterferencePattern;
		attribute timestamp : TimeInstantValue;
		attribute resolution : HolographicResolution;
	}
	
	item def ReconstructedData {
		attribute measuredQuantity : Real;
		attribute spatialDistribution : Real[*];
		attribute measurementQuality : Real;
	}
	
	port def OpticalInputPort {
		in item objectWave : OpticalWavefront;
	}
	
	port def OpticalOutputPort {
		out item referenceWave : OpticalWavefront;
	}
	
	port def DataOutputPort {
		out item holographicData : HolographicRecord;
		out item reconstructedData : ReconstructedData;
	}
	
	port def PowerPort {
		in attribute voltage : ISQ::ElectricPotentialValue;
		in attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def ControlPort {
		in attribute captureCommand : Boolean;
		in attribute resetCommand : Boolean;
		out attribute status : SensorState;
	}
	
	connection def OpticalCoupling {
		end source : OpticalOutputPort[1];
		end target : OpticalInputPort[1];
	}
	
	action def GenerateReferenceBeam {
		in laserPower : ISQ::PowerValue;
		in wavelength : LaserWavelength;
		out referenceBeam : OpticalWavefront;
	}
	
	action def SplitBeam {
		in inputBeam : OpticalWavefront;
		out referenceBeam : OpticalWavefront;
		out objectBeam : OpticalWavefront;
	}
	
	action def IlluminateObject {
		in objectBeam : OpticalWavefront;
		out reflectedWave : OpticalWavefront;
	}
	
	action def CreateInterference {
		in referenceWave : OpticalWavefront;
		in objectWave : OpticalWavefront;
		out interferencePattern : InterferencePattern;
	}
	
	action def RecordHologram {
		in interferencePattern : InterferencePattern;
		out holographicRecord : HolographicRecord;
	}
	
	action def ReconstructWavefront {
		in holographicRecord : HolographicRecord;
		in reconstructionBeam : OpticalWavefront;
		out reconstructedData : ReconstructedData;
	}
	
	part def CoherentLaserSource {
		attribute wavelength : LaserWavelength;
		attribute outputPower : ISQ::PowerValue;
		attribute coherenceLength : ISQ::LengthValue;
		
		port powerIn : PowerPort;
		port beamOut : OpticalOutputPort;
		
		action emitBeam : GenerateReferenceBeam {
			in laserPower = outputPower;
			in wavelength = CoherentLaserSource::wavelength;
			out referenceBeam;
		}
	}
	
	part def OpticalBeamSplitter {
		attribute splitRatio : Real;
		
		port inputPort : OpticalInputPort;
		port referencePort : OpticalOutputPort;
		port objectPort : OpticalOutputPort;
		
		action split : SplitBeam {
			in inputBeam;
			out referenceBeam;
			out objectBeam;
		}
	}
	
	part def ObjectIlluminator {
		port objectBeamIn : OpticalInputPort;
		port reflectedBeamOut : OpticalOutputPort;
		
		action illuminate : IlluminateObject {
			in objectBeam;
			out reflectedWave;
		}
	}
	
	part def InterferenceDetector {
		attribute detectorSize : ISQ::LengthValue[2];
		attribute pixelCount : Integer[2];
		attribute sensitivity : Real;
		
		port referenceIn : OpticalInputPort;
		port objectIn : OpticalInputPort;
		
		action detectInterference : CreateInterference {
			in referenceWave;
			in objectWave;
			out interferencePattern;
		}
	}
	
	part def HolographicRecorder {
		attribute recordingMedium : String;
		attribute exposureTime : ISQ::DurationValue;
		
		action record : RecordHologram {
			in interferencePattern;
			out holographicRecord;
		}
	}
	
	part def SignalProcessor {
		attribute processingRate : ISQ::FrequencyValue;
		attribute algorithmType : String;
		
		action process : ReconstructWavefront {
			in holographicRecord;
			in reconstructionBeam;
			out reconstructedData;
		}
	}
	
	part def HolographicSensor {
		attribute sensorID : String;
		attribute operatingWavelength : LaserWavelength;
		attribute measurementRange : ISQ::LengthValue;
		attribute currentState : SensorState default SensorState::Idle;
		
		port powerSupply : PowerPort;
		port control : ControlPort;
		port dataOut : DataOutputPort;
		
		part laser : CoherentLaserSource {
			attribute :>> wavelength = operatingWavelength;
			attribute :>> outputPower = 100.0[SI::W] * 0.001;
			attribute :>> coherenceLength = 1.0[SI::m];
		}
		
		part beamSplitter : OpticalBeamSplitter {
			attribute :>> splitRatio = 0.5;
		}
		
		part illuminator : ObjectIlluminator;
		
		part detector : InterferenceDetector {
			attribute :>> detectorSize = (25.0[SI::mm], 25.0[SI::mm]);
			attribute :>> pixelCount = (2048, 2048);
			attribute :>> sensitivity = 0.92;
		}
		
		part recorder : HolographicRecorder {
			attribute :>> recordingMedium = "Digital CCD";
			attribute :>> exposureTime = 10.0[SI::s] * 0.001;
		}
		
		part processor : SignalProcessor {
			attribute :>> processingRate = 200.0[SI::Hz] * 1000000.0;
			attribute :>> algorithmType = "Fourier Transform";
		}
		
		connect laser.powerIn to powerSupply;
		connection : OpticalCoupling connect laser.beamOut to beamSplitter.inputPort;
		connection : OpticalCoupling connect beamSplitter.objectPort to illuminator.objectBeamIn;
		connection : OpticalCoupling connect beamSplitter.referencePort to detector.referenceIn;
		connection : OpticalCoupling connect illuminator.reflectedBeamOut to detector.objectIn;
		
		action performCapture {
			action generateBeam : GenerateReferenceBeam;
			then action splitBeams : SplitBeam {
				perform beamSplitter.split;
			}
			then fork;
			
			then action illuminateTarget : IlluminateObject {
				perform illuminator.illuminate;
			}
			then joinNode;
			
			then action detectPattern : CreateInterference {
				perform detector.detectInterference;
			}
			then joinNode;
			
			join joinNode;
			then action recordPattern : RecordHologram {
				perform recorder.record;
			}
		}
	}
	
	part def SensingUnit {
		attribute unitID : String;
		attribute measurementType : String;
		attribute accuracyTarget : Real;
		
		port powerInput : PowerPort;
		port controlInterface : ControlPort;
		port measurementOutput : DataOutputPort;
		
		part holographicSensor : HolographicSensor {
			attribute :>> sensorID = "HOLO-SU-001";
			attribute :>> operatingWavelength = 632.8[SI::nm];
			attribute :>> measurementRange = 5.0[SI::m];
		}
		
		connect powerInput to holographicSensor.powerSupply;
		connect controlInterface to holographicSensor.control;
		connect holographicSensor.dataOut to measurementOutput;
		
		action performMeasurement {
			out measurement : ReconstructedData;
			
			action initiate;
			then action waitForCapture;
			then action retrieveData {
				out data : ReconstructedData;
			}
			
			bind retrieveData.data = measurement;
		}
	}
	
	requirement def HolographicMeasurementRequirement {
		doc /* The sensing unit shall measure the relevant quantity using a holographic sensor with specified accuracy and resolution. */
		
		subject unit : SensingUnit;
		
		attribute requiredAccuracy : Real;
		attribute requiredResolution : HolographicResolution;
		attribute requiredWavelength : LaserWavelength;
		
		require constraint accuracyConstraint {
			unit.accuracyTarget >= requiredAccuracy
		}
		
		require constraint wavelengthConstraint {
			unit.holographicSensor.operatingWavelength == requiredWavelength
		}
	}
	
	requirement holographicSensingReq : HolographicMeasurementRequirement {
		attribute :>> requiredAccuracy = 0.95;
		attribute :>> requiredResolution = 1.0[SI::um];
		attribute :>> requiredWavelength = 632.8[SI::nm];
		
		subject sensingUnit : SensingUnit;
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitID = "HSU-2024-001";
		attribute :>> measurementType = "Holographic Interferometry";
		attribute :>> accuracyTarget = 0.97;
		
		part :>> holographicSensor {
			attribute :>> operatingWavelength = 632.8[SI::nm];
			
			part :>> laser {
				attribute :>> outputPower = 150.0[SI::W] * 0.001;
				attribute :>> coherenceLength = 2.0[SI::m];
			}
			
			part :>> detector {
				attribute :>> detectorSize = (50.0[SI::mm], 50.0[SI::mm]);
				attribute :>> pixelCount = (4096, 4096);
				attribute :>> sensitivity = 0.95;
			}
			
			part :>> processor {
				attribute :>> processingRate = 500.0[SI::Hz] * 1000000.0;
			}
		}
		
		satisfy holographicSensingReq by sensingUnitInstance;
	}
	
	individual def TestMeasurement :> ReconstructedData;
	
	individual testScenario : SensingUnit :> sensingUnitInstance {
		timeslice measurement1 {
			perform action :>> performMeasurement {
				out measurement : TestMeasurement {
					:>> measuredQuantity = 42.5;
					:>> measurementQuality = 0.96;
				}
			}
		}
		
		then timeslice measurement2 {
			perform action :>> performMeasurement {
				out measurement : TestMeasurement {
					:>> measuredQuantity = 38.2;
					:>> measurementQuality = 0.94;
				}
			}
		}
	}
}
