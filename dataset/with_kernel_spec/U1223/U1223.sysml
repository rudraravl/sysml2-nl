package DiamondLaserSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;
	private import ScalarValues::Integer;

	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		item def EnableCommand;
		item def DisableCommand;
		item def EmergencyCommand;

		item def ElectricalPower {
			attribute voltage : ElectricPotentialValue;
			attribute current : ElectricCurrentValue;
		}
		item def PumpLight {
			attribute wavelength : LengthValue = 808 [nm];
			attribute power : PowerValue;
		}
		item def LaserBeam {
			attribute wavelength : LengthValue = 1064 [nm];
			attribute power : PowerValue;
		}
		item def CoolantFluid {
			attribute temperature : TemperatureValue;
			attribute flowRate : Real;
		}
		item def Heat;

		port def ElectricalInPort {
			in item power : ElectricalPower;
		}
		port def ElectricalOutPort {
			out item power : ElectricalPower;
		}
		port def OpticalPort {
			in item inLight : PumpLight;
			in item inBeam : LaserBeam;
			out item outLight : PumpLight;
			out item outBeam : LaserBeam;
		}
		port def CoolantPort {
			out item fluidOut : CoolantFluid;
			in item fluidIn : CoolantFluid;
		}
		port def ThermalPort {
			out item heat : Heat;
		}
		port def CommandPort {
			in item enable : EnableCommand;
			in item disable : DisableCommand;
			in item emergency : EmergencyCommand;
			out attribute status : String;
		}
		port def SensorPort {
			out attribute tempReading : TemperatureValue;
		}
		port def BooleanInPort {
			in attribute value : Boolean;
		}
		port def BooleanOutPort {
			out attribute value : Boolean;
		}
		port def RealInPort {
			in attribute value : Real;
		}
		port def RealOutPort {
			out attribute value : Real;
		}

		action def ConvertPower {
			in item inPower : ElectricalPower;
			out item outPower : ElectricalPower;
		}
		action def EmitPumpLight {
			in item inPower : ElectricalPower;
			out item outLight : PumpLight;
		}
		action def AmplifyLight {
			in item inLight : PumpLight;
			out item outBeam : LaserBeam;
			out item wasteHeat : Heat;
		}
		action def CirculateCoolant {
			in item heat : Heat;
			out item cooledFluid : CoolantFluid;
			in item returnFluid : CoolantFluid;
		}
		action def EnablePumpArray;
		action def DisablePumpArray;
		action def EnableCoolant;
		action def DisableCoolant;
		action def EmergencyShutdownAction;

		part def PowerSupplyUnit {
			port mainIn : ElectricalInPort;
			port hvOut : ElectricalOutPort;
			port enable : BooleanInPort;
			perform action convert : ConvertPower {
				in inPower = mainIn.power;
				out outPower = hvOut.power;
			}
		}

		part def DiodePump {
			port elecIn : ElectricalInPort;
			port lightOut : OpticalPort;
			perform action emit : EmitPumpLight {
				in inPower = elecIn.power;
				out outLight = lightOut.outLight;
			}
		}

		part def DiodePumpArray {
			port elecIn : ElectricalInPort;
			port lightOut : OpticalPort;
			port enable : BooleanInPort;
			part diodes[24] : DiodePump;
		}

		part def SyntheticDiamond {
			port pumpIn : OpticalPort;
			port beamOut : OpticalPort;
			port thermalOut : ThermalPort;
			port coolantIn : CoolantPort;
			attribute temperature : TemperatureValue;
			attribute thermalConductivity : Real = 2000;
			perform action amplify : AmplifyLight {
				in inLight = pumpIn.inLight;
				out outBeam = beamOut.outBeam;
				out wasteHeat = thermalOut.heat;
			}
		}

		part def ResonatorMirror {
			port optical : OpticalPort;
			attribute reflectivity : Real;
		}

		part def Resonator {
			port pumpIn : OpticalPort;
			port beamOut : OpticalPort;
			part diamond : SyntheticDiamond;
			part highReflector : ResonatorMirror {
				attribute reflectivity = 0.999;
			}
			part outputCoupler : ResonatorMirror {
				attribute reflectivity = 0.5;
			}
			flow of pumpLight : PumpLight
				from pumpIn.inLight to diamond.pumpIn.inLight;
			flow of internalBeam1 : LaserBeam
				from diamond.beamOut.outBeam to highReflector.optical.inBeam;
			flow of internalBeam2 : LaserBeam
				from highReflector.optical.outBeam to diamond.pumpIn.inBeam;
			flow of internalBeam3 : LaserBeam
				from diamond.beamOut.outBeam to outputCoupler.optical.inBeam;
			flow of outputBeam : LaserBeam
				from outputCoupler.optical.outBeam to beamOut.outBeam;
		}

		part def ThermalManagementSystem {
			port coolantOut : CoolantPort;
			port coolantIn : CoolantPort;
			port thermalIn : ThermalPort;
			port flowRateCmd : RealInPort;
			perform action circulate : CirculateCoolant {
				in heat = thermalIn.heat;
				out cooledFluid = coolantOut.fluidOut;
				in returnFluid = coolantIn.fluidIn;
			}
		}

		part def TemperatureSensor {
			port thermalIn : ThermalPort;
			port dataOut : SensorPort;
		}

		part def LaserController {
			port command : CommandPort;
			port sensorIn : SensorPort;
			port pumpEnable : BooleanOutPort;
			port coolantFlowCmd : RealOutPort;
			port psuEnable : BooleanOutPort;
			attribute tempReading : TemperatureValue;

			state controllerBehavior {
				entry;
					then standby;
				state standby;
				transition t1 first standby
					accept EnableCommand via command
					then warmup;
				state warmup {
					do action {
						action enablePump : EnablePumpArray;
						action enableCoolant : EnableCoolant;
					}
				}
				transition t2 first warmup
					if tempReading >= 50 [K]
					then active;
				state active {
					do action maintainCoolant : EnableCoolant;
				}
				transition t3 first active
					accept DisableCommand via command
					then cooldown;
				transition t4 first active
					if tempReading > 80 [K]
					then emergencyShutdown;
				state cooldown {
					do action {
						action disablePump : DisablePumpArray;
						action enableCoolant : EnableCoolant;
					}
				}
				transition t5 first cooldown
					if tempReading <= 30 [K]
					then standby;
				state emergencyShutdown {
					do action {
						action shutdown : EmergencyShutdownAction;
						action disablePump : DisablePumpArray;
						action enableCoolant : EnableCoolant;
					}
				}
				transition t6 first emergencyShutdown
					accept DisableCommand via command
					then standby;
			}
		}

		part def LaserSystem {
			port beamOut : OpticalPort;

			part psu : PowerSupplyUnit;
			part pumpArray : DiodePumpArray;
			part resonator : Resonator;
			part tms : ThermalManagementSystem;
			part tempSensor : TemperatureSensor;
			part controller : LaserController;

			flow of power : ElectricalPower
				from psu.hvOut.power to pumpArray.elecIn.power;
			flow of pumpLight : PumpLight
				from pumpArray.lightOut.outLight to resonator.pumpIn.inLight;
			flow of outputBeam : LaserBeam
				from resonator.beamOut.outBeam to beamOut.outBeam;

			flow of heat : Heat
				from resonator.diamond.thermalOut.heat to tms.thermalIn.heat;
			flow of heatToSensor : Heat
				from resonator.diamond.thermalOut.heat to tempSensor.thermalIn.heat;

			flow of coolantSupply : CoolantFluid
				from tms.coolantOut.fluidOut to resonator.diamond.coolantIn.fluidIn;
			flow of coolantReturn : CoolantFluid
				from resonator.diamond.coolantIn.fluidOut to tms.coolantIn.fluidIn;

			bind controller.tempReading = tempSensor.dataOut.tempReading;
			bind pumpArray.enable.value = controller.pumpEnable.value;
			bind psu.enable.value = controller.psuEnable.value;
			bind tms.flowRateCmd.value = controller.coolantFlowCmd.value;
		}
	}

	package Usages {
		private import Definitions::*;

		part laserSystem : LaserSystem;
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def LaserSystemSpec {
			subject laserSystem : LaserSystem;
			requirement powerOutput {
				constraint { laserSystem.beamOut.outBeam.power >= 10000 [W] }
				constraint { laserSystem.beamOut.outBeam.wavelength == 1064 [nm] }
			}
			requirement thermalStability {
				constraint { laserSystem.resonator.diamond.temperature <= 80 [K] }
			}
			requirement pumpCount {
				constraint { laserSystem.pumpArray.diodes->size() == 24 }
			}
			requirement diamondGainMedium {
				constraint { laserSystem.resonator.diamond.thermalConductivity >= 1800 }
			}
			requirement emergencyResponse {
				constraint { laserSystem.controller.tempReading <= 80 [K] }
			}
		}
	}
}
