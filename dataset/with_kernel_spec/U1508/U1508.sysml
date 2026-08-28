package 'Steam Powered Water Pump' {
	private import ScalarValues::*;
	private import ISQ::*;

	public import Definitions::*;

	package Definitions {
		alias Pressure for ISQ::PressureValue;
		alias Temperature for ISQ::TemperatureValue;
		alias VolumetricFlowRate for ISQ::VolumeFlowRateValue;
		alias Power for ISQ::PowerValue;

		item def Steam {
			attribute pressure : Pressure;
			attribute temperature : Temperature;
		}
		item def Water {
			attribute pressure : Pressure;
			attribute temperature : Temperature;
			attribute flowRate : VolumetricFlowRate;
		}
		item def MechanicalPower {
			attribute power : Power;
		}

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def EmergencyCommand;
		attribute def ResetCommand;
		attribute def HighDemand;
		attribute def NormalDemand;
		attribute def LowDemand;
		attribute def CylinderReady;
		attribute def ShutdownComplete;

		part def SteamBoiler {
			out steamPort : Steam;
		}
		part def SteamCylinder {
			in steamPort : Steam;
			out exhaustPort : Steam;
			out mechanicalPowerPort : MechanicalPower;
		}
		part def ReciprocatingPump {
			in mechanicalPowerPort : MechanicalPower;
			in suctionPort : Water;
			out dischargePort : Water;
		}
		part def CheckValve {
			in inlet : Water;
			out outlet : Water;
		}
		part def Condenser {
			in exhaustPort : Steam;
			out dischargePort : Water;
		}
		part def SafetyValve {
			in pressurePort : Steam;
		}
		part def SteamPressureGauge {
			in pressurePort : Steam;
			out reading : Pressure;
		}
		part def WaterPressureGauge {
			in pressurePort : Water;
			out reading : Pressure;
		}
		part def FlowMeter {
			in flowPort : Water;
			out flowRate : VolumetricFlowRate;
		}
		part def PumpController {
			exhibit state pumpStates : PumpStates;
		}

		action def GenerateSteam { out steam : Steam; }
		action def DrivePiston { in steam : Steam; out exhaust : Steam; out power : MechanicalPower; }
		action def PumpWater { in power : MechanicalPower; in suction : Water; out discharge : Water; }
		action def CondenseExhaust { in exhaust : Steam; out water : Water; }
		action def RegulateSteamFlow;
		action def CutOffSteam;

		state def PumpStates;
	}

	package Usages {
		private import Definitions::*;

		action 'generate steam' : GenerateSteam;
		action 'drive piston' : DrivePiston;
		action 'pump water' : PumpWater;
		action 'condense exhaust' : CondenseExhaust;
		action 'regulate steam flow' : RegulateSteamFlow;
		action 'cut off steam' : CutOffSteam;

		part steamPumpSystem {
			part boiler : SteamBoiler;
			part cylinder : SteamCylinder;
			part pump : ReciprocatingPump;
			part suctionValve : CheckValve;
			part dischargeValve : CheckValve;
			part condenser : Condenser;
			part safetyValve : SafetyValve;
			part steamPressureGauge : SteamPressureGauge;
			part dischargePressureGauge : WaterPressureGauge;
			part flowMeter : FlowMeter;
			part controller : PumpController {
				exhibit state pumpStates : PumpStates {
					entry; then stopped;

					state stopped;
					accept StartCommand then starting;

					state starting {
						entry 'generate steam';
						do 'drive piston';
					}
					accept CylinderReady then operating;

					state operating {
						entry; then normal;

						state normal {
							entry 'regulate steam flow';
							do 'pump water';
						}
						accept HighDemand then high;
						accept LowDemand then low;

						state high {
							entry 'regulate steam flow';
							do 'pump water';
						}
						accept NormalDemand then normal;
						accept LowDemand then low;

						state low {
							entry 'regulate steam flow';
							do 'pump water';
						}
						accept NormalDemand then normal;
						accept HighDemand then high;
					}
					accept StopCommand then stopping;
					accept EmergencyCommand then emergency;

					state stopping {
						entry 'condense exhaust';
					}
					accept ShutdownComplete then stopped;

					state emergency {
						entry 'cut off steam';
					}
					accept ResetCommand then stopped;
				}
			}

			flow boiler.steamPort to cylinder.steamPort;
			flow cylinder.exhaustPort to condenser.exhaustPort;
			flow cylinder.mechanicalPowerPort to pump.mechanicalPowerPort;
			flow suctionValve.outlet to pump.suctionPort;
			flow pump.dischargePort to dischargeValve.inlet;
			flow dischargeValve.outlet to flowMeter.flowPort;
			flow dischargeValve.outlet to dischargePressureGauge.pressurePort;
			flow boiler.steamPort to safetyValve.pressurePort;
			flow boiler.steamPort to steamPressureGauge.pressurePort;
		}

		requirement 'Safe Pressure Relief' {
			doc /* The system shall automatically release steam pressure via the safety valve if the boiler pressure exceeds a critical threshold. */
		}
		requirement 'One-Way Water Flow' {
			doc /* The suction and discharge check valves shall ensure water flows in only one direction from the source to the destination. */
		}
		requirement 'Continuous Operation' {
			doc /* The system shall provide continuous pumping action during the operating state, converting steam energy into mechanical work to move water. */
		}
		requirement 'Emergency Shutdown' {
			doc /* Upon an emergency stop signal, the system shall immediately cut off steam flow and enter a safe emergency state. */
		}
	}
}
