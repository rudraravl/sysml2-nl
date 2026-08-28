package 'Steam Pulsometer Pumping System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		item def Water;
		item def Steam {
			attribute pressure : PressureValue;
			attribute temperature : Real;
		}
		item def Condensate :> Water;

		port def SteamPort {
			out item steam : Steam;
		}
		port def WaterPort {
			out item water : Water;
		}
		port def CondensatePort {
			out item condensate : Condensate;
		}

		interface def SteamSupplyInterface {
			end supplier : SteamPort;
			end consumer : ~SteamPort;
		}
		interface def WaterSupplyInterface {
			end source : WaterPort;
			end sink : ~WaterPort;
		}
		interface def WaterDischargeInterface {
			end source : WaterPort;
			end sink : ~WaterPort;
		}
		interface def CondensateReturnInterface {
			end source : CondensatePort;
			end sink : ~CondensatePort;
		}

		action def GenerateSteam {
			out steamOut : Steam;
		}

		action def PumpCycle {
			in steamIn : Steam;
			in waterIn : Water;
			out waterOut : Water;
			out condensateOut : Condensate;

			action condenseSteam {
				doc /* Steam condenses on cool chamber walls, creating a vacuum. */
				in steam : Steam;
				out condensate : Condensate;
			}
			action suctionFill {
				doc /* Vacuum draws water from the source through the suction valve. */
				in water : Water;
				out filledWater : Water;
			}
			action steamPressurize {
				doc /* High-pressure steam pushes directly on the water surface. */
				in steam : Steam;
				in water : Water;
				out pressurizedWater : Water;
			}
			action discharge {
				doc /* Pressurized water exits through the discharge valve. */
				in pressurizedWater : Water;
				out dischargedWater : Water;
			}

			flow from steamIn to condenseSteam.steam;
			flow from condenseSteam.condensate to condensateOut;
			flow from waterIn to suctionFill.water;
			flow from suctionFill.filledWater to steamPressurize.water;
			flow from steamIn to steamPressurize.steam;
			flow from steamPressurize.pressurizedWater to discharge.pressurizedWater;
			flow from discharge.dischargedWater to waterOut;
		}

		part def SteamBoiler {
			attribute outputPressure : PressureValue;
			attribute outputTemperature : Real;
			port steamOutPort : SteamPort;
			perform action generateSteam : GenerateSteam;
		}

		part def CheckValve {
			attribute isOpen : Boolean;
			port valveInPort : ~WaterPort;
			port valveOutPort : WaterPort;
		}

		part def PumpChamber {
			attribute chamberVolume : VolumeValue;
			attribute waterLevel : VolumeValue;
			attribute internalPressure : PressureValue;
			attribute wallTemperature : Real;
			port steamInPort : ~SteamPort;
			port suctionPort : ~WaterPort;
			port dischargePort : WaterPort;
			port condensateOutPort : CondensatePort;

			part suctionValve : CheckValve;
			part dischargeValve : CheckValve;

			bind suctionValve.valveInPort = suctionPort;
			bind dischargeValve.valveOutPort = dischargePort;
			flow of water : Water
				from suctionValve.valveOutPort.water to dischargeValve.valveInPort.water;

			perform action pumpCycle : PumpCycle {
				in steamIn = steamInPort.steam;
				in waterIn = suctionPort.water;
				out waterOut = dischargePort.water;
				out condensateOut = condensateOutPort.condensate;
			}
		}

		part def PulsometerPump {
			attribute totalFlowRate : Real;
			port steamInPort : ~SteamPort;
			port suctionPort : ~WaterPort;
			port dischargePort : WaterPort;
			port condensateOutPort : CondensatePort;

			part chamberA : PumpChamber;
			part chamberB : PumpChamber;

			bind chamberA.steamInPort = steamInPort;
			bind chamberB.steamInPort = steamInPort;
			bind chamberA.suctionPort = suctionPort;
			bind chamberB.suctionPort = suctionPort;
			bind chamberA.dischargePort = dischargePort;
			bind chamberB.dischargePort = dischargePort;
			bind chamberA.condensateOutPort = condensateOutPort;
			bind chamberB.condensateOutPort = condensateOutPort;

			state pumpOperation {
				entry; then fillingA_dischargingB;
				state fillingA_dischargingB;
				transition from fillingA_dischargingB to dischargingA_fillingB
					when chamberA.waterLevel >= chamberA.chamberVolume;
				state dischargingA_fillingB;
				transition from dischargingA_fillingB to fillingA_dischargingB
					when chamberB.waterLevel >= chamberB.chamberVolume;
			}
		}

		part def WaterSource {
			attribute sourceVolume : VolumeValue;
			port waterOutPort : WaterPort;
		}

		part def DischargeTank {
			attribute tankCapacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			port waterInPort : ~WaterPort;
		}

		part def CondensateReceiver {
			attribute receiverCapacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			port condensateInPort : ~CondensatePort;
		}
	}

	package Usages {
		public import Definitions::*;

		part pulsometerSystem {
			part boiler : SteamBoiler {
				attribute :>> outputPressure = 500000 [Pa];
				attribute :>> outputTemperature = 425 [K];
				port :>> steamOutPort;
			}
			part pump : PulsometerPump {
				attribute :>> totalFlowRate = 0.01;
				port :>> steamInPort;
				port :>> suctionPort;
				port :>> dischargePort;
				port :>> condensateOutPort;
				part :>> chamberA : PumpChamber {
					attribute :>> chamberVolume = 0.05 [m3];
					attribute :>> waterLevel = 0 [m3];
					attribute :>> internalPressure = 101325 [Pa];
					attribute :>> wallTemperature = 293 [K];
					part :>> suctionValve : CheckValve {
						attribute :>> isOpen = true;
					}
					part :>> dischargeValve : CheckValve {
						attribute :>> isOpen = false;
					}
				}
				part :>> chamberB : PumpChamber {
					attribute :>> chamberVolume = 0.05 [m3];
					attribute :>> waterLevel = 0.05 [m3];
					attribute :>> internalPressure = 101325 [Pa];
					attribute :>> wallTemperature = 293 [K];
					part :>> suctionValve : CheckValve {
						attribute :>> isOpen = false;
					}
					part :>> dischargeValve : CheckValve {
						attribute :>> isOpen = true;
					}
				}
			}
			part waterSource : WaterSource {
				attribute :>> sourceVolume = 1000 [m3];
				port :>> waterOutPort;
			}
			part dischargeTank : DischargeTank {
				attribute :>> tankCapacity = 50 [m3];
				attribute :>> currentLevel = 0 [m3];
				port :>> waterInPort;
			}
			part condensateReceiver : CondensateReceiver {
				attribute :>> receiverCapacity = 10 [m3];
				attribute :>> currentLevel = 0 [m3];
				port :>> condensateInPort;
			}

			interface steamSupply : SteamSupplyInterface
				connect boiler.steamOutPort to pump.steamInPort;
			interface waterSupply : WaterSupplyInterface
				connect waterSource.waterOutPort to pump.suctionPort;
			interface waterDischarge : WaterDischargeInterface
				connect pump.dischargePort to dischargeTank.waterInPort;
			interface condensateReturn : CondensateReturnInterface
				connect pump.condensateOutPort to condensateReceiver.condensateInPort;

			flow of steam : Steam
				from boiler.steamOutPort.steam to pump.steamInPort.steam;
			flow of water : Water
				from waterSource.waterOutPort.water to pump.suctionPort.water;
			flow of water : Water
				from pump.dischargePort.water to dischargeTank.waterInPort.water;
			flow of condensate : Condensate
				from pump.condensateOutPort.condensate to condensateReceiver.condensateInPort.condensate;
		}
	}

	package Requirements {
		public import Definitions::*;
		public import Usages::*;

		requirement def MinFlowRateRequirement {
			doc /* The pump shall maintain a minimum discharge flow rate. */
			subject pump : PulsometerPump;
			attribute requiredFlowRate : Real;
			require constraint { pump.totalFlowRate >= requiredFlowRate }
		}

		requirement def SteamPressureRangeRequirement {
			doc /* The boiler shall supply steam within a defined pressure range. */
			subject boiler : SteamBoiler;
			attribute minPressure : PressureValue;
			attribute maxPressure : PressureValue;
			require constraint {
				boiler.outputPressure >= minPressure and
				boiler.outputPressure <= maxPressure
			}
		}

		requirement def AlternatingChamberOperationRequirement {
			doc /* The two chambers shall operate in alternating fill and discharge cycles. */
			subject pump : PulsometerPump;
			require constraint {
				(pump.chamberA.suctionValve.isOpen and pump.chamberB.dischargeValve.isOpen) or
				(pump.chamberB.suctionValve.isOpen and pump.chamberA.dischargeValve.isOpen)
			}
		}

		requirement def CondensateCollectionRequirement {
			doc /* The system shall collect condensed steam without overflow. */
			subject receiver : CondensateReceiver;
			require constraint { receiver.currentLevel <= receiver.receiverCapacity }
		}

		requirement def DischargeTankCapacityRequirement {
			doc /* The discharge tank shall not overflow during operation. */
			subject tank : DischargeTank;
			require constraint { tank.currentLevel <= tank.tankCapacity }
		}

		requirement systemPerformance {
			doc /* Overall system performance requirements. */
			subject ctx : pulsometerSystem;
			require minFlow : MinFlowRateRequirement {
				doc /* The pump shall maintain a minimum flow rate of 0.01 m3/s. */
				subject = ctx.pump;
				attribute :>> requiredFlowRate = 0.01;
			}
			require steamPressure : SteamPressureRangeRequirement {
				doc /* The boiler shall supply steam between 200 kPa and 800 kPa. */
				subject = ctx.boiler;
				attribute :>> minPressure = 200000 [Pa];
				attribute :>> maxPressure = 800000 [Pa];
			}
			require alternatingOperation : AlternatingChamberOperationRequirement {
				subject = ctx.pump;
			}
			require condensateCollection : CondensateCollectionRequirement {
				subject = ctx.condensateReceiver;
			}
			require dischargeCapacity : DischargeTankCapacityRequirement {
				subject = ctx.dischargeTank;
			}
		}
	}
}
