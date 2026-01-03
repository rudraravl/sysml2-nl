package AnemometerSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WindSpeedValue :> ISQ::SpeedValue;
	attribute def WindDirectionValue :> ISQ::DimensionOneValue;
	attribute def RotationRateValue :> ISQ::AngularVelocityValue;
	attribute def VoltageSignalValue :> ISQ::ElectricPotentialValue;
	
	item def WindMeasurement {
		attribute speed : WindSpeedValue;
		attribute direction : WindDirectionValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def CalibrationParameters {
		attribute speedConversionFactor : Real;
		attribute directionOffset : WindDirectionValue;
	}
	
	port def SensorOutputPort {
		out rotationRate : RotationRateValue;
	}
	
	port def DirectionOutputPort {
		out directionAngle : WindDirectionValue;
	}
	
	port def MeasurementOutputPort {
		out measurement : WindMeasurement;
	}
	
	part def RotatingCups {
		attribute numberOfCups : Integer = 3;
		attribute cupDiameter : ISQ::LengthValue;
		port rotationOutput : SensorOutputPort;
		
		action def CaptureWindForce {
			in windSpeed : WindSpeedValue;
			out rotationSpeed : RotationRateValue;
		}
		
		perform action captureWind : CaptureWindForce;
	}
	
	part def DirectionVane {
		attribute vaneArea : ISQ::AreaValue;
		port angleOutput : DirectionOutputPort;
		
		action def AlignToWind {
			in windDirection : WindDirectionValue;
			out alignedAngle : WindDirectionValue;
		}
		
		perform action alignVane : AlignToWind;
	}
	
	part def RotationSensor {
		port rotationInput {
			in rotationRate : RotationRateValue;
		}
		port signalOutput {
			out speedSignal : VoltageSignalValue;
		}
		
		action def ConvertRotationToSignal {
			in rotation : RotationRateValue;
			out signal : VoltageSignalValue;
		}
		
		perform action convertRotation : ConvertRotationToSignal;
	}
	
	part def AngleSensor {
		port angleInput {
			in directionAngle : WindDirectionValue;
		}
		port signalOutput {
			out directionSignal : VoltageSignalValue;
		}
		
		action def ConvertAngleToSignal {
			in angle : WindDirectionValue;
			out signal : VoltageSignalValue;
		}
		
		perform action convertAngle : ConvertAngleToSignal;
	}
	
	part def DataProcessor {
		attribute calibration : CalibrationParameters;
		port speedSignalInput {
			in speedSignal : VoltageSignalValue;
		}
		port directionSignalInput {
			in directionSignal : VoltageSignalValue;
		}
		port measurementOutput : MeasurementOutputPort;
		
		state def ProcessingStateMachine {
			entry; then idle;
			state idle;
			accept at idle then acquiringData;
			state acquiringData;
			accept at acquiringData then computing;
			state computing;
			accept at computing then outputtingResult;
			state outputtingResult;
			accept at outputtingResult then acquiringData;
		}
		
		action def ComputeWindMeasurement {
			in speedSignal : VoltageSignalValue;
			in directionSignal : VoltageSignalValue;
			in calibrationParams : CalibrationParameters;
			out windMeasurement : WindMeasurement;
		}
		
		perform action computeMeasurement : ComputeWindMeasurement;
	}
	
	requirement def AccuracyRequirement {
		doc /* The anemometer shall measure wind speed with accuracy within ±0.5 m/s for speeds up to 50 m/s. */
		subject anemometer : Anemometer;
		require constraint speedAccuracy {
			doc /* Speed measurement error shall not exceed ±0.5 m/s. */
		}
	}
	
	requirement def DirectionAccuracyRequirement {
		doc /* The anemometer shall measure wind direction with accuracy within ±5 degrees. */
		subject anemometer : Anemometer;
		require constraint directionAccuracy {
			doc /* Direction measurement error shall not exceed ±5 degrees. */
		}
	}
	
	requirement def OperationalRangeRequirement {
		doc /* The anemometer shall operate across specified environmental conditions. */
		subject anemometer : Anemometer;
		require constraint speedRange {
			doc /* Shall measure wind speeds from 0 to 75 m/s. */
		}
		require constraint temperatureRange {
			doc /* Shall operate in temperatures from -40°C to +60°C. */
		}
	}
	
	part def Anemometer {
		doc /* 
			An anemometer system that measures wind speed and direction.
			Primary function: Continuously sense wind conditions by converting
			mechanical rotation and vane alignment into calibrated digital measurements
			of wind speed and direction for meteorological monitoring and analysis.
		*/
		
		attribute systemCalibration : CalibrationParameters;
		port outputPort : MeasurementOutputPort;
		
		part cups : RotatingCups {
			attribute :>> cupDiameter = 0.08 [m];
		}
		
		part vane : DirectionVane {
			attribute :>> vaneArea = 0.02 [m^2];
		}
		
		part speedSensor : RotationSensor;
		part directionSensor : AngleSensor;
		part processor : DataProcessor;
		
		connection cupsToSpeedSensor connect 
			cups.rotationOutput.rotationRate to speedSensor.rotationInput.rotationRate;
		
		connection vaneToDirectionSensor connect 
			vane.angleOutput.directionAngle to directionSensor.angleInput.directionAngle;
		
		connection speedSensorToProcessor connect 
			speedSensor.signalOutput.speedSignal to processor.speedSignalInput.speedSignal;
		
		connection directionSensorToProcessor connect 
			directionSensor.signalOutput.directionSignal to processor.directionSignalInput.directionSignal;
		
		connection processorToOutput connect 
			processor.measurementOutput to outputPort;
		
		perform action measureWindConditions : MeasureWindConditions;
	}
	
	action def MeasureWindConditions {
		doc /* 
			Primary system behavior: Continuously measure wind speed and direction.
			Coordinates the sensing of mechanical motion from wind force,
			conversion to electrical signals, and processing into calibrated
			wind measurements for output.
		*/
		
		first start;
		then merge continuousMeasurement;
		
		then action senseRotation {
			doc /* Capture rotation rate from cup assembly. */
			out cupRotation : RotationRateValue;
		}
		
		then action senseDirection {
			doc /* Capture vane alignment angle. */
			out vaneAngle : WindDirectionValue;
		}
		
		then action convertSpeedSignal {
			doc /* Convert mechanical rotation to electrical signal. */
			in rotation : RotationRateValue = senseRotation.cupRotation;
			out speedVoltage : VoltageSignalValue;
		}
		
		then action convertDirectionSignal {
			doc /* Convert vane angle to electrical signal. */
			in angle : WindDirectionValue = senseDirection.vaneAngle;
			out directionVoltage : VoltageSignalValue;
		}
		
		then action processData {
			doc /* Apply calibration and compute wind measurements. */
			in speedSignal : VoltageSignalValue = convertSpeedSignal.speedVoltage;
			in directionSignal : VoltageSignalValue = convertDirectionSignal.directionVoltage;
			out windSpeed : WindSpeedValue;
			out windDirection : WindDirectionValue;
		}
		
		then action createMeasurement {
			doc /* Assemble complete wind measurement data. */
			in speed : WindSpeedValue = processData.windSpeed;
			in direction : WindDirectionValue = processData.windDirection;
			out measurement : WindMeasurement;
		}
		
		then action outputMeasurement {
			doc /* Transmit measurement to external systems. */
			in data : WindMeasurement = createMeasurement.measurement;
		}
		
		then continuousMeasurement;
	}
	
	part anemometerSystem : Anemometer {
		satisfy accuracyReq : AccuracyRequirement;
		satisfy directionAccuracyReq : DirectionAccuracyRequirement;
		satisfy operationalRangeReq : OperationalRangeRequirement;
	}
}
