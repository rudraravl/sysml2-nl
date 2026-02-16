package 'Triangulation Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import UnitsAndScales::*;
	
	attribute def DistanceValue :> LengthValue;
	
	attribute def AngleValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngleUnit;
	}
	
	attribute def AngleUnit :> MeasurementUnit;
	
	attribute def BaselineValue :> LengthValue;
	
	attribute def IntensityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ScalarMeasurementReference;
	}
	
	item def LaserBeam {
		attribute wavelength : LengthValue;
		attribute power : PowerValue;
	}
	
	item def ReflectedLight {
		attribute intensity : IntensityValue;
		attribute position : LengthValue;
	}
	
	port def PowerPort {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
	}
	
	port def DataPort {
		out distance : DistanceValue;
		out valid : Boolean;
	}
	
	port def ControlPort {
		in trigger : Boolean;
		out status : String;
	}
	
	connection def PowerConnection {
		end [1] port source : PowerPort;
		end [1] port sink : PowerPort;
	}
	
	connection def DataConnection {
		end [1] port output : DataPort;
		end [1] port input : DataPort;
	}
	
	action def EmitLaserBeam {
		in power : PowerValue;
		out beam : LaserBeam;
	}
	
	action def DetectReflection {
		in beam : LaserBeam;
		out leftReflection : ReflectedLight;
		out rightReflection : ReflectedLight;
	}
	
	action def MeasureAngles {
		in leftReflection : ReflectedLight;
		in rightReflection : ReflectedLight;
		in baseline : BaselineValue;
		out leftAngle : AngleValue;
		out rightAngle : AngleValue;
	}
	
	action def ComputeDistance {
		in leftAngle : AngleValue;
		in rightAngle : AngleValue;
		in baseline : BaselineValue;
		out distance : DistanceValue;
	}
	
	action def ValidateReading {
		in distance : DistanceValue;
		in leftAngle : AngleValue;
		in rightAngle : AngleValue;
		out validDistance : DistanceValue;
		out isValid : Boolean;
	}
	
	action def TriangulationMeasurement {
		in baseline : BaselineValue;
		in sourcePower : PowerValue;
		out measuredDistance : DistanceValue;
		out measurementValid : Boolean;
		
		action emit : EmitLaserBeam {
			in power;
			out beam;
		}
		bind emit.power = sourcePower;
		
		then action detect : DetectReflection {
			in beam;
			out leftReflection;
			out rightReflection;
		}
		flow from emit.beam to detect.beam;
		
		then action measure : MeasureAngles {
			in leftReflection;
			in rightReflection;
			in baseline;
			out leftAngle;
			out rightAngle;
		}
		flow from detect.leftReflection to measure.leftReflection;
		flow from detect.rightReflection to measure.rightReflection;
		bind measure.baseline = baseline;
		
		then action compute : ComputeDistance {
			in leftAngle;
			in rightAngle;
			in baseline;
			out distance;
		}
		flow from measure.leftAngle to compute.leftAngle;
		flow from measure.rightAngle to compute.rightAngle;
		bind compute.baseline = baseline;
		
		then action validate : ValidateReading {
			in distance;
			in leftAngle;
			in rightAngle;
			out validDistance;
			out isValid;
		}
		flow from compute.distance to validate.distance;
		flow from measure.leftAngle to validate.leftAngle;
		flow from measure.rightAngle to validate.rightAngle;
		
		bind validate.validDistance = measuredDistance;
		bind validate.isValid = measurementValid;
	}
	
	part def LaserSource {
		attribute emissionWavelength : LengthValue;
		attribute maxPower : PowerValue;
		port powerIn : PowerPort;
		port beamOut {
			out beam : LaserBeam;
		}
		perform action emitBeam : EmitLaserBeam;
	}
	
	part def PhotoDetector {
		attribute sensitivity : Real;
		attribute detectionArea : AreaValue;
		port lightIn {
			in beam : LaserBeam;
		}
		port signalOut {
			out reflection : ReflectedLight;
		}
	}
	
	part def AngleCalculator {
		attribute resolution : AngleValue;
		port reflectionInputs {
			in leftReflection : ReflectedLight;
			in rightReflection : ReflectedLight;
		}
		port angleOutputs {
			out leftAngle : AngleValue;
			out rightAngle : AngleValue;
		}
		perform action calculateAngles : MeasureAngles;
	}
	
	part def ProcessingUnit {
		attribute computationRate : FrequencyValue;
		port angleInputs {
			in leftAngle : AngleValue;
			in rightAngle : AngleValue;
		}
		port distanceOutput {
			out distance : DistanceValue;
			out valid : Boolean;
		}
		perform action processData : ComputeDistance;
		perform action validateData : ValidateReading;
	}
	
	part def TriangulationSensor {
		attribute baselineLength : BaselineValue;
		attribute minRange : DistanceValue;
		attribute maxRange : DistanceValue;
		attribute accuracy : DistanceValue;
		
		port powerSupply : PowerPort;
		port dataOutput : DataPort;
		port control : ControlPort;
		
		part laser : LaserSource[1] {
			attribute :>> emissionWavelength = 650.0e-9[m];
			attribute :>> maxPower = 0.05[W];
		}
		
		part leftDetector : PhotoDetector[1] {
			attribute :>> sensitivity = 0.9;
		}
		
		part rightDetector : PhotoDetector[1] {
			attribute :>> sensitivity = 0.9;
		}
		
		part angleCalc : AngleCalculator[1];
		
		part processor : ProcessingUnit[1] {
			attribute :>> computationRate = 100.0[Hz];
		}
		
		connect laser.beamOut to leftDetector.lightIn;
		connect laser.beamOut to rightDetector.lightIn;
		connect leftDetector.signalOut to angleCalc.reflectionInputs;
		connect rightDetector.signalOut to angleCalc.reflectionInputs;
		connect angleCalc.angleOutputs to processor.angleInputs;
		connect processor.distanceOutput to dataOutput;
		
		perform action measure : TriangulationMeasurement {
			bind measure.baseline = baselineLength;
			bind measure.sourcePower = laser.maxPower;
		}
	}
	
	part def SensingUnit {
		attribute operatingVoltage : ElectricPotentialValue;
		attribute powerConsumption : PowerValue;
		attribute updateRate : FrequencyValue;
		
		port mainPower : PowerPort;
		port measurementOutput : DataPort;
		port systemControl : ControlPort;
		
		part sensor : TriangulationSensor[1] {
			attribute :>> baselineLength = 0.12[m];
			attribute :>> minRange = 0.1[m];
			attribute :>> maxRange = 10.0[m];
			attribute :>> accuracy = 0.001[m];
		}
		
		connect sensor.powerSupply to mainPower;
		connect sensor.dataOutput to measurementOutput;
		connect sensor.control to systemControl;
	}
	
	requirement def TriangulationMethodRequirement {
		doc /* The sensing unit shall measure distance using optical triangulation with dual photodetectors. */
		subject unit : SensingUnit;
		require constraint {
			unit.sensor.leftDetector->size() == 1 and
			unit.sensor.rightDetector->size() == 1
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure distances from 0.1m to 10m. */
		subject unit : SensingUnit;
		attribute minDist : DistanceValue;
		attribute maxDist : DistanceValue;
		require constraint {
			unit.sensor.minRange == minDist and
			unit.sensor.maxRange == maxDist
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The sensing unit shall achieve measurement accuracy of 1mm or better. */
		subject unit : SensingUnit;
		attribute maxError : DistanceValue;
		require constraint {
			unit.sensor.accuracy <= maxError
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> operatingVoltage = 5.0[V];
		attribute :>> powerConsumption = 2.0[W];
		attribute :>> updateRate = 50.0[Hz];
		
		satisfy reqTriangulation : TriangulationMethodRequirement {
			subject :>> unit = sensingUnitInstance;
		}
		
		satisfy reqRange : MeasurementRangeRequirement {
			subject :>> unit = sensingUnitInstance;
			attribute :>> minDist = 0.1[m];
			attribute :>> maxDist = 10.0[m];
		}
		
		satisfy reqAccuracy : AccuracyRequirement {
			subject :>> unit = sensingUnitInstance;
			attribute :>> maxError = 0.001[m];
		}
	}
	
	part def PowerSupply {
		attribute outputVoltage : ElectricPotentialValue;
		attribute maxCurrent : ElectricCurrentValue;
		port powerOut : PowerPort;
	}
	
	part def DataAcquisitionSystem {
		port dataIn : DataPort;
		port controlOut : ControlPort;
	}
	
	part systemConfiguration {
		part supply : PowerSupply[1] {
			attribute :>> outputVoltage = 5.0[V];
			attribute :>> maxCurrent = 1.0[A];
		}
		
		part unit : SensingUnit[1] :> sensingUnitInstance;
		
		part dataSystem : DataAcquisitionSystem[1];
		
		connection : PowerConnection
			connect source references supply.powerOut
			to sink references unit.mainPower;
		
		connection : DataConnection
			connect output references unit.measurementOutput
			to input references dataSystem.dataIn;
	}
	
	individual def TestUnit :> SensingUnit;
	individual testUnit : TestUnit :> sensingUnitInstance {
		timeslice measurement1 {
			attribute :>> sensor.baselineLength = 0.12[m];
		}
		then timeslice measurement2 {
			attribute :>> sensor.baselineLength = 0.12[m];
		}
	}
}
