package 'Plunger Pump Subsystem' {
	private import ScalarValues::*;
	
	package Definitions {
		attribute def PressureValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def LengthValue :> Real;
		attribute def FrequencyValue :> Real;
		attribute def ForceValue :> Real;
		attribute def TemperatureValue :> Real;
		
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : TemperatureValue;
			attribute pressure : PressureValue;
			attribute volume : VolumeValue;
		}
		
		port def FluidPort {
			attribute portPressure : PressureValue;
			attribute portTemperature : TemperatureValue;
			out item fluidOut : Fluid;
			in item fluidIn : Fluid;
		}
		
		port def FluidInletPort :> FluidPort {
			in item :>> fluidIn;
		}
		
		port def FluidOutletPort :> FluidPort {
			out item :>> fluidOut;
		}
		
		part def CheckValve {
			port inlet : FluidInletPort;
			port outlet : FluidOutletPort;
			attribute crackingPressure : PressureValue;
			attribute valveState : Boolean = false;
		}
		
		part def Plunger {
			attribute diameter : LengthValue;
			attribute strokeLength : LengthValue;
			attribute currentPosition : LengthValue;
			attribute velocity : Real;
			attribute appliedForce : ForceValue;
			attribute area : Real;
		}
		
		part def PumpChamber {
			port inlet : FluidInletPort;
			port outlet : FluidOutletPort;
			attribute currentVolume : VolumeValue;
			attribute maxVolume : VolumeValue;
			attribute minVolume : VolumeValue;
			item containedFluid : Fluid;
		}
		
		part def DriveShaft {
			attribute rotationalSpeed : FrequencyValue;
			attribute torque : Real;
			attribute power : Real;
		}
		
		part def CrankMechanism {
			attribute crankRadius : LengthValue;
			attribute connectingRodLength : LengthValue;
			attribute crankAngle : Real;
		}
		
		part def Motor {
			port mechanicalOutput;
			attribute ratedPower : Real;
			attribute operatingSpeed : FrequencyValue;
			attribute voltage : Real;
			attribute current : Real;
		}
		
		part def FluidReservoir {
			port outlet : FluidOutletPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			item storedFluid : Fluid;
		}
		
		part def PressureVessel {
			port inlet : FluidInletPort;
			attribute capacity : VolumeValue;
			attribute currentPressure : PressureValue;
			attribute maxAllowablePressure : PressureValue;
			item containedFluid : Fluid;
		}
		
		part def PressureSensor {
			port sensingPort;
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real;
		}
		
		part def FlowMeter {
			port sensingPort;
			attribute measuredFlowRate : FlowRateValue;
			attribute accuracy : Real;
		}
		
		action def IntakeStroke {
			in chamberVolume : VolumeValue;
			in sourceFluid : Fluid;
			out intakeFluid : Fluid;
		}
		
		action def CompressionStroke {
			in chamberFluid : Fluid;
			in targetPressure : PressureValue;
			out compressedFluid : Fluid;
		}
		
		action def DischargeStroke {
			in pressurizedFluid : Fluid;
			out dischargeFluid : Fluid;
		}
		
		action def PlungerPumpCycle {
			in inletFluid : Fluid;
			in operatingSpeed : FrequencyValue;
			out outletFluid : Fluid;
			out flowRate : FlowRateValue;
			
			first start;
			then merge cycleLoop;
			
			then action intake : IntakeStroke {
				in chamberVolume;
				in sourceFluid = inletFluid;
				out intakeFluid : Fluid;
			}
			
			then action compress : CompressionStroke {
				in chamberFluid = intake.intakeFluid;
				in targetPressure;
				out compressedFluid : Fluid;
			}
			
			then action discharge : DischargeStroke {
				in pressurizedFluid = compress.compressedFluid;
				out dischargeFluid = outletFluid;
			}
			
			then cycleLoop;
		}
		
		part def PlungerPump {
			port suctionPort : FluidInletPort;
			port dischargePort : FluidOutletPort;
			port driveInput;
			
			attribute ratedFlowRate : FlowRateValue;
			attribute ratedDischargePressure : PressureValue;
			attribute ratedSpeed : FrequencyValue;
			attribute numberOfPlungers : Integer;
			attribute volumetricEfficiency : Real;
			attribute mechanicalEfficiency : Real;
			attribute overallEfficiency : Real;
			
			part plungers : Plunger[3];
			part chambers : PumpChamber[3];
			part inletValves : CheckValve[3];
			part dischargeValves : CheckValve[3];
			part driveShaft : DriveShaft;
			part crankMechanism : CrankMechanism;
			
			perform action pumpingCycle : PlungerPumpCycle {
				in inletFluid = suctionPort.fluidIn;
				in operatingSpeed = ratedSpeed;
				out outletFluid = dischargePort.fluidOut;
				out flowRate = ratedFlowRate;
			}
		}
		
		requirement def PumpPerformanceRequirement {
			subject pump : PlungerPump;
			
			attribute minFlowRate : FlowRateValue;
			attribute maxFlowRate : FlowRateValue;
			attribute minDischargePressure : PressureValue;
			attribute maxDischargePressure : PressureValue;
			attribute minEfficiency : Real;
			
			require constraint flowRateRange {
				pump.ratedFlowRate >= minFlowRate and
				pump.ratedFlowRate <= maxFlowRate
			}
			
			require constraint pressureRange {
				pump.ratedDischargePressure >= minDischargePressure and
				pump.ratedDischargePressure <= maxDischargePressure
			}
			
			require constraint efficiencyRequirement {
				pump.overallEfficiency >= minEfficiency
			}
		}
		
		requirement def ValveOperationRequirement {
			subject valve : CheckValve;
			
			require constraint preventBackflow {
				valve.valveState == false implies
				valve.inlet.portPressure <= valve.outlet.portPressure + valve.crackingPressure
			}
			
			require constraint allowForwardFlow {
				valve.valveState == true implies
				valve.inlet.portPressure > valve.outlet.portPressure + valve.crackingPressure
			}
		}
		
		requirement def SystemSafetyRequirement {
			subject vessel : PressureVessel;
			
			require constraint pressureLimit {
				vessel.currentPressure <= vessel.maxAllowablePressure
			}
		}
	}
	
	package Usages {
		part pumpingSubsystem {
			part supplyReservoir : FluidReservoir {
				attribute :>> capacity = 1000.0;
				attribute :>> currentLevel = 850.0;
				item :>> storedFluid : Fluid {
					attribute :>> density = 998.0;
					attribute :>> viscosity = 0.001;
					attribute :>> temperature = 293.15;
					attribute :>> pressure = 101325.0;
				}
			}
			
			part driveMotor : Motor {
				attribute :>> ratedPower = 11000.0;
				attribute :>> operatingSpeed = 1450.0;
				attribute :>> voltage = 400.0;
				attribute :>> current = 20.0;
			}
			
			part mainPump : PlungerPump {
				attribute :>> ratedFlowRate = 75.0;
				attribute :>> ratedDischargePressure = 25000000.0;
				attribute :>> ratedSpeed = 1450.0;
				attribute :>> numberOfPlungers = 3;
				attribute :>> volumetricEfficiency = 0.92;
				attribute :>> mechanicalEfficiency = 0.95;
				attribute :>> overallEfficiency = 0.874;
				
				part :>> plungers : Plunger[3] {
					attribute :>> diameter = 0.030;
					attribute :>> strokeLength = 0.060;
					attribute :>> currentPosition = 0.030;
					attribute :>> area = 0.000707;
				}
				
				part :>> chambers : PumpChamber[3] {
					attribute :>> maxVolume = 0.000042;
					attribute :>> minVolume = 0.000005;
				}
				
				part :>> inletValves : CheckValve[3] {
					attribute :>> crackingPressure = 15000.0;
				}
				
				part :>> dischargeValves : CheckValve[3] {
					attribute :>> crackingPressure = 75000.0;
				}
				
				part :>> crankMechanism : CrankMechanism {
					attribute :>> crankRadius = 0.030;
					attribute :>> connectingRodLength = 0.120;
				}
			}
			
			part dischargeVessel : PressureVessel {
				attribute :>> capacity = 200.0;
				attribute :>> maxAllowablePressure = 30000000.0;
			}
			
			part suctionPressureSensor : PressureSensor {
				attribute :>> accuracy = 0.25;
			}
			
			part dischargePressureSensor : PressureSensor {
				attribute :>> accuracy = 0.25;
			}
			
			part dischargeFlowMeter : FlowMeter {
				attribute :>> accuracy = 0.5;
			}
			
			flow of fluid : Fluid
				from supplyReservoir.outlet.fluidOut to mainPump.suctionPort.fluidIn;
			
			flow of fluid : Fluid
				from mainPump.dischargePort.fluidOut to dischargeVessel.inlet.fluidIn;
			
			bind suctionPressureSensor.measuredPressure = mainPump.suctionPort.portPressure;
			bind dischargePressureSensor.measuredPressure = mainPump.dischargePort.portPressure;
			bind dischargeFlowMeter.measuredFlowRate = mainPump.ratedFlowRate;
			
			connection motorDrive connect driveMotor.mechanicalOutput to mainPump.driveInput;
			
			satisfy performanceReq : PumpPerformanceRequirement {
				subject pump = mainPump;
				redefines minFlowRate = 60.0;
				redefines maxFlowRate = 90.0;
				redefines minDischargePressure = 20000000.0;
				redefines maxDischargePressure = 28000000.0;
				redefines minEfficiency = 0.85;
			}
			
			satisfy inletValveReq : ValveOperationRequirement {
				subject valve = mainPump.inletValves[1];
			}
			
			satisfy dischargeValveReq : ValveOperationRequirement {
				subject valve = mainPump.dischargeValves[1];
			}
			
			satisfy safetyReq : SystemSafetyRequirement {
				subject vessel = dischargeVessel;
			}
			
			assert constraint systemOperatingConstraint {
				mainPump.ratedFlowRate >= performanceReq.minFlowRate and
				mainPump.ratedDischargePressure <= dischargeVessel.maxAllowablePressure and
				mainPump.overallEfficiency >= performanceReq.minEfficiency
			}
		}
	}
}
