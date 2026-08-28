package 'Self-Balancing Transporter' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def PowerOnSignal;
		attribute def SelfTestPassed;
		attribute def SelfTestFailed;
		attribute def RiderDetected;
		attribute def RiderDismounted;
		attribute def LeanForward;
		attribute def LeanBackward;
		attribute def CriticalFault;

		attribute def TiltAngleValue :> Real;
		attribute def TiltRateValue :> Real;
		attribute def LeanAngleValue :> Real;
		attribute def TorqueValue :> Real;
		attribute def VoltageValue :> Real;
		attribute def CurrentValue :> Real;

		port def TiltAnglePort { out tiltAngle : TiltAngleValue; }
		port def TiltRatePort { out tiltRate : TiltRateValue; }
		port def RiderLeanPort { out leanAngle : LeanAngleValue; }
		port def RiderPresencePort { out riderPresent : Boolean; }
		port def TorqueCommandPort { out torque : TorqueValue; }
		port def PowerSupplyPort { out voltage : VoltageValue; out current : CurrentValue; }

		part def BatteryPack {
			port powerOut : PowerSupplyPort;
		}
		part def Gyroscope {
			port tiltRateOut : TiltRatePort;
		}
		part def Accelerometer {
			port tiltAngleOut : TiltAnglePort;
		}
		part def Handlebar {
			port leanOut : RiderLeanPort;
		}
		part def Platform {
			port presenceOut : RiderPresencePort;
		}
		part def BrushlessMotor {
			port torqueIn : TorqueCommandPort;
			port powerIn : PowerSupplyPort;
		}
		part def Wheel;
		part def PlatformFrame;

		action def BalanceLoop {
			in tiltAngle : TiltAngleValue;
			in tiltRate : TiltRateValue;
			in riderLean : LeanAngleValue;
			out leftTorque : TorqueValue;
			out rightTorque : TorqueValue;
		}
		action def SelfTest;
		action def ApplyTorque {
			in torque : TorqueValue;
		}
		action def SafeShutdown;

		action selfTest : SelfTest;
		action balanceLoop : BalanceLoop;
		action safeShutdown : SafeShutdown;

		state def TransporterStates {
			entry; then powerOff;
			state powerOff;
			accept PowerOnSignal then initializing;
			state initializing {
				entry selfTest;
				accept SelfTestPassed then standby;
				accept SelfTestFailed then fault;
			}
			state standby;
			accept RiderDetected then balancing;
			state balancing {
				do balanceLoop;
			}
			accept LeanForward then moving;
			accept LeanBackward then moving;
			accept RiderDismounted then standby;
			accept CriticalFault then fault;
			state moving {
				do balanceLoop;
			}
			accept RiderDismounted then standby;
			accept CriticalFault then fault;
			state fault {
				entry safeShutdown;
			}
		}

		part def BalanceController {
			port tiltAngleIn : TiltAnglePort;
			port tiltRateIn : TiltRatePort;
			port leanIn : RiderLeanPort;
			port torqueOutLeft : TorqueCommandPort;
			port torqueOutRight : TorqueCommandPort;
			port powerIn : PowerSupplyPort;
			exhibit state transporterStates : TransporterStates;
		}

		part def Transporter {
			part platform : Platform;
			part handlebar : Handlebar;
			part leftWheel : Wheel;
			part rightWheel : Wheel;
			part leftMotor : BrushlessMotor;
			part rightMotor : BrushlessMotor;
			part gyro : Gyroscope;
			part accel : Accelerometer;
			part balanceController : BalanceController;
			part battery : BatteryPack;
			part frame : PlatformFrame;

			connect accel.tiltAngleOut to balanceController.tiltAngleIn;
			connect gyro.tiltRateOut to balanceController.tiltRateIn;
			connect handlebar.leanOut to balanceController.leanIn;
			connect balanceController.torqueOutLeft to leftMotor.torqueIn;
			connect balanceController.torqueOutRight to rightMotor.torqueIn;
			connect battery.powerOut to balanceController.powerIn;
			connect battery.powerOut to leftMotor.powerIn;
			connect battery.powerOut to rightMotor.powerIn;
		}
	}

	package Usages {
		private import Definitions::*;

		part transporter : Transporter;

		requirement def DynamicBalanceReq {
			doc /* The transporter shall maintain dynamic balance, keeping the platform level at all times. */
		}
		requirement def RiderLeanPropulsionReq {
			doc /* The transporter shall respond to rider lean by moving in the direction of lean. */
		}
		requirement def SteeringReq {
			doc /* The transporter shall steer by applying differential torque to left and right wheels. */
		}
		requirement def SelfTestReq {
			doc /* The transporter shall perform a self-test routine upon power-on. */
		}
		requirement def FaultHandlingReq {
			doc /* The transporter shall enter a safe fault state upon critical system error. */
		}

		requirement dynamicBalanceReq : DynamicBalanceReq {
			subject transporter = transporter;
		}
		requirement riderLeanPropulsionReq : RiderLeanPropulsionReq {
			subject transporter = transporter;
		}
		requirement steeringReq : SteeringReq {
			subject transporter = transporter;
		}
		requirement selfTestReq : SelfTestReq {
			subject transporter = transporter;
		}
		requirement faultHandlingReq : FaultHandlingReq {
			subject transporter = transporter;
		}

		satisfy dynamicBalanceReq by transporter.balanceController;
		satisfy riderLeanPropulsionReq by transporter.handlebar;
		satisfy steeringReq by transporter.balanceController;
		satisfy selfTestReq by transporter.balanceController;
		satisfy faultHandlingReq by transporter.balanceController;
	}
}
