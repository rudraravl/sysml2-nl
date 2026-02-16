package SpeedometerSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RotationalFrequency :> Real;
	
	item def WheelRotationSignal {
		attribute frequency : RotationalFrequency;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def SpeedData {
		attribute speedValue : ISQ::SpeedValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def DisplayCommand {
		attribute speed : ISQ::SpeedValue;
		attribute units : SpeedUnitType;
	}
	
	enum def SpeedUnitType {
		enum kilometersPerHour;
		enum milesPerHour;
	}
	
	port def WheelSensorPort {
		out item rotationSignal : WheelRotationSignal;
	}
	
	port def ProcessorInputPort {
		in item rotationSignal : WheelRotationSignal;
	}
	
	port def ProcessorOutputPort {
		out item speedData : SpeedData;
	}
	
	port def DisplayInputPort {
		in item displayCmd : DisplayCommand;
	}
	
	action def SenseWheelRotation {
		out rotationFreq : RotationalFrequency;
		out signal : WheelRotationSignal;
	}
	
	action def CalculateSpeed {
		in rotationSignal : WheelRotationSignal;
		in wheelRadius : ISQ::LengthValue;
		out calculatedSpeed : SpeedData;
	}
	
	action def RenderSpeed {
		in speedCmd : DisplayCommand;
	}
	
	part def WheelSpeedSensor {
		attribute wheelCircumference : ISQ::LengthValue;
		port sensorOutput : WheelSensorPort;
		
		perform action continuousSensing : SenseWheelRotation[*] ordered;
	}
	
	part def SpeedCalculationProcessor {
		attribute wheelRadius : ISQ::LengthValue;
		port processorInput : ProcessorInputPort;
		port processorOutput : ProcessorOutputPort;
		
		perform action processingLoop : CalculateSpeed[*] ordered;
	}
	
	part def SpeedDisplayUnit {
		attribute displayMode : SpeedUnitType;
		attribute brightness : Real;
		port displayInput : DisplayInputPort;
		
		state def DisplayStateMachine {
			entry; then off;
			
			state off;
			transition powerOn
				first off
				then on;
			
			state on {
				entry action initializeDisplay;
				
				state idle;
				state updating {
					entry action refreshDisplay;
				}
				
				transition startUpdate
					first idle
					then updating;
				
				transition finishUpdate
					first updating
					then idle;
			}
			
			transition powerOff
				first on
				then off;
		}
		
		perform action renderingLoop : RenderSpeed[*] ordered;
	}
	
	part def Speedometer {
		doc /* 
		 * The Speedometer system measures vehicle speed by sensing wheel rotation,
		 * converting rotational frequency to linear speed, and displaying the result
		 * to the driver in real-time.
		 */
		
		part wheelSensor : WheelSpeedSensor {
			:>> wheelCircumference = 2.0[m];
		}
		
		part processor : SpeedCalculationProcessor {
			:>> wheelRadius = 0.32[m];
		}
		
		part display : SpeedDisplayUnit {
			:>> displayMode = SpeedUnitType::kilometersPerHour;
			:>> brightness = 0.75;
		}
		
		connection sensorToProcessor connect 
			wheelSensor.sensorOutput to processor.processorInput;
		
		action def MeasureAndDisplaySpeed {
			first start;
			then merge continueMeasurement;
			
			then action acquireRotation : SenseWheelRotation {
				out rotationFreq;
				out signal;
			}
			
			then action calculateSpeed : CalculateSpeed {
				in rotationSignal = acquireRotation.signal;
				in wheelRadius = processor.wheelRadius;
				out calculatedSpeed;
			}
			
			then action prepareDisplayCommand {
				in speedData : SpeedData = calculateSpeed.calculatedSpeed;
				out cmd : DisplayCommand;
			}
			
			then action renderToDisplay : RenderSpeed {
				in speedCmd = prepareDisplayCommand.cmd;
			}
			
			then continueMeasurement;
		}
		
		perform action mainOperation : MeasureAndDisplaySpeed;
	}
	
	requirement def SpeedMeasurementAccuracy {
		doc /* 
		 * The speedometer shall measure vehicle speed with an accuracy of +/- 2% 
		 * or +/- 1 km/h, whichever is greater, across the operating range of 
		 * 0 to 250 km/h.
		 */
		
		subject speedometer : Speedometer;
		
		require constraint accuracyBound {
			attribute measuredSpeed : ISQ::SpeedValue;
			attribute actualSpeed : ISQ::SpeedValue;
			attribute error : ISQ::SpeedValue = measuredSpeed - actualSpeed;
			attribute percentError : Real = (error / actualSpeed) * 100.0;
			
			(percentError >= -2.0 and percentError <= 2.0) or
			(error >= -1.0[km/h] and error <= 1.0[km/h])
		}
	}
	
	requirement def DisplayUpdateRate {
		doc /* 
		 * The speedometer display shall update at a minimum rate of 5 Hz to 
		 * provide smooth, real-time feedback to the driver.
		 */
		
		subject display : SpeedDisplayUnit;
		
		require constraint updateFrequency {
			attribute refreshRate : Real;
			refreshRate >= 5.0;
		}
	}
	
	requirement def ResponseTime {
		doc /* 
		 * The speedometer shall reflect changes in vehicle speed within 
		 * 150 milliseconds from the time of actual speed change.
		 */
		
		subject speedometer : Speedometer;
		
		require constraint responseDelay {
			attribute responseTime : ISQ::TimeValue;
			responseTime <= 0.15[s];
		}
	}
	
	requirement speedometerSystemRequirement {
		doc /* 
		 * The Speedometer system shall continuously measure the vehicle's speed 
		 * by monitoring wheel rotation and present this information to the driver 
		 * through a visual display in real-time with high accuracy and responsiveness.
		 */
		
		subject vehicleSpeedometer : Speedometer;
		
		assume constraint operatingEnvironment {
			attribute temperature : ISQ::TemperatureValue;
			attribute voltage : Real;
			
			temperature >= 233.15[K] and temperature <= 358.15[K] and
			voltage >= 10.0 and voltage <= 16.0;
		}
	}
	
	part vehicleSpeedometerSystem : Speedometer;
}
