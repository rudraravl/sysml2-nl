package 'A.M. Bohnert Rice Plantation Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Water {
			attribute density : Real = 1000.0;
			attribute temperature : Real;
			attribute volume : Real;
		}
		
		attribute def VolumeFlowRateValue :> Real;
		attribute def PressureValue :> Real;
		attribute def PowerValue :> Real;
		attribute def LengthValue :> Real;
		attribute def RotationalSpeedValue :> Real;
		
		port def FluidPort {
			attribute pressure : PressureValue;
			attribute flowRate : VolumeFlowRateValue;
			out item fluid : Water;
		}
		
		port def PowerPort {
			attribute voltage : Real;
			attribute current : Real;
			attribute power : PowerValue;
		}
		
		part def AMBohnertRicePlantationPump {
			doc /* 
			 * A.M. Bohnert Rice Plantation Pump - centrifugal pump designed
			 * for agricultural irrigation in rice plantation operations.
			 */
			
			attribute pumpType : String = "Centrifugal";
			attribute manufacturer : String = "A.M. Bohnert";
			attribute nominalFlowRate : VolumeFlowRateValue = 1893.0;
			attribute maxHead : PressureValue = 30.0;
			attribute impellerDiameter : LengthValue = 0.305;
			attribute pumpEfficiency : Real = 0.75;
			attribute operatingSpeed : RotationalSpeedValue = 1750.0;
			
			port suctionPort : ~FluidPort;
			port dischargePort : FluidPort;
			port driveShaft {
				in attribute torque : Real;
				in attribute speed : RotationalSpeedValue;
			}
			
			part impeller {
				attribute diameter : LengthValue = impellerDiameter;
				attribute numberOfVanes : Integer = 6;
				attribute material : String = "Cast Iron";
			}
			
			part volute {
				attribute material : String = "Cast Iron";
			}
			
			part shaft {
				attribute diameter : LengthValue = 0.038;
				attribute material : String = "Stainless Steel 316";
			}
			
			part mechanicalSeal {
				attribute sealType : String = "Single Cartridge";
				attribute material : String = "Silicon Carbide";
			}
			
			part bearings[2] {
				attribute bearingType : String = "Ball Bearing";
				attribute lubrication : String = "Grease";
			}
			
			part casing {
				attribute material : String = "Cast Iron";
				attribute pressureRating : PressureValue = 1034.0;
			}
			
			perform action pumpFluid {
				in suctionFluid : Water = suctionPort.fluid;
				in shaftSpeed : RotationalSpeedValue = driveShaft.speed;
				out dischargeFluid : Water;
				
				first start;
				
				then action calculatePerformance {
					attribute actualFlowRate : VolumeFlowRateValue = nominalFlowRate * (shaftSpeed / operatingSpeed);
					attribute headDeveloped : PressureValue = maxHead * ((shaftSpeed / operatingSpeed) ** 2);
				}
				
				then action transferFluid {
					dischargeFluid = suctionFluid;
				}
				
				then done;
			}
			
			state pumpStates {
				entry; then off;
				
				state off;
				transition off_to_starting
					first off
					accept startCommand
					then starting;
				
				state starting;
				transition starting_to_running
					first starting
					accept speedReached
					then running;
				
				state running;
				transition running_to_stopping
					first running
					accept stopCommand
					then stopping;
				
				state stopping;
				transition stopping_to_off
					first stopping
					accept speedZero
					then off;
			}
		}
		
		part def ElectricMotor {
			attribute ratedPower : PowerValue = 7500.0;
			attribute efficiency : Real = 0.88;
			attribute operatingSpeed : RotationalSpeedValue = 1750.0;
			attribute voltage : Real = 480.0;
			
			port powerIn : ~PowerPort;
			port shaftOut {
				out attribute torque : Real;
				out attribute speed : RotationalSpeedValue;
			}
			
			perform action operateMotor {
				in electricPower : PowerValue = powerIn.power;
				out mechanicalPower : PowerValue = electricPower * efficiency;
				out outputSpeed : RotationalSpeedValue = operatingSpeed;
			}
		}
		
		part def SuctionPiping {
			attribute diameter : LengthValue = 0.254;
			attribute length : LengthValue = 5.0;
			attribute material : String = "PVC Schedule 40";
			
			port inlet : ~FluidPort;
			port outlet : FluidPort;
			
			part footValve {
				attribute valveType : String = "Check Valve";
				attribute size : LengthValue = 0.254;
			}
			
			part strainer {
				attribute meshSize : LengthValue = 0.003;
			}
		}
		
		part def DischargePiping {
			attribute diameter : LengthValue = 0.203;
			attribute length : LengthValue = 50.0;
			attribute material : String = "PVC Schedule 40";
			
			port inlet : ~FluidPort;
			port outlet : FluidPort;
			
			part checkValve {
				attribute valveType : String = "Swing Check";
				attribute size : LengthValue = 0.203;
			}
			
			part gateValve {
				attribute valveType : String = "Gate Valve";
				attribute size : LengthValue = 0.203;
				attribute position : Real = 1.0;
			}
		}
		
		part def WaterSource {
			attribute waterLevel : LengthValue = 2.0;
			attribute capacity : Real = 100000.0;
			
			port outletPort : FluidPort {
				attribute :>> pressure = 101325.0 - (waterLevel * 9810.0);
			}
			
			item storedWater : Water {
				attribute :>> volume = capacity;
			}
		}
		
		part def IrrigationField {
			attribute area : Real = 50000.0;
			attribute requiredFlowRate : VolumeFlowRateValue = 1700.0;
			attribute elevation : LengthValue = 25.0;
			
			port inletPort : ~FluidPort;
			
			part distributionNetwork {
				attribute numberOfLaterals : Integer = 20;
				attribute lateralSpacing : LengthValue = 15.0;
			}
		}
		
		part def ControlPanel {
			attribute voltage : Real = 480.0;
			attribute phases : Integer = 3;
			
			port powerSupply : ~PowerPort;
			port motorPower : PowerPort;
			
			part motorStarter {
				attribute starterType : String = "DOL Starter";
				attribute rating : PowerValue = 10000.0;
			}
			
			part overloadRelay {
				attribute tripCurrent : Real = 18.0;
			}
			
			part pressureSwitch {
				attribute cutInPressure : PressureValue = 103.4;
				attribute cutOutPressure : PressureValue = 310.3;
			}
			
			perform action controlPump {
				in systemPressure : PressureValue;
				out motorCommand : Boolean;
				
				first start;
				then merge controlLoop;
				
				then action monitorPressure {
					out currentPressure : PressureValue = systemPressure;
				}
				
				then decide;
					if monitorPressure.currentPressure < pressureSwitch.cutInPressure 
						then startMotor;
					if monitorPressure.currentPressure >= pressureSwitch.cutOutPressure 
						then stopMotor;
				
				action startMotor {
					motorCommand = true;
				}
				then controlLoop;
				
				action stopMotor {
					motorCommand = false;
				}
				then controlLoop;
			}
		}
		
		requirement def PumpingSystemRequirements {
			doc /* Requirements for the rice plantation pumping subsystem */
			
			requirement flowCapacityReq {
				doc /* The system shall deliver minimum flow to irrigation field */
				subject pumpingSystem : PumpingSubsystem;
				require constraint {
					pumpingSystem.pump.nominalFlowRate >= 1700.0
				}
			}
			
			requirement headRequirement {
				doc /* The system shall overcome elevation plus friction losses */
				subject pumpingSystem : PumpingSubsystem;
				require constraint {
					pumpingSystem.pump.maxHead >= 30.0
				}
			}
			
			requirement reliabilityReq {
				doc /* The pump shall operate continuously for irrigation season */
				subject pump : AMBohnertRicePlantationPump;
				require constraint {
					pump.mechanicalSeal.sealType == "Single Cartridge" &
					pump.bearings.lubrication == "Grease"
				}
			}
			
			requirement materialCompatibilityReq {
				doc /* All wetted parts shall resist corrosion from agricultural water */
				subject pump : AMBohnertRicePlantationPump;
				require constraint {
					pump.shaft.material == "Stainless Steel 316" &
					pump.mechanicalSeal.material == "Silicon Carbide"
				}
			}
		}
		
		part def PumpingSubsystem {
			part pump : AMBohnertRicePlantationPump;
		}
	}
	
	package Usages {
		part pumpingSubsystem : PumpingSubsystem {
			
			part waterSource : WaterSource;
			
			part suctionPipe : SuctionPiping;
			
			flow of water : Water
				from waterSource.outletPort.fluid to suctionPipe.inlet.fluid;
			
			part pump : AMBohnertRicePlantationPump;
			
			flow of water : Water
				from suctionPipe.outlet.fluid to pump.suctionPort.fluid;
			
			part dischargePipe : DischargePiping;
			
			flow of water : Water
				from pump.dischargePort.fluid to dischargePipe.inlet.fluid;
			
			part irrigationField : IrrigationField;
			
			flow of water : Water
				from dischargePipe.outlet.fluid to irrigationField.inletPort.fluid;
			
			part motor : ElectricMotor;
			
			connect motor.shaftOut to pump.driveShaft;
			
			part controlPanel : ControlPanel;
			
			connect controlPanel.motorPower to motor.powerIn;
			
			bind controlPanel.controlPump.systemPressure = pump.dischargePort.pressure;
			
			satisfy pumpingRequirements : PumpingSystemRequirements by pumpingSubsystem;
			
			perform action operateSystem {
				first start;
				
				then action initializeSystem {
					dischargePipe.gateValve.position = 1.0;
				}
				
				then merge operationLoop;
				
				then action monitorAndControl : controlPanel.controlPump {
					in systemPressure = pump.dischargePort.pressure;
					out motorCommand;
				}
				
				then decide;
					if monitorAndControl.motorCommand == true then pumpWater;
					if monitorAndControl.motorCommand == false then idle;
				
				action pumpWater {
					first action runMotor : motor.operateMotor;
					then action pumpFluid : pump.pumpFluid {
						in shaftSpeed = motor.operatingSpeed;
					}
				}
				then operationLoop;
				
				action idle;
				then operationLoop;
			}
		}
	}
}
