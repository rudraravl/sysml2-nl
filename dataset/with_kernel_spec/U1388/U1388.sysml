package BrineProcessingSystem {
	private import SI::s;
	private import ScalarValues::*;

	package Definitions {
		unit g_per_L;

		attribute def TemperatureValue :> Real;
		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;

		item def Brine {
			attribute temperature : TemperatureValue;
			attribute salinity : Real [g_per_L];
		}
		item def HotBrine :> Brine;
		item def Vapor {
			attribute temperature : TemperatureValue;
			attribute pressure : PressureValue;
		}
		item def FreshWater {
			attribute salinity : Real [g_per_L];
		}
		item def ConcentratedBrine :> Brine;

		item def StartSignal;
		item def ShutdownSignal;
		item def TempReached;
		item def TempCommand {
			attribute targetTemp : TemperatureValue;
		}
		item def TempReading {
			attribute temperature : TemperatureValue;
		}
		item def SalinityReading {
			attribute salinity : Real [g_per_L];
		}

		action def StartUpSequence;
		action def HeatUpSequence;
		action def EvaporateAction;
		action def ConcentrateAction;
		action def ShutdownSequence;
		action def CoolDownAction;

		part def FeedTank {
			port brineOutPort {
				out brine : Brine;
			}
			attribute capacity : Real = 5000;
		}
		part def CirculationPump {
			port brineInPort {
				in brine : Brine;
			}
			port brineOutPort {
				out brine : Brine;
			}
			port samplePort {
				out brineSample : Brine;
			}
			attribute flowRate : FlowRateValue = 50;
		}
		part def PreHeater {
			port brineInPort {
				in brine : Brine;
			}
			port brineOutPort {
				out hotBrine : HotBrine;
			}
			port tempCmdPort {
				in tempCmd : TempCommand;
			}
			port tempReadingPort {
				out tempReading : TempReading;
			}
			attribute outletTemp : TemperatureValue = 85;
		}
		part def EvaporationUnit {
			port brineInPort {
				in hotBrine : HotBrine;
			}
			port vaporOutPort {
				out vapor : Vapor;
			}
			port concentrateOutPort {
				out concentrate : ConcentratedBrine;
			}
			attribute operatingTemp : TemperatureValue = 100;
			attribute operatingPressure : PressureValue = 1;
		}
		part def Condenser {
			port vaporInPort {
				in vapor : Vapor;
			}
			port freshWaterOutPort {
				out freshWater : FreshWater;
			}
		}
		part def ProductTank {
			port freshWaterInPort {
				in freshWater : FreshWater;
			}
			attribute storedVolume : Real;
		}
		part def ConcentrateTank {
			port concentrateInPort {
				in concentrate : ConcentratedBrine;
			}
			attribute storedVolume : Real;
		}
		part def TemperatureController {
			port tempCmdPort {
				out tempCmd : TempCommand;
			}
			port tempReadingPort {
				in tempReading : TempReading;
			}
			port salinityPort {
				in salinityReading : SalinityReading;
			}
		}
		part def SalinityMonitor {
			port salinityPort {
				out salinityReading : SalinityReading;
			}
			port brineSamplePort {
				in brine : Brine;
			}
		}

		part def BrineSystem {
			port startPort {
				in startSignal : StartSignal;
			}
			port shutdownPort {
				in shutdownSignal : ShutdownSignal;
			}

			attribute targetTemperature : TemperatureValue = 85;

			part feedTank : FeedTank;
			part circulationPump : CirculationPump;
			part preHeater : PreHeater;
			part evaporationUnit : EvaporationUnit;
			part condenser : Condenser;
			part productTank : ProductTank;
			part concentrateTank : ConcentrateTank;
			part temperatureController : TemperatureController;
			part salinityMonitor : SalinityMonitor;

			flow brineFlow of Brine
				from feedTank.brineOutPort.brine to circulationPump.brineInPort.brine;
			flow pumpedBrineFlow of Brine
				from circulationPump.brineOutPort.brine to preHeater.brineInPort.brine;
			flow hotBrineFlow of HotBrine
				from preHeater.brineOutPort.hotBrine to evaporationUnit.brineInPort.hotBrine;
			flow vaporFlow of Vapor
				from evaporationUnit.vaporOutPort.vapor to condenser.vaporInPort.vapor;
			flow freshWaterFlow of FreshWater
				from condenser.freshWaterOutPort.freshWater to productTank.freshWaterInPort.freshWater;
			flow concentrateFlow of ConcentratedBrine
				from evaporationUnit.concentrateOutPort.concentrate to concentrateTank.concentrateInPort.concentrate;
			flow tempCmdFlow of TempCommand
				from temperatureController.tempCmdPort.tempCmd to preHeater.tempCmdPort.tempCmd;
			flow tempReadingFlow of TempReading
				from preHeater.tempReadingPort.tempReading to temperatureController.tempReadingPort.tempReading;
			flow salinityReadingFlow of SalinityReading
				from salinityMonitor.salinityPort.salinityReading to temperatureController.salinityPort.salinityReading;
			flow brineSampleFlow of Brine
				from circulationPump.samplePort.brineSample to salinityMonitor.brineSamplePort.brine;

			state BrineSystemBehavior {
				entry; then standby;

				state standby;
				accept StartSignal via startPort
					then startup;

				state startup {
					entry action startUpAction : StartUpSequence {
						/* Initialize circulation pump and open feed valves */
					}
				}
				accept after 30 [s]
					then heating;

				state heating {
					entry action heatUpAction : HeatUpSequence {
						/* Activate pre-heater to reach target temperature of 85 degrees Celsius */
					}
				}
				accept TempReached
					then operating;

				state operating parallel {
					state evaporating {
						do action evaporateAction : EvaporateAction {
							/* Boil brine to separate water vapor from dissolved salts */
						}
					}
					state concentrating {
						do action concentrateAction : ConcentrateAction {
							/* Collect concentrated brine solution */
						}
					}
				}
				accept ShutdownSignal via shutdownPort
					then shutdown;

				state shutdown {
					entry action shutdownAction : ShutdownSequence {
						/* Initiate controlled shutdown sequence */
					}
					do action coolDownAction : CoolDownAction {
						/* Cool system components safely */
					}
				}
				accept after 120 [s]
					then standby;
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part brineSystem : BrineSystem;

		requirement def FreshWaterQualityRequirement {
			doc
			/* The fresh water produced must have a salinity less than 1 g/L. */
			subject freshWater : FreshWater;
			constraint { freshWater.salinity < 1 [g_per_L] }
		}

		requirement def ConcentrateQualityRequirement {
			doc
			/* The concentrated brine must have a salinity of at least 200 g/L. */
			subject concentrate : ConcentratedBrine;
			constraint { concentrate.salinity >= 200 [g_per_L] }
		}

		requirement def PreHeaterTempRequirement {
			doc
			/* The pre-heater must raise brine temperature to approximately 85 degrees Celsius. */
			subject preHeater : PreHeater;
			constraint { preHeater.outletTemp == 85 }
		}

		requirement freshWaterQuality : FreshWaterQualityRequirement;
		requirement concentrateQuality : ConcentrateQualityRequirement;
		requirement preHeaterTemp : PreHeaterTempRequirement;
	}
}
