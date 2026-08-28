package 'HCNG Fueling Station Dispenser' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def Hydrogen;
		item def CNG;
		item def HCNGBlend;
		item def VentGas;

		attribute def UserStartSignal;
		attribute def AuthSuccessSignal;
		attribute def AuthFailSignal;
		attribute def SafetyCheckPassSignal;
		attribute def SafetyCheckFailSignal;
		attribute def TankFullSignal;
		attribute def TransactionCompleteSignal;
		attribute def ResetSignal;
		attribute def AnomalySignal;

		attribute def PaymentInfo {
			attribute cardId : String;
			attribute amount : Real;
		}
		attribute def BlendSelection {
			attribute hydrogenContent : Real;
		}
		attribute def AuthResult {
			attribute authenticated : Boolean;
		}
		attribute def NozzleStatus {
			attribute connected : Boolean;
			attribute locked : Boolean;
		}
		attribute def PressureReading {
			attribute value : PressureValue;
		}
		attribute def TemperatureReading {
			attribute value : TemperatureValue;
		}
		attribute def FlowReading {
			attribute value : VolumeFlowRateValue;
		}
		attribute def LeakAlert {
			attribute leakDetected : Boolean;
		}
		attribute def BlendCommand {
			attribute hydrogenFraction : Real;
			attribute cngFraction : Real;
		}
		attribute def FuelCommand {
			attribute targetPressure : PressureValue;
		}
		attribute def ShutoffCommand {
			attribute emergencyShutdown : Boolean;
		}
		attribute def VentCommand;
		attribute def DisplayMessage {
			attribute text : String;
		}

		part def H2StorageTank {
			attribute maxPressure : PressureValue;
			port hydrogenOutPort {
				out item hydrogen : Hydrogen;
			}
		}

		part def CNGStorageTank {
			attribute maxPressure : PressureValue;
			port cngOutPort {
				out item cng : CNG;
			}
		}

		part def UserInterface {
			port paymentOutPort {
				out payment : PaymentInfo;
			}
			port blendOutPort {
				out blend : BlendSelection;
			}
			port authResultInPort {
				in authResult : AuthResult;
			}
			port displayInPort {
				in display : DisplayMessage;
			}
		}

		part def ControlModule {
			attribute maxSafePressure : PressureValue;
			attribute maxSafeTemperature : TemperatureValue;
			attribute minSafeTemperature : TemperatureValue;

			port paymentInPort {
				in payment : PaymentInfo;
			}
			port blendInPort {
				in blend : BlendSelection;
			}
			port pressureSensorInPort {
				in pressure : PressureReading;
			}
			port temperatureSensorInPort {
				in temperature : TemperatureReading;
			}
			port flowMeterInPort {
				in flowReading : FlowReading;
			}
			port leakDetectionInPort {
				in leak : LeakAlert;
			}
			port nozzleStatusInPort {
				in nozzleStatus : NozzleStatus;
			}
			port blendCommandOutPort {
				out blendCommand : BlendCommand;
			}
			port fuelCommandOutPort {
				out fuelCommand : FuelCommand;
			}
			port shutoffCommandOutPort {
				out shutoffCommand : ShutoffCommand;
			}
			port ventCommandOutPort {
				out ventCommand : VentCommand;
			}
			port authResultOutPort {
				out authResult : AuthResult;
			}
			port displayOutPort {
				out display : DisplayMessage;
			}
		}

		part def BlendingValve {
			port hydrogenInPort {
				in item hydrogen : Hydrogen;
			}
			port cngInPort {
				in item cng : CNG;
			}
			port blendCommandInPort {
				in blendCommand : BlendCommand;
			}
			port hcngOutPort {
				out item hcng : HCNGBlend;
			}
		}

		part def CompressionModule {
			port hcngInPort {
				in item hcng : HCNGBlend;
			}
			port fuelCommandInPort {
				in fuelCommand : FuelCommand;
			}
			port hcngOutPort {
				out item hcng : HCNGBlend;
			}
		}

		part def SafetyShutoffValve {
			attribute valveOpen : Boolean;
			port hcngInPort {
				in item hcng : HCNGBlend;
			}
			port shutoffCommandInPort {
				in shutoffCommand : ShutoffCommand;
			}
			port hcngOutPort {
				out item hcng : HCNGBlend;
			}
			port ventOutPort {
				out item vent : HCNGBlend;
			}
		}

		part def DispensingNozzle {
			attribute connected : Boolean;
			attribute locked : Boolean;
			port hcngInPort {
				in item hcng : HCNGBlend;
			}
			port nozzleStatusOutPort {
				out nozzleStatus : NozzleStatus;
			}
			port hcngOutPort {
				out item hcng : HCNGBlend;
			}
		}

		part def PressureSensor {
			port pressureOutPort {
				out pressure : PressureReading;
			}
		}

		part def TemperatureSensor {
			port temperatureOutPort {
				out temperature : TemperatureReading;
			}
		}

		part def FlowMeter {
			port flowOutPort {
				out flowReading : FlowReading;
			}
		}

		part def LeakDetectionSystem {
			port leakAlertOutPort {
				out leak : LeakAlert;
			}
		}

		part def VentingSystem {
			port ventCommandInPort {
				in ventCommand : VentCommand;
			}
			port ventInPort {
				in item vent : HCNGBlend;
			}
			port ventOutPort {
				out item ventGas : VentGas;
			}
		}

		part def Vehicle {
			port fuelInPort {
				in item fuel : HCNGBlend;
			}
		}

		part def Dispenser;

		action def AuthenticatePayment {
			in payment : PaymentInfo;
			out result : AuthResult;
		}

		action def PerformSafetyCheck {
			in nozzleStatus : NozzleStatus;
			in pressure : PressureReading;
			in temperature : TemperatureReading;
			in leak : LeakAlert;
			out pass : Boolean;
		}

		action def PrepareBlend {
			in selection : BlendSelection;
			out command : BlendCommand;
		}

		action def DispenseFuel {
			in command : FuelCommand;
		}

		action def CompleteTransaction {
			out message : DisplayMessage;
		}

		action def EmergencyShutdownAction {
			out shutoff : ShutoffCommand;
			out vent : VentCommand;
		}

		action def MonitorSensors {
			out pressure : PressureReading;
			out temperature : TemperatureReading;
			out flowReading : FlowReading;
			out leak : LeakAlert;
		}

		state def DispenserStates {
			in ctrl : ControlModule;
			in nzl : DispensingNozzle;
			in blnd : BlendingValve;
			in cmp : CompressionModule;
			in shut : SafetyShutoffValve;
			in vnt : VentingSystem;
			in pS : PressureSensor;
			in tS : TemperatureSensor;
			in fM : FlowMeter;
			in lD : LeakDetectionSystem;
			in usr : UserInterface;
		}
	}

	package Usages {
		private import Definitions::*;

		action authenticatePayment : AuthenticatePayment;
		action performSafetyCheck : PerformSafetyCheck;
		action prepareBlend : PrepareBlend;
		action dispenseFuel : DispenseFuel;
		action completeTransaction : CompleteTransaction;
		action emergencyShutdownAction : EmergencyShutdownAction;
		action monitorSensors : MonitorSensors;

		part dispenser : Dispenser {
			part ui : UserInterface;
			part controlModule : ControlModule;
			part h2Tank : H2StorageTank;
			part cngTank : CNGStorageTank;
			part blendingValve : BlendingValve;
			part compressionModule : CompressionModule;
			part safetyShutoffValve : SafetyShutoffValve;
			part dispensingNozzle : DispensingNozzle;
			part pressureSensor : PressureSensor;
			part temperatureSensor : TemperatureSensor;
			part flowMeter : FlowMeter;
			part leakDetection : LeakDetectionSystem;
			part ventingSystem : VentingSystem;
			part vehicle : Vehicle;

			bind blendingValve.hydrogenInPort.hydrogen = h2Tank.hydrogenOutPort.hydrogen;
			bind blendingValve.cngInPort.cng = cngTank.cngOutPort.cng;
			bind compressionModule.hcngInPort.hcng = blendingValve.hcngOutPort.hcng;
			bind safetyShutoffValve.hcngInPort.hcng = compressionModule.hcngOutPort.hcng;
			bind dispensingNozzle.hcngInPort.hcng = safetyShutoffValve.hcngOutPort.hcng;
			bind vehicle.fuelInPort.fuel = dispensingNozzle.hcngOutPort.hcng;
			bind ventingSystem.ventInPort.vent = safetyShutoffValve.ventOutPort.vent;

			bind controlModule.paymentInPort.payment = ui.paymentOutPort.payment;
			bind controlModule.blendInPort.blend = ui.blendOutPort.blend;
			bind ui.authResultInPort.authResult = controlModule.authResultOutPort.authResult;
			bind ui.displayInPort.display = controlModule.displayOutPort.display;
			bind blendingValve.blendCommandInPort.blendCommand = controlModule.blendCommandOutPort.blendCommand;
			bind compressionModule.fuelCommandInPort.fuelCommand = controlModule.fuelCommandOutPort.fuelCommand;
			bind safetyShutoffValve.shutoffCommandInPort.shutoffCommand = controlModule.shutoffCommandOutPort.shutoffCommand;
			bind ventingSystem.ventCommandInPort.ventCommand = controlModule.ventCommandOutPort.ventCommand;

			bind controlModule.nozzleStatusInPort.nozzleStatus = dispensingNozzle.nozzleStatusOutPort.nozzleStatus;
			bind controlModule.pressureSensorInPort.pressure = pressureSensor.pressureOutPort.pressure;
			bind controlModule.temperatureSensorInPort.temperature = temperatureSensor.temperatureOutPort.temperature;
			bind controlModule.flowMeterInPort.flowReading = flowMeter.flowOutPort.flowReading;
			bind controlModule.leakDetectionInPort.leak = leakDetection.leakAlertOutPort.leak;

			exhibit state dispenserStates : DispenserStates {
				in ctrl = controlModule;
				in nzl = dispensingNozzle;
				in blnd = blendingValve;
				in cmp = compressionModule;
				in shut = safetyShutoffValve;
				in vnt = ventingSystem;
				in pS = pressureSensor;
				in tS = temperatureSensor;
				in fM = flowMeter;
				in lD = leakDetection;
				in usr = ui;

				entry; then idle;

				state idle;
				accept UserStartSignal
					then authenticating;

				state authenticating {
					entry authenticatePayment {
						in payment = ctrl.paymentInPort.payment;
						out result = ctrl.authResultOutPort.authResult;
					}
				}
				accept AuthSuccessSignal
					then preparing;
				accept AuthFailSignal
					then idle;

				state preparing {
					entry performSafetyCheck {
						in nozzleStatus = nzl.nozzleStatusOutPort.nozzleStatus;
						in pressure = pS.pressureOutPort.pressure;
						in temperature = tS.temperatureOutPort.temperature;
						in leak = lD.leakAlertOutPort.leak;
					}
					do prepareBlend {
						in selection = ctrl.blendInPort.blend;
						out command = ctrl.blendCommandOutPort.blendCommand;
					}
				}
				accept SafetyCheckPassSignal
					then dispensing;
				accept SafetyCheckFailSignal
					then fault;

				state dispensing {
					entry monitorSensors {
						out pressure = pS.pressureOutPort.pressure;
						out temperature = tS.temperatureOutPort.temperature;
						out flowReading = fM.flowOutPort.flowReading;
						out leak = lD.leakAlertOutPort.leak;
					}
					do dispenseFuel {
						in command = ctrl.fuelCommandOutPort.fuelCommand;
					}
				}
				accept TankFullSignal
					then completing;
				accept AnomalySignal
					then fault;

				state completing {
					entry completeTransaction {
						out message = ctrl.displayOutPort.display;
					}
				}
				accept TransactionCompleteSignal
					then idle;

				state fault {
					entry emergencyShutdownAction {
						out shutoff = ctrl.shutoffCommandOutPort.shutoffCommand;
						out vent = ctrl.ventCommandOutPort.ventCommand;
					}
				}
				accept ResetSignal
					then idle;
			}
		}
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def SafetyRequirement {
			doc
			/* The dispenser must ensure safety during all fueling operations.
			 * Emergency shutdown must activate within maxResponseTime seconds
			 * of detecting any anomaly including pressure, temperature, or leak. */
			subject dispenser : Dispenser;
			attribute maxResponseTime : Real = 1.0;
			assert constraint {
				doc /* Emergency shutdown must occur within maxResponseTime seconds. */
			}
		}

		requirement def BlendPrecisionRequirement {
			doc
			/* The blending valve must deliver fuel within the specified blend
			 * tolerance. Hydrogen content must not exceed 30%. */
			subject blendingValve : BlendingValve;
			attribute blendTolerance : Real = 0.02;
			attribute maxHydrogenContent : Real = 30.0;
			assert constraint {
				doc /* Hydrogen content must not exceed maxHydrogenContent and must be within blendTolerance of target. */
			}
		}

		requirement def AuthenticationRequirement {
			doc
			/* Payment must be authenticated before any fuel is dispensed. */
			subject controlModule : ControlModule;
			assert constraint {
				doc /* No fuel flow shall occur until authentication is successfully completed. */
			}
		}

		requirement def DispensingPressureRequirement {
			doc
			/* The compression module must deliver fuel at the target pressure
			 * for efficient vehicle tank filling. */
			subject compressionModule : CompressionModule;
			attribute targetPressure : PressureValue;
			assert constraint {
				doc /* Output pressure must meet or exceed the target pressure. */
			}
		}

		requirement def LeakDetectionRequirement {
			doc
			/* The leak detection system must detect any gas leaks and trigger
			 * emergency shutdown immediately. */
			subject leakDetection : LeakDetectionSystem;
			assert constraint {
				doc /* Leak detection must be active during all dispensing operations. */
			}
		}

		requirement def NozzleInterlockRequirement {
			doc
			/* The dispensing nozzle must be securely connected and locked
			 * before any fuel flows. */
			subject dispensingNozzle : DispensingNozzle;
			assert constraint {
				doc /* Fuel flow shall not begin until nozzle is connected and locked. */
			}
		}

		requirement def VentingRequirement {
			doc
			/* The venting system must safely release pressure when commanded
			 * during emergency shutdown or maintenance. */
			subject ventingSystem : VentingSystem;
			assert constraint {
				doc /* Venting system must release pressure safely when activated. */
			}
		}

		requirement safetyReq : SafetyRequirement;
		requirement blendPrecisionReq : BlendPrecisionRequirement;
		requirement authReq : AuthenticationRequirement;
		requirement dispensingPressureReq : DispensingPressureRequirement;
		requirement leakDetectionReq : LeakDetectionRequirement;
		requirement nozzleInterlockReq : NozzleInterlockRequirement;
		requirement ventingReq : VentingRequirement;

		satisfy safetyReq by dispenser;
		satisfy blendPrecisionReq by dispenser.blendingValve;
		satisfy authReq by dispenser.controlModule;
		satisfy dispensingPressureReq by dispenser.compressionModule;
		satisfy leakDetectionReq by dispenser.leakDetection;
		satisfy nozzleInterlockReq by dispenser.dispensingNozzle;
		satisfy ventingReq by dispenser.ventingSystem;
	}

	import Definitions::*;
	import Usages::*;
}
