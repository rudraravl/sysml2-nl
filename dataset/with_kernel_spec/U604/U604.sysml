package AttitudeIndicatorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	public import Definitions::AttitudeIndicator;
	public import Definitions::SystemStates;
	
	package Definitions {
		item def GyroData {
			attribute pitchRate : AngularVelocityValue;
			attribute rollRate : AngularVelocityValue;
		}
		item def AccelData {
			attribute xAccel : AccelerationValue;
			attribute yAccel : AccelerationValue;
			attribute zAccel : AccelerationValue;
		}
		item def AttitudeData {
			attribute pitch : PlaneAngleValue;
			attribute roll : PlaneAngleValue;
		}
		item def PowerStatus {
			attribute voltage : ElectricPotentialValue;
			attribute stable : Boolean;
		}
		
		port def GyroOutPort { out gyroData : GyroData; }
		port def AccelOutPort { out accelData : AccelData; }
		port def AttitudeOutPort { out attitudeData : AttitudeData; }
		port def PowerOutPort { out powerStatus : PowerStatus; }
		port def PowerInPort { in powerStatus : PowerStatus; }
		
		action def SenseAngularRate {
			out pitchRate : AngularVelocityValue;
			out rollRate : AngularVelocityValue;
		}
		action def SenseAcceleration {
			out x : AccelerationValue;
			out y : AccelerationValue;
			out z : AccelerationValue;
		}
		action def FuseSensorData {
			in gyro : GyroData;
			in accel : AccelData;
			out attitude : AttitudeData;
		}
		action def RenderDisplay {
			in attitude : AttitudeData;
		}
		action def RegulatePower {
			in inputVoltage : ElectricPotentialValue;
			out regulatedVoltage : ElectricPotentialValue;
		}
		action def PerformSelfTest {
			out passed : Boolean;
		}
		action def DisplayWarningFlag;
		
		action def NormalOperation {
			action senseAngularRate : SenseAngularRate;
			action senseAcceleration : SenseAcceleration;
			action fuseSensorData : FuseSensorData;
			action renderDisplay : RenderDisplay;
		}
		
		state def SystemStates;
		
		attribute def PowerOn;
		attribute def SelfTestComplete;
		attribute def SensorFailure;
		attribute def SensorRecovered;
		attribute def PowerOff;
		
		part def RateGyroscope {
			doc /* Measures angular velocity for pitch and roll rates. */
			port powerIn : ~PowerOutPort;
			port gyroOut : GyroOutPort;
			attribute pitchRate : AngularVelocityValue;
			attribute rollRate : AngularVelocityValue;
			perform action senseAngularRate : SenseAngularRate;
		}
		
		part def ThreeAxisAccelerometer {
			doc /* Measures linear acceleration to determine gravity direction. */
			port powerIn : ~PowerOutPort;
			port accelOut : AccelOutPort;
			attribute xAccel : AccelerationValue;
			attribute yAccel : AccelerationValue;
			attribute zAccel : AccelerationValue;
			perform action senseAcceleration : SenseAcceleration;
		}
		
		part def AttitudeComputer {
			doc /* Fuses gyroscope and accelerometer data using a complementary filter. */
			port powerIn : ~PowerOutPort;
			port gyroIn : ~GyroOutPort;
			port accelIn : ~AccelOutPort;
			port attitudeOut : AttitudeOutPort;
			attribute pitch : PlaneAngleValue;
			attribute roll : PlaneAngleValue;
			attribute filterCoefficient : Real = 0.98;
			perform action fuseSensorData : FuseSensorData;
		}
		
		part def HorizonDisplay {
			doc /* Presents pitch ladder, roll scale, and horizon line to pilot. */
			port powerIn : ~PowerOutPort;
			port attitudeIn : ~AttitudeOutPort;
			attribute displayPitch : PlaneAngleValue;
			attribute displayRoll : PlaneAngleValue;
			attribute updateRate : FrequencyValue = 60.0;
			perform action renderDisplay : RenderDisplay;
		}
		
		part def PowerManagementUnit {
			doc /* Manages power input, self-test, regulation, and distribution. */
			attribute inputVoltage : ElectricPotentialValue;
			attribute regulatedVoltage : ElectricPotentialValue = 28.0;
			attribute selfTestPassed : Boolean;
			port aircraftPowerIn : PowerInPort;
			port gyroPowerOut : PowerOutPort;
			port accelPowerOut : PowerOutPort;
			port computerPowerOut : PowerOutPort;
			port displayPowerOut : PowerOutPort;
			perform action performSelfTest : PerformSelfTest;
			perform action regulatePower : RegulatePower;
		}
		
		part def AttitudeIndicator {
			doc /* Aircraft Attitude Indicator (artificial horizon) providing real-time pitch and roll. */
			part rateGyroscope : RateGyroscope;
			part threeAxisAccelerometer : ThreeAxisAccelerometer;
			part attitudeComputer : AttitudeComputer;
			part horizonDisplay : HorizonDisplay;
			part powerManagementUnit : PowerManagementUnit;
			
			connect powerManagementUnit.gyroPowerOut to rateGyroscope.powerIn;
			connect powerManagementUnit.accelPowerOut to threeAxisAccelerometer.powerIn;
			connect powerManagementUnit.computerPowerOut to attitudeComputer.powerIn;
			connect powerManagementUnit.displayPowerOut to horizonDisplay.powerIn;
			
			connect rateGyroscope.gyroOut to attitudeComputer.gyroIn;
			connect threeAxisAccelerometer.accelOut to attitudeComputer.accelIn;
			connect attitudeComputer.attitudeOut to horizonDisplay.attitudeIn;
			
			exhibit state systemStates : SystemStates;
			satisfy requirement ProvideRealTimeAttitude;
			satisfy requirement FuseSensorDataAccurately;
			satisfy requirement PowerInputSpecification;
			satisfy requirement DegradedModeHandling;
		}
		
		requirement def ProvideRealTimeAttitude {
			doc /* The system shall provide pilots with a clear, real-time visual representation of aircraft pitch and roll relative to the Earth's horizon. */
			attribute minUpdateRate : FrequencyValue = 30.0;
			attribute pitchAccuracy : PlaneAngleValue = 0.5;
			attribute rollAccuracy : PlaneAngleValue = 0.5;
		}
		requirement def FuseSensorDataAccurately {
			doc /* The attitude computer shall fuse gyroscope and accelerometer data using a complementary filter to calculate accurate pitch and roll angles. */
		}
		requirement def PowerInputSpecification {
			doc /* The system shall operate on a 28V DC input and regulate power to all components. */
			attribute nominalVoltage : ElectricPotentialValue = 28.0;
			attribute minVoltage : ElectricPotentialValue = 20.0;
		}
		requirement def DegradedModeHandling {
			doc /* The system shall enter a degraded mode if a sensor fault is detected and annunciate a warning to the pilot. */
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part attitudeIndicator : AttitudeIndicator;
		
		action 'sense angular rate' : SenseAngularRate;
		action 'sense acceleration' : SenseAcceleration;
		action 'fuse sensor data' : FuseSensorData;
		action 'render display' : RenderDisplay;
		action 'regulate power' : RegulatePower;
		action 'perform self test' : PerformSelfTest;
		action 'display warning flag' : DisplayWarningFlag;
		action 'normal operation' : NormalOperation;
		
		state 'system states' : SystemStates parallel {
			state 'operational states' {
				entry; then off;
				state off;
				accept PowerOn
					then self_test;
				state self_test {
					entry 'perform self test';
				}
				accept SelfTestComplete
					if attitudeIndicator.powerManagementUnit.selfTestPassed
					then normal;
				accept SelfTestComplete
					if not attitudeIndicator.powerManagementUnit.selfTestPassed
					then degraded;
				state normal {
					do 'normal operation';
				}
				accept SensorFailure
					then degraded;
				accept PowerOff
					then off;
				state degraded {
					entry 'display warning flag';
				}
				accept SensorRecovered
					then normal;
				accept PowerOff
					then off;
			}
			state 'power states' {
				entry; then off;
				state off;
				accept PowerOn
					then self_test;
				state self_test {
					do 'regulate power';
				}
				accept SelfTestComplete
					then on;
				state on {
					do 'regulate power';
				}
				accept when attitudeIndicator.powerManagementUnit.inputVoltage < 20.0
					then low_power;
				state low_power {
					do 'regulate power';
				}
				accept when attitudeIndicator.powerManagementUnit.inputVoltage >= 20.0
					then on;
				accept PowerOff
					then off;
			}
		}
	}
}
