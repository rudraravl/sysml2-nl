package IndustrialFluidTransferSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		import ItemDefinitions::*;
		import PortDefinitions::*;
		import AttributeDefinitions::*;
		import ActionDefinitions::*;
		import StateDefinitions::*;
		import PartDefinitions::*;
		import RequirementDefinitions::*;

		package ItemDefinitions {
			item def ProcessFluid {
				attribute density :> ISQ::mass / ISQ::volume;
				attribute viscosity :> ISQ::dynamicViscosity;
				attribute solidsContent : Real;
			}
		}

		package PortDefinitions {
			port def FluidPort {
				in item fluidIn : ProcessFluid;
				out item fluidOut : ProcessFluid;
			}
			port def SuctionPort :> FluidPort;
			port def DischargePort :> FluidPort;

			port def ElectricalPowerPort {
				attribute frequency :> ISQ::frequency;
				attribute voltage :> ISQ::electricPotential;
				attribute current :> ISQ::electricCurrent;
			}
			port def MechanicalDrivePort {
				attribute rotationalSpeed :> ISQ::angularVelocity;
				attribute torque :> ISQ::torque;
			}
			port def ControlPort {
				in attribute speedCommand :> ISQ::frequency;
				in attribute startCmd : Boolean;
				in attribute stopCmd : Boolean;
				in attribute emergencyStopCmd : Boolean;
				out attribute actualSpeed :> ISQ::angularVelocity;
				out attribute status : String;
			}
			port def SensorPort {
				out attribute measuredPressure :> ISQ::pressure;
				out attribute measuredTemperature :> ISQ::temperature;
				out attribute measuredFlowRate :> ISQ::volumeFlowRate;
			}
		}

		package AttributeDefinitions {
			attribute def StartSignal;
			attribute def StopSignal;
			attribute def EmergencyStopSignal;
			attribute def CavitationAlert;
			attribute def FlowAdjustCommand {
				attribute targetFlowRate :> ISQ::volumeFlowRate;
			}
			attribute def ReturnToNormal;
			attribute def PrimingComplete;
			attribute def StartupComplete;
		}

		package ActionDefinitions {
			action def TransferFluid {
				in item supplyFluid : ProcessFluid;
				out item dischargeFluid : ProcessFluid;
			}
			action def PrimePump;
			action def StartPump;
			action def StopPump;
			action def AdjustFlowRate {
				in targetFlowRate :> ISQ::volumeFlowRate;
			}
			action def EngageEmergencyStop;
			action def SenseSuctionPressure { out pressure :> ISQ::pressure; }
			action def SenseSuctionTemperature { out temperature :> ISQ::temperature; }
			action def SenseDischargePressure { out pressure :> ISQ::pressure; }
			action def SenseDischargeTemperature { out temperature :> ISQ::temperature; }
			action def SenseFlowRate { out flowRate :> ISQ::volumeFlowRate; }
			action def DetectCavitation {
				in suctionPressure :> ISQ::pressure;
				out cavitationDetected : Boolean;
			}
		}

		package StateDefinitions {
			state def SystemStates;
		}

		package PartDefinitions {
			part def SupplyReservoir {
				attribute volume :> ISQ::volume;
				attribute fluidLevel :> ISQ::length;
				port dischargePort : DischargePort;
			}
			part def DischargeVessel {
				attribute volume :> ISQ::volume;
				attribute fluidLevel :> ISQ::length;
				port inletPort : DischargePort;
			}
			part def Rotor {
				attribute material : String = "StainlessSteel";
				attribute pitch :> ISQ::length;
				attribute diameter :> ISQ::length;
			}
			part def Stator {
				attribute material : String = "Elastomer";
				attribute helixCount : Integer = 2;
				attribute boreDiameter :> ISQ::length;
			}
			part def PumpSeals {
				attribute sealMaterial : String = "PTFE";
			}
			part def Driveshaft {
				attribute material : String = "StainlessSteel";
				attribute length :> ISQ::length;
				attribute diameter :> ISQ::length;
			}
			part def ProgressingCavityPump {
				part rotor : Rotor;
				part stator : Stator;
				part seals : PumpSeals;
				part driveshaft : Driveshaft;
				attribute ratedFlowRate :> ISQ::volumeFlowRate;
				attribute ratedPressure :> ISQ::pressure;
				attribute minSuctionPressure :> ISQ::pressure;
				port suctionPort : SuctionPort;
				port dischargePort : DischargePort;
				port drivePort : MechanicalDrivePort;
				perform action transferFluid : TransferFluid;
			}
			part def ThreePhaseInductionMotor {
				attribute ratedPower :> ISQ::power;
				attribute ratedSpeed :> ISQ::angularVelocity;
				attribute ratedVoltage :> ISQ::electricPotential;
				attribute actualSpeed :> ISQ::angularVelocity;
				port powerInputPort : ElectricalPowerPort;
				port mechanicalOutputPort : MechanicalDrivePort;
			}
			part def VariableFrequencyDrive {
				attribute minFrequency :> ISQ::frequency;
				attribute maxFrequency :> ISQ::frequency;
				attribute outputFrequency :> ISQ::frequency;
				port powerInputPort : ElectricalPowerPort;
				port powerOutputPort : ElectricalPowerPort;
				port controlPort : ControlPort;
			}
			part def PressureSensor {
				attribute range :> ISQ::pressure;
				attribute measuredPressure :> ISQ::pressure;
				port fluidPort : FluidPort;
				port sensorPort : SensorPort;
				perform action sensePressure;
			}
			part def TemperatureSensor {
				attribute range :> ISQ::temperature;
				attribute measuredTemperature :> ISQ::temperature;
				port fluidPort : FluidPort;
				port sensorPort : SensorPort;
				perform action senseTemperature;
			}
			part def FlowMeter {
				attribute range :> ISQ::volumeFlowRate;
				attribute measuredFlowRate :> ISQ::volumeFlowRate;
				port fluidPort : FluidPort;
				port sensorPort : SensorPort;
				perform action senseFlow;
			}
			part def PumpController {
				attribute setFlowRate :> ISQ::volumeFlowRate;
				attribute maxDischargePressure :> ISQ::pressure;
				attribute cavitationPressureThreshold :> ISQ::pressure;
				port controlPort : ControlPort;
				port sensorInputPort : SensorPort;
			}
			part def FluidTransferSystem {
				attribute systemFlowRate :> ISQ::volumeFlowRate;
				attribute systemPressure :> ISQ::pressure;
				attribute emergencyStopActivated : Boolean;
				part supplyReservoir : SupplyReservoir;
				part dischargeVessel : DischargeVessel;
				part pump : ProgressingCavityPump;
				part motor : ThreePhaseInductionMotor;
				part vfd : VariableFrequencyDrive;
				part suctionPressureSensor : PressureSensor;
				part suctionTemperatureSensor : TemperatureSensor;
				part dischargePressureSensor : PressureSensor;
				part dischargeTemperatureSensor : TemperatureSensor;
				part flowMeter : FlowMeter;
				part controller : PumpController;
				perform action transferFluid : TransferFluid;
				perform action primePump : PrimePump;
				perform action startPump : StartPump;
				perform action stopPump : StopPump;
				perform action adjustFlowRate : AdjustFlowRate;
				perform action engageEmergencyStop : EngageEmergencyStop;
				exhibit state systemStates : SystemStates;
			}
		}

		package RequirementDefinitions {
			requirement def FlowRateRequirement {
				doc /* The system shall transfer fluid at the required flow rate. */
				attribute requiredFlowRate :> ISQ::volumeFlowRate;
				subject system : FluidTransferSystem;
				constraint { system.systemFlowRate >= requiredFlowRate }
			}
			requirement def PressureControlRequirement {
				doc /* The system shall not exceed the maximum discharge pressure. */
				attribute maxDischargePressure :> ISQ::pressure;
				subject system : FluidTransferSystem;
				constraint { system.systemPressure <= maxDischargePressure }
			}
			requirement def CavitationProtectionRequirement {
				doc /* The system shall enter a protective state when suction pressure falls below the minimum threshold. */
				attribute minSuctionPressure :> ISQ::pressure;
				subject pump : ProgressingCavityPump;
				constraint { pump.minSuctionPressure >= minSuctionPressure }
			}
			requirement def EmergencyStopRequirement {
				doc /* The system shall halt all operations within the specified time of an emergency stop command. */
				attribute maxResponseTime :> ISQ::duration;
				subject system : FluidTransferSystem;
			}
		}
	}

	package Usages {
		private import Definitions::ItemDefinitions::*;
		private import Definitions::PortDefinitions::*;
		private import Definitions::AttributeDefinitions::*;
		private import Definitions::ActionDefinitions::*;
		private import Definitions::StateDefinitions::*;
		private import Definitions::PartDefinitions::*;
		private import Definitions::RequirementDefinitions::*;

		action primePump : PrimePump;
		action startPump : StartPump;
		action stopPump : StopPump;
		action adjustFlowRate : AdjustFlowRate;
		action engageEmergencyStop : EngageEmergencyStop;
		action senseSuctionPressure : SenseSuctionPressure;
		action senseSuctionTemperature : SenseSuctionTemperature;
		action senseDischargePressure : SenseDischargePressure;
		action senseDischargeTemperature : SenseDischargeTemperature;
		action senseFlowRate : SenseFlowRate;
		action detectCavitation : DetectCavitation;

		part fluidTransferSystem : FluidTransferSystem {
			part supplyReservoir : SupplyReservoir {
				attribute volume = 5000[L];
				attribute fluidLevel = 4000[mm];
			}
			part dischargeVessel : DischargeVessel {
				attribute volume = 5000[L];
				attribute fluidLevel = 0[mm];
			}
			part pump : ProgressingCavityPump {
				attribute ratedFlowRate = 50[L/min];
				attribute ratedPressure = 10[bar];
				attribute minSuctionPressure = 0.5[bar];
				part rotor : Rotor {
					attribute pitch = 100[mm];
					attribute diameter = 60[mm];
				}
				part stator : Stator {
					attribute boreDiameter = 62[mm];
				}
				part seals : PumpSeals;
				part driveshaft : Driveshaft {
					attribute length = 500[mm];
					attribute diameter = 40[mm];
				}
			}
			part motor : ThreePhaseInductionMotor {
				attribute ratedPower = 5.5[kW];
				attribute ratedSpeed = 1450[rev/min];
				attribute ratedVoltage = 400[V];
			}
			part vfd : VariableFrequencyDrive {
				attribute minFrequency = 0[Hz];
				attribute maxFrequency = 60[Hz];
			}
			part suctionPressureSensor : PressureSensor {
				attribute range = 5[bar];
			}
			part suctionTemperatureSensor : TemperatureSensor {
				attribute range = 150[degC];
			}
			part dischargePressureSensor : PressureSensor {
				attribute range = 20[bar];
			}
			part dischargeTemperatureSensor : TemperatureSensor {
				attribute range = 150[degC];
			}
			part flowMeter : FlowMeter {
				attribute range = 100[L/min];
			}
			part controller : PumpController {
				attribute setFlowRate = 40[L/min];
				attribute maxDischargePressure = 8[bar];
				attribute cavitationPressureThreshold = 0.5[bar];
			}

			connect supplyReservoir.dischargePort to suctionPressureSensor.fluidPort;
			connect suctionPressureSensor.fluidPort to suctionTemperatureSensor.fluidPort;
			connect suctionTemperatureSensor.fluidPort to pump.suctionPort;
			connect pump.dischargePort to dischargePressureSensor.fluidPort;
			connect dischargePressureSensor.fluidPort to dischargeTemperatureSensor.fluidPort;
			connect dischargeTemperatureSensor.fluidPort to flowMeter.fluidPort;
			connect flowMeter.fluidPort to dischargeVessel.inletPort;
			connect vfd.powerOutputPort to motor.powerInputPort;
			connect motor.mechanicalOutputPort to pump.drivePort;
			connect vfd.controlPort to controller.controlPort;
			connect suctionPressureSensor.sensorPort to controller.sensorInputPort;
			connect dischargePressureSensor.sensorPort to controller.sensorInputPort;
			connect flowMeter.sensorPort to controller.sensorInputPort;

			exhibit state systemStates : SystemStates parallel {
				state operationalStates {
					entry; then idle;
					state idle;
					transition idleToPriming first idle
						accept StartSignal
						then priming;
					state priming {
						entry primePump;
					}
					transition primingToStarting first priming
						accept PrimingComplete
						then starting;
					state starting {
						entry startPump;
					}
					transition startingToNormal first starting
						accept StartupComplete
						then normalOperation;
					state normalOperation {
						do transferFluid;
					}
					transition normalToAdjusting first normalOperation
						accept FlowAdjustCommand
						then adjustingFlow;
					state adjustingFlow {
						do adjustFlowRate;
					}
					transition adjustingToNormal first adjustingFlow
						accept ReturnToNormal
						then normalOperation;
					transition normalToProtective first normalOperation
						accept CavitationAlert
						then protectiveCavitation;
					state protectiveCavitation {
						do stopPump;
					}
					transition protectiveToNormal first protectiveCavitation
						accept ReturnToNormal
						then normalOperation;
					transition normalToStopping first normalOperation
						accept StopSignal
						do stopPump
						then stopping;
					state stopping {
						entry stopPump;
					}
					transition stoppingToIdle first stopping
						accept when true
						then idle;
				}

				state safetyStates {
					entry; then armed;
					state armed;
					transition armedToEmergency first armed
						accept EmergencyStopSignal
						do engageEmergencyStop
						then emergencyStopped;
					state emergencyStopped;
					transition emergencyToArmed first emergencyStopped
						accept ReturnToNormal
						then armed;
				}

				state healthStates {
					entry; then normal;
					state normal;
					transition normalToCavitationDetected first normal
						accept CavitationAlert
						then cavitationDetected;
					state cavitationDetected;
					transition cavitationDetectedToNormal first cavitationDetected
						accept ReturnToNormal
						then normal;
				}
			}
		}

		requirement flowRateReq : FlowRateRequirement {
			attribute requiredFlowRate = 40[L/min];
			subject system :> fluidTransferSystem;
		}
		requirement pressureControlReq : PressureControlRequirement {
			attribute maxDischargePressure = 8[bar];
			subject system :> fluidTransferSystem;
		}
		requirement cavitationProtectionReq : CavitationProtectionRequirement {
			attribute minSuctionPressure = 0.5[bar];
			subject pump :> fluidTransferSystem.pump;
		}
		requirement emergencyStopReq : EmergencyStopRequirement {
			attribute maxResponseTime = 1[s];
			subject system :> fluidTransferSystem;
		}
	}
}
