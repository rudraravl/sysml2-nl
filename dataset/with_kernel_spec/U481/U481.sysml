package 'Industrial Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		alias VolumeValue for ISQ::VolumeValue;
		alias VolumeFlowRateValue for ISQ::VolumeFlowRateValue;
		alias PressureValue for ISQ::PressureValue;
		alias PowerValue for ISQ::PowerValue;
		alias TorqueValue for ISQ::TorqueValue;
		alias LengthValue for ISQ::LengthValue;
		alias ElectricPotentialValue for ISQ::ElectricPotentialValue;

		attribute def 'Rotational Speed' :> Real {
			doc /* revolutions per minute (rpm) */
		}

		attribute def 'Efficiency' :> Real {
			doc /* dimensionless, range 0..1 */
		}

		attribute def 'Start Cmd' :> Boolean;
		attribute def 'Stop Cmd' :> Boolean;
		attribute def 'Speed Setpoint' :> 'Rotational Speed';

		enum def 'Pump Status' {
			enum stopped;
			enum starting;
			enum running;
			enum faulted;
		}

		item def 'Fluid';
		item def 'Solid Matter';

		item def 'Slurry' {
			item base : 'Fluid';
			item solids : 'Solid Matter';
			attribute volume : VolumeValue;
			attribute solidsConcentration : Real;
		}

		port def 'Fluid Port' {
			out item fluid : 'Slurry';
		}

		port def 'Power Port' {
			out attribute power : PowerValue;
		}

		port def 'Mechanical Drive Port' {
			out attribute torque : TorqueValue;
			out attribute rotationalSpeed : 'Rotational Speed';
		}

		port def 'Command Port' {
			out attribute startCmd : 'Start Cmd';
			out attribute stopCmd : 'Stop Cmd';
			out attribute speedSetpoint : 'Speed Setpoint';
		}

		port def 'Status Port' {
			out attribute actualSpeed : 'Rotational Speed';
			out attribute status : 'Pump Status';
		}

		part def 'Source Reservoir' {
			port fluidOutPort : 'Fluid Port';
			attribute initialVolume : VolumeValue;
			attribute fluidLevel : VolumeValue;
			item slurry : 'Slurry';
		}

		part def 'Suction Pipe' {
			port fluidInPort : ~'Fluid Port';
			port fluidOutPort : 'Fluid Port';
			attribute length : LengthValue;
			attribute diameter : LengthValue;
		}

		part def 'Discharge Pipe' {
			port fluidInPort : ~'Fluid Port';
			port fluidOutPort : 'Fluid Port';
			attribute length : LengthValue;
			attribute diameter : LengthValue;
		}

		part def 'Destination Vessel' {
			port fluidInPort : ~'Fluid Port';
			attribute maxCapacity : VolumeValue;
			attribute fluidLevel : VolumeValue;
			item slurry : 'Slurry';
		}

		part def 'Electric Motor' {
			port powerInPort : ~'Power Port';
			port driveOutPort : 'Mechanical Drive Port';
			attribute ratedPower : PowerValue = 15;
			attribute ratedSpeed : 'Rotational Speed' = 1450;
			attribute supplyVoltage : ElectricPotentialValue;
			attribute efficiency : 'Efficiency' = 0.9;
		}

		part def 'Chopper Impeller' {
			port driveInPort : ~'Mechanical Drive Port';
			port fluidInPort : ~'Fluid Port';
			port fluidOutPort : 'Fluid Port';
			attribute numBlades : Integer = 4;
			attribute material : String = "Stainless Steel";
			attribute operatingSpeed : 'Rotational Speed' = 1450;
		}

		part def 'Pump Casing' {
			port fluidInPort : ~'Fluid Port';
			port fluidOutPort : 'Fluid Port';
			attribute material : String = "Stainless Steel";
			attribute maxPressure : PressureValue = 10;
			attribute inletPressure : PressureValue;
			attribute outletPressure : PressureValue;
		}

		part def 'Electrical Power Source' {
			port powerOutPort : 'Power Port';
			attribute supplyVoltage : ElectricPotentialValue = 400;
			attribute supplyFrequency : Real = 50;
		}

		part def 'Control Interface' {
			port commandOutPort : 'Command Port';
			port statusInPort : ~'Status Port';
			attribute operatorInput : String;
			attribute desiredSpeed : 'Rotational Speed' = 1450;
		}

		action def 'Macerate Solids' {
			in slurryIn : 'Slurry';
			in speed : 'Rotational Speed';
			out slurryMacerated : 'Slurry';
		}

		action def 'Pressurize Fluid' {
			in slurryIn : 'Slurry';
			in speed : 'Rotational Speed';
			out slurryPressurized : 'Slurry';
		}

		action def 'Operate Pump' {
			in startCmd : 'Start Cmd';
			in stopCmd : 'Stop Cmd';
			in speedSetpoint : 'Speed Setpoint';
			in slurryIn : 'Slurry';
			out slurryOut : 'Slurry';

			loop {
				accept start : 'Start Cmd';
				then action {
					action 'macerate solids' : 'Macerate Solids' {
						in slurryIn = slurryIn;
						in speed = speedSetpoint;
						out slurryMacerated;
					}
					action 'pressurize fluid' : 'Pressurize Fluid' {
						in slurryIn = 'macerate solids'.slurryMacerated;
						in speed = speedSetpoint;
						out slurryPressurized;
					}
					flow 'pressurize fluid'.slurryPressurized to slurryOut;
				}
				then accept stop : 'Stop Cmd';
			}
		}

		part def 'Chopper Pump' {
			port fluidInPort : ~'Fluid Port';
			port fluidOutPort : 'Fluid Port';
			port powerInPort : ~'Power Port';
			port commandInPort : ~'Command Port';
			port statusOutPort : 'Status Port';

			attribute nominalFlowRate : VolumeFlowRateValue = 100;
			attribute nominalPressure : PressureValue = 10;
			attribute efficiency : 'Efficiency';
			attribute actualFlowRate : VolumeFlowRateValue;
			attribute actualPressure : PressureValue;
			attribute actualSpeed : 'Rotational Speed';

			part motor : 'Electric Motor';
			part impeller : 'Chopper Impeller';
			part casing : 'Pump Casing';

			connect powerInPort to motor.powerInPort;
			connect motor.driveOutPort to impeller.driveInPort;

			flow of slurry : 'Slurry'
				from fluidInPort.fluid to impeller.fluidInPort.fluid;
			flow of slurry : 'Slurry'
				from impeller.fluidOutPort.fluid to casing.fluidInPort.fluid;
			flow of slurry : 'Slurry'
				from casing.fluidOutPort.fluid to fluidOutPort.fluid;

			perform action 'operate pump' : 'Operate Pump' {
				in startCmd = commandInPort.startCmd;
				in stopCmd = commandInPort.stopCmd;
				in speedSetpoint = commandInPort.speedSetpoint;
				in slurryIn = fluidInPort.fluid;
				out slurryOut = fluidOutPort.fluid;
			}

			state machine pumpControl {
				state idle;
				state starting;
				state running;
				state faulted;
				transition from idle to starting when commandInPort.startCmd;
				transition from starting to running when actualSpeed >= commandInPort.speedSetpoint;
				transition from running to idle when commandInPort.stopCmd;
				transition from running to faulted when actualPressure > casing.maxPressure;
				transition from faulted to idle when commandInPort.stopCmd;
			}
		}

		requirement def 'Minimum Flow Rate Requirement' {
			subject pump : 'Chopper Pump';
			constraint { pump.actualFlowRate >= 100 }
		}

		requirement def 'Maximum Discharge Pressure Requirement' {
			subject pump : 'Chopper Pump';
			constraint { pump.actualPressure <= 10 }
		}

		requirement def 'High Energy Efficiency Requirement' {
			subject pump : 'Chopper Pump';
			constraint { pump.efficiency >= 0.75 }
		}

		requirement def 'Impeller Blade Count Requirement' {
			subject pump : 'Chopper Pump';
			constraint { pump.impeller.numBlades == 4 }
		}

		requirement def 'Casing Material Requirement' {
			subject pump : 'Chopper Pump';
			constraint { pump.casing.material == "Stainless Steel" }
		}

		requirement def 'Casing Pressure Rating Requirement' {
			subject pump : 'Chopper Pump';
			constraint { pump.casing.maxPressure >= 10 }
		}
	}

	package Usages {
		private import Definitions::*;

		part 'Pumping System Context' {
			part sourceReservoir : 'Source Reservoir' {
				attribute redefines initialVolume = 5000;
				attribute redefines fluidLevel = 4000;
			}

			part suctionPipe : 'Suction Pipe' {
				attribute redefines length = 2;
				attribute redefines diameter = 0.1;
			}

			part chopperPump : 'Chopper Pump' {
				attribute redefines efficiency = 0.85;
				attribute redefines actualFlowRate = 120;
				attribute redefines actualPressure = 9.5;
				attribute redefines actualSpeed = 1450;
			}

			part dischargePipe : 'Discharge Pipe' {
				attribute redefines length = 5;
				attribute redefines diameter = 0.08;
			}

			part destinationVessel : 'Destination Vessel' {
				attribute redefines maxCapacity = 8000;
				attribute redefines fluidLevel = 1000;
			}

			part controlInterface : 'Control Interface' {
				attribute redefines desiredSpeed = 1450;
			}

			part powerSupply : 'Electrical Power Source';

			flow of slurry : 'Slurry'
				from sourceReservoir.fluidOutPort.fluid to suctionPipe.fluidInPort.fluid;
			flow of slurry : 'Slurry'
				from suctionPipe.fluidOutPort.fluid to chopperPump.fluidInPort.fluid;
			flow of slurry : 'Slurry'
				from chopperPump.fluidOutPort.fluid to dischargePipe.fluidInPort.fluid;
			flow of slurry : 'Slurry'
				from dischargePipe.fluidOutPort.fluid to destinationVessel.fluidInPort.fluid;

			connect controlInterface.commandOutPort to chopperPump.commandInPort;
			connect chopperPump.statusOutPort to controlInterface.statusInPort;
			connect powerSupply.powerOutPort to chopperPump.powerInPort;
		}

		requirement 'minFlowReq' : 'Minimum Flow Rate Requirement';
		requirement 'maxPressureReq' : 'Maximum Discharge Pressure Requirement';
		requirement 'efficiencyReq' : 'High Energy Efficiency Requirement';
		requirement 'bladeCountReq' : 'Impeller Blade Count Requirement';
		requirement 'casingMaterialReq' : 'Casing Material Requirement';
		requirement 'casingPressureReq' : 'Casing Pressure Rating Requirement';

		satisfy 'minFlowReq' by 'Pumping System Context'::chopperPump;
		satisfy 'maxPressureReq' by 'Pumping System Context'::chopperPump;
		satisfy 'efficiencyReq' by 'Pumping System Context'::chopperPump;
		satisfy 'bladeCountReq' by 'Pumping System Context'::chopperPump;
		satisfy 'casingMaterialReq' by 'Pumping System Context'::chopperPump;
		satisfy 'casingPressureReq' by 'Pumping System Context'::chopperPump;
	}
}
