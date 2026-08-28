package 'Hengsteysee Hydropower System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def Water;
		item def Electricity;

		attribute def StartCmd;
		attribute def StopCmd;
		attribute def RunningConfirmed;
		attribute def StoppedConfirmed;
		attribute def OpenCmd;
		attribute def CloseCmd;
		attribute def GateOpened;
		attribute def GateClosed;
		attribute def FloodCondition;
		attribute def DroughtCondition;
		attribute def NormalWaterLevel;
		attribute def OverCriticalLevel;
		attribute def ReturnToNormal;

		port def WaterPort {
			in item water : Water;
		}
		port def PowerPort {
			out item electricity : Electricity;
		}
		port def CommandPort {
			in command : ScalarValues::Real;
			out status : ScalarValues::Real;
		}
		port def SensorDataPort {
			out upstreamLevel :> ISQ::length;
			out downstreamLevel :> ISQ::length;
			out inflowRate :> ISQ::volumeFlowRate;
			out outflowRate :> ISQ::volumeFlowRate;
		}

		action def GeneratePower;
		action def StartTurbine;
		action def StopTurbine;
		action def OpenGate;
		action def CloseGate;
		action def RegulateGate;
		action def MonitorSensors {
			out upstreamLevel :> ISQ::length;
			out downstreamLevel :> ISQ::length;
			out inflow :> ISQ::volumeFlowRate;
			out outflow :> ISQ::volumeFlowRate;
		}
		action def SendAlert;
		action def DischargeWater;
		action def AdjustTurbine;
		action def AdjustGate;
		action def ConserveWater;
		action def MaintainEnvFlow;

		state def TurbineStates {
			entry; then stopped;
			state stopped;
			accept StartCmd then starting;
			state starting {
				entry action startTurbine : StartTurbine;
			}
			accept RunningConfirmed then running;
			state running {
				do action generatePower : GeneratePower;
				exit action stopTurbine : StopTurbine;
			}
			accept StopCmd then stopping;
			state stopping {
				entry action stopTurbine : StopTurbine;
			}
			accept StoppedConfirmed then stopped;
		}

		state def GateStates {
			entry; then closed;
			state closed;
			accept OpenCmd then opening;
			state opening {
				entry action openGate : OpenGate;
			}
			accept GateOpened then open;
			state open {
				do action regulateGate : RegulateGate;
			}
			accept CloseCmd then closing;
			state closing {
				entry action closeGate : CloseGate;
			}
			accept GateClosed then closed;
		}

		state def SpillwayStates {
			entry; then idle;
			state idle;
			accept OverCriticalLevel then discharging;
			state discharging {
				do action dischargeWater : DischargeWater;
			}
			accept ReturnToNormal then idle;
		}

		state def ControlStates {
			entry; then normal;
			state normal {
				do action monitorSensors : MonitorSensors;
			}
			accept FloodCondition then floodControl;
			state floodControl {
				entry action sendAlert : SendAlert;
				do action adjustGate : AdjustGate;
				do action adjustTurbine : AdjustTurbine;
			}
			accept NormalWaterLevel then normal;
			accept DroughtCondition then lowWater;
			state lowWater {
				entry action sendAlert : SendAlert;
				do action conserveWater : ConserveWater;
				do action maintainEnvFlow : MaintainEnvFlow;
			}
			accept NormalWaterLevel then normal;
		}

		part def Dam {
			attribute crestElevation :> ISQ::length;
			attribute criticalLevel :> ISQ::length;
			port reservoirConnection : WaterPort;
			port downstreamConnection : WaterPort;
		}

		part def Reservoir {
			attribute capacity :> ISQ::volume;
			attribute currentLevel :> ISQ::length;
			attribute targetLevel :> ISQ::length;
			attribute minLevel :> ISQ::length;
			attribute maxLevel :> ISQ::length;
			ref item water : Water;
			port inflowPort : WaterPort;
			port outflowPort : WaterPort;
		}

		part def Turbine {
			attribute ratedPower :> ISQ::power;
			attribute efficiency : ScalarValues::Real;
			port waterIn : WaterPort;
			port waterOut : WaterPort;
			port powerOut : PowerPort;
			port commandIn : CommandPort;
			perform action generatePower : GeneratePower;
			exhibit state turbineStates : TurbineStates;
		}

		part def SluiceGate {
			attribute opening : ScalarValues::Real;
			attribute maxDischarge :> ISQ::volumeFlowRate;
			port waterIn : WaterPort;
			port waterOut : WaterPort;
			port commandIn : CommandPort;
			exhibit state gateStates : GateStates;
		}

		part def Spillway {
			attribute crestLevel :> ISQ::length;
			attribute dischargeCapacity :> ISQ::volumeFlowRate;
			port waterIn : WaterPort;
			port waterOut : WaterPort;
			exhibit state spillwayStates : SpillwayStates;
		}

		part def ControlCenter {
			port commandToTurbine : CommandPort;
			port commandToGate : CommandPort;
			port sensorDataIn : SensorDataPort;
			perform action monitorSensors : MonitorSensors;
			exhibit state controlStates : ControlStates;
		}

		part def SensorSuite {
			attribute upstreamLevel :> ISQ::length;
			attribute downstreamLevel :> ISQ::length;
			attribute inflowRate :> ISQ::volumeFlowRate;
			attribute outflowRate :> ISQ::volumeFlowRate;
			port dataOut : SensorDataPort;
			perform action monitorSensors : MonitorSensors;
		}

		part def PowerGrid {
			port powerIn : PowerPort;
			attribute frequency :> ISQ::frequency;
		}

		part def River {
			port inflow : WaterPort;
			port outflow : WaterPort;
			attribute waterLevel :> ISQ::length;
			attribute flowRate :> ISQ::volumeFlowRate;
		}

		requirement def PowerGenerationReq {
			doc /* The system shall generate renewable hydroelectric power and supply it to the main power grid. */
			subject system;
		}
		requirement def ReservoirLevelReq {
			doc /* The control center shall maintain the reservoir level between minimum and maximum operational levels. */
			subject system;
		}
		requirement def FloodControlReq {
			doc /* The system shall safely discharge excess water during flood conditions to prevent downstream flooding. */
			subject system;
		}
		requirement def EnvironmentalFlowReq {
			doc /* The system shall ensure a minimum environmental flow downstream during low water conditions. */
			subject system;
		}
		requirement def DamSafetyReq {
			doc /* The spillway shall automatically discharge water when the critical reservoir level is exceeded to prevent dam overtopping. */
			subject system;
		}
	}

	package Usages {
		private import Definitions::*;

		part hengsteyseeSystem {
			part dam : Dam {
				attribute redefines crestElevation = 105.0 [m];
				attribute redefines criticalLevel = 102.0 [m];
			}
			part reservoir : Reservoir {
				attribute redefines capacity = 5000000.0 [m^3];
				attribute redefines targetLevel = 95.0 [m];
				attribute redefines minLevel = 80.0 [m];
				attribute redefines maxLevel = 100.0 [m];
			}
			part mainTurbine : Turbine {
				attribute redefines ratedPower = 3000000.0 [W];
			}
			part auxiliaryTurbine : Turbine {
				attribute redefines ratedPower = 1500000.0 [W];
			}
			part primarySluiceGate : SluiceGate;
			part emergencySluiceGate : SluiceGate;
			part spillway : Spillway {
				attribute redefines crestLevel = 99.0 [m];
			}
			part controlCenter : ControlCenter;
			part sensorSuite : SensorSuite;
			part powerGrid : PowerGrid;
			part upstreamRiver : River;
			part downstreamRiver : River;

			connect upstreamRiver.outflow to reservoir.inflowPort;
			connect reservoir.outflowPort to mainTurbine.waterIn;
			connect reservoir.outflowPort to auxiliaryTurbine.waterIn;
			connect reservoir.outflowPort to primarySluiceGate.waterIn;
			connect reservoir.outflowPort to emergencySluiceGate.waterIn;
			connect reservoir.outflowPort to spillway.waterIn;

			connect mainTurbine.waterOut to downstreamRiver.inflow;
			connect auxiliaryTurbine.waterOut to downstreamRiver.inflow;
			connect primarySluiceGate.waterOut to downstreamRiver.inflow;
			connect emergencySluiceGate.waterOut to downstreamRiver.inflow;
			connect spillway.waterOut to downstreamRiver.inflow;

			connect mainTurbine.powerOut to powerGrid.powerIn;
			connect auxiliaryTurbine.powerOut to powerGrid.powerIn;

			connect sensorSuite.dataOut to controlCenter.sensorDataIn;

			connect controlCenter.commandToTurbine to mainTurbine.commandIn;
			connect controlCenter.commandToTurbine to auxiliaryTurbine.commandIn;
			connect controlCenter.commandToGate to primarySluiceGate.commandIn;
			connect controlCenter.commandToGate to emergencySluiceGate.commandIn;

			assert constraint {
				reservoir.currentLevel >= reservoir.minLevel and
				reservoir.currentLevel <= reservoir.maxLevel
			}

			requirement powerGenReq : PowerGenerationReq;
			satisfy powerGenReq by mainTurbine;
			satisfy powerGenReq by auxiliaryTurbine;
			assert satisfy powerGenReq by hengsteyseeSystem;

			requirement levelReq : ReservoirLevelReq;
			satisfy levelReq by controlCenter;
			assert satisfy levelReq by hengsteyseeSystem;

			requirement floodReq : FloodControlReq;
			satisfy floodReq by spillway;
			satisfy floodReq by primarySluiceGate;
			satisfy floodReq by emergencySluiceGate;
			assert satisfy floodReq by hengsteyseeSystem;

			requirement envFlowReq : EnvironmentalFlowReq;
			satisfy envFlowReq by controlCenter;
			assert satisfy envFlowReq by hengsteyseeSystem;

			requirement damSafetyReq : DamSafetyReq;
			satisfy damSafetyReq by spillway;
			assert satisfy damSafetyReq by hengsteyseeSystem;
		}
	}
}
