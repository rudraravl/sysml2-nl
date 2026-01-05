package OpticalPositionSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	private import ISQSpaceTime::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	attribute def PositionValue :> VectorQuantityValue {
		attribute :>> num : Real[3];
		attribute :>> mRef : LengthUnit;
	}
	
	attribute def IntensityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : LuminousIntensityUnit;
	}
	
	attribute def FrequencyValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : FrequencyUnit;
	}
	
	attribute def FrequencyUnit :> DerivedUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[1] {
			[0] { attribute :>> unit = TimeUnit; attribute :>> exponent = -1; }
		}
	}
	
	item def OpticalBeam {
		attribute wavelength : LengthValue;
		attribute intensity : IntensityValue;
	}
	
	item def ReflectedBeam :> OpticalBeam {
		attribute reflectionAngle : Real;
	}
	
	item def PositionMeasurement {
		attribute position : PositionValue;
		attribute timestamp : TimeValue;
		attribute isValid : Boolean;
		attribute confidence : Real;
	}
	
	item def Target {
		attribute actualPosition : PositionValue;
		attribute reflectivity : Real;
	}
	
	port def OpticalEmitterPort {
		out item emittedBeam : OpticalBeam;
	}
	
	port def OpticalReceiverPort {
		in item receivedBeam : ReflectedBeam;
	}
	
	port def DataOutputPort {
		out item measurement : PositionMeasurement;
	}
	
	port def PowerSupplyPort {
		in attribute voltage : ElectricPotentialValue;
		in attribute current : ElectricCurrentValue;
	}
	
	part def LaserEmitter {
		port emitterPort : OpticalEmitterPort;
		attribute emissionWavelength : LengthValue;
		attribute outputPower : PowerValue;
	}
	
	part def PhotodetectorArray {
		port receiverPort : OpticalReceiverPort;
		attribute pixelCount : Integer;
		attribute sensitivity : IntensityValue;
		out attribute detectedIntensities : IntensityValue[*];
	}
	
	part def PositionCalculator {
		in attribute intensityData : IntensityValue[*];
		out item calculatedPosition : PositionMeasurement;
		attribute algorithmType : String;
		attribute processingRate : FrequencyValue;
	}
	
	part def OpticalPositionSensor {
		port opticalOutput : OpticalEmitterPort;
		port opticalInput : OpticalReceiverPort;
		port dataOutput : DataOutputPort;
		port powerInput : PowerSupplyPort;
		
		attribute measurementRange : LengthValue;
		attribute resolution : LengthValue;
		attribute updateRate : FrequencyValue;
		
		part emitter : LaserEmitter[1] {
			attribute :>> emissionWavelength = 650.0[nm];
			attribute :>> outputPower = 0.01[W];
		}
		
		part detector : PhotodetectorArray[1] {
			attribute :>> pixelCount = 2048;
			attribute :>> sensitivity = 0.1[cd];
		}
		
		part calculator : PositionCalculator[1] {
			attribute :>> algorithmType = "Centroid";
			attribute :>> processingRate = 2000.0[Hz];
		}
		
		part housing : SensorHousing[1];
		
		connection emitterToOutput 
			connect emitter.emitterPort to opticalOutput;
		
		connection inputToDetector 
			connect opticalInput to detector.receiverPort;
		
		connection detectorToCalculator 
			connect detector.detectedIntensities to calculator.intensityData;
		
		connection calculatorToOutput 
			connect calculator.calculatedPosition to dataOutput.measurement;
	}
	
	part def SensorHousing {
		part opticalWindow : OpticalWindow[1];
		part enclosure : Enclosure[1];
		part mountingInterface : MountingInterface[1];
	}
	
	part def OpticalWindow {
		attribute transmittance : Real;
		attribute material : String;
		attribute thickness : LengthValue;
	}
	
	part def Enclosure {
		attribute protectionRating : String;
		attribute material : String;
	}
	
	part def MountingInterface {
		part mountingHoles : MountingHole[4];
	}
	
	part def MountingHole {
		attribute diameter : LengthValue;
		attribute threadType : String;
	}
	
	action def EmitOpticalBeam {
		out item beam : OpticalBeam;
	}
	
	action def DetectReflection {
		in item reflectedBeam : ReflectedBeam;
		out attribute intensityPattern : IntensityValue[*];
	}
	
	action def ComputePosition {
		in attribute intensityData : IntensityValue[*];
		out item positionResult : PositionMeasurement;
	}
	
	action def ValidateReading {
		in item rawMeasurement : PositionMeasurement;
		out item validatedMeasurement : PositionMeasurement;
	}
	
	action def PerformPositionMeasurement {
		in ref item targetObject : Target;
		out item finalMeasurement : PositionMeasurement;
		
		action emitBeam : EmitOpticalBeam {
			out item outgoingBeam;
		}
		
		then detectReflection;
		
		item reflectedBeam : ReflectedBeam;
		
		action detectReflection : DetectReflection {
			in item reflectedBeam;
			out attribute intensityPattern;
		}
		
		then computePosition;
		
		flow from detectReflection.intensityPattern to computePosition.intensityData;
		
		action computePosition : ComputePosition {
			in attribute intensityData;
			out item positionResult;
		}
		
		then validateReading;
		
		flow from computePosition.positionResult to validateReading.rawMeasurement;
		
		action validateReading : ValidateReading {
			in item rawMeasurement;
			out item validatedMeasurement;
		}
		
		bind validateReading.validatedMeasurement = finalMeasurement;
	}
	
	state def SensorOperationalStates {
		entry; then powerUp;
		
		state powerUp;
		
		accept InitializationComplete then idle;
		
		state idle;
		
		accept StartMeasurement then measuring;
		accept CalibrationRequest then calibrating;
		
		state measuring {
			do action continuousMeasure : PerformPositionMeasurement;
		}
		
		accept StopMeasurement then idle;
		accept ErrorOccurred then fault;
		
		state calibrating;
		
		accept CalibrationComplete then idle;
		
		state fault;
		
		accept Reset then powerUp;
	}
	
	part def SensingUnit {
		port measurementOutput : DataOutputPort;
		port power : PowerSupplyPort;
		
		in ref item target : Target;
		out item currentMeasurement : PositionMeasurement;
		
		part sensor : OpticalPositionSensor[1] {
			attribute :>> measurementRange = 2000.0[mm];
			attribute :>> resolution = 0.05[mm];
			attribute :>> updateRate = 1000.0[Hz];
		}
		
		connection sensorOutput 
			connect sensor.dataOutput to measurementOutput;
		
		connection sensorPower 
			connect power to sensor.powerInput;
		
		perform action measure : PerformPositionMeasurement {
			in ref item :>> targetObject = target;
			out item :>> finalMeasurement = currentMeasurement;
		}
		
		exhibit state operationState : SensorOperationalStates;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The optical position sensor shall measure position with an accuracy 
		     better than 0.1mm over the entire measurement range. */
		
		subject sensor : OpticalPositionSensor;
		
		require constraint {
			sensor.resolution <= 0.1[mm]
		}
	}
	
	requirement def UpdateRateRequirement {
		doc /* The sensing unit shall provide position measurements at a minimum 
		     rate of 500 Hz to support real-time control applications. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.updateRate >= 500.0[Hz]
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The optical position sensor shall measure positions within a range 
		     of at least 1000mm to cover the operational workspace. */
		
		subject sensor : OpticalPositionSensor;
		
		require constraint {
			sensor.measurementRange >= 1000.0[mm]
		}
	}
	
	requirement def PowerConsumptionRequirement {
		doc /* The sensing unit shall operate with a supply voltage between 12V and 24V 
		     and consume no more than 2A of current. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.power.voltage >= 12.0[V] and 
			unit.power.voltage <= 24.0[V] and 
			unit.power.current <= 2.0[A]
		}
	}
	
	part verifiedSensingUnit : SensingUnit {
		attribute :>> sensor.measurementRange = 2000.0[mm];
		attribute :>> sensor.resolution = 0.05[mm];
		attribute :>> sensor.updateRate = 1000.0[Hz];
		
		satisfy accuracyReq : MeasurementAccuracyRequirement by verifiedSensingUnit.sensor;
		satisfy rateReq : UpdateRateRequirement by verifiedSensingUnit;
		satisfy rangeReq : MeasurementRangeRequirement by verifiedSensingUnit.sensor;
		satisfy powerReq : PowerConsumptionRequirement by verifiedSensingUnit;
	}
}
