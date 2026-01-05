package 'Waterladder Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Water {
			attribute density : DensityValue;
			attribute temperature : TemperatureValue;
			attribute volume : VolumeValue;
		}
		
		port def FluidPort {
			out item fluid : Water;
			attribute pressure : PressureValue;
			attribute flowRate : VolumeFlowValue;
		}
		
		port def MechanicalDrivePort {
			in attribute torque : TorqueValue;
			in attribute rotationalSpeed : AngularVelocityValue;
		}
		
		signal def StartCommand;
		signal def StopCommand;
		signal def ResetCommand;
		
		part def WaterladderPump {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			port drivePort : MechanicalDrivePort;
			
			attribute numberOfBuckets : Integer = 12;
			attribute bucketCapacity : VolumeValue;
			attribute drumDiameter : LengthValue;
			attribute liftHeight : LengthValue;
			attribute operatingSpeed : AngularVelocityValue;
			attribute efficiency : Real;
			attribute actualFlowRate : VolumeFlowValue;
			attribute developedHead : LengthValue;
			
			part rotatingDrum {
				attribute diameter : LengthValue;
				attribute length : LengthValue;
				attribute rotationSpeed : AngularVelocityValue;
			}
			
			part buckets[12] {
				attribute capacity : VolumeValue;
				attribute currentPosition : Real;
				attribute fillLevel : Real;
			}
			
			part liftingChain {
				attribute length : LengthValue;
				attribute tension : ForceValue;
			}
			
			perform action pumpWater : PumpWater {
				in waterIn = inletPort.fluid;
				out waterOut = outletPort.fluid;
			}
			
			state pumpStateMachine {
				entry; then stopped;
				
				state stopped {
					entry assign rotatingDrum.rotationSpeed := 0.0 [SI::rad/SI::s];
				}
				
				state starting {
					entry assign rotatingDrum.rotationSpeed := operatingSpeed * 0.3;
					do action accelerate {
						out targetSpeed : AngularVelocityValue;
					}
				}
				
				state running {
					state normalOperation {
						entry assign rotatingDrum.rotationSpeed := operatingSpeed;
						do action liftWater {
							in bucketIndex : Integer;
							out liftedVolume : VolumeValue;
						}
					}
					
					state discharging {
						do action dischargeWater {
							out dischargeFlow : VolumeFlowValue;
							out dischargePressure : PressureValue;
						}
					}
				}
				
				state stopping {
					entry assign rotatingDrum.rotationSpeed := operatingSpeed * 0.5;
					do action decelerate;
				}
				
				state fault {
					entry assign rotatingDrum.rotationSpeed := 0.0 [SI::rad/SI::s];
				}
				
				transition stopped_to_starting
					first stopped
					accept StartCommand
					then starting;
				
				transition starting_to_running
					first starting
					if rotatingDrum.rotationSpeed >= operatingSpeed * 0.9
					then running;
				
				transition running_to_stopping
					first running
					accept StopCommand
					then stopping;
				
				transition stopping_to_stopped
					first stopping
					if rotatingDrum.rotationSpeed <= 0.1 [SI::rad/SI::s]
					then stopped;
				
				transition running_to_fault
					first running
					if drivePort.torque > 8000.0 [SI::N*SI::m]
					then fault;
				
				transition fault_to_stopped
					first fault
					accept ResetCommand
					then stopped;
			}
		}
		
		part def DriveMotor {
			port mechanicalOutput : ~MechanicalDrivePort;
			port powerInput {
				in attribute voltage : Real;
				in attribute current : Real;
			}
			
			attribute ratedPower : PowerValue;
			attribute outputTorque : TorqueValue;
			attribute outputSpeed : AngularVelocityValue;
			attribute motorEfficiency : Real;
			
			perform action convertPower : ConvertElectricalToMechanical {
				in electricalPower : PowerValue;
				out mechanicalPower : PowerValue;
			}
		}
		
		part def SupplyReservoir {
			port outletPort : FluidPort;
			
			attribute capacity : VolumeValue;
			attribute currentLevel : LengthValue;
			attribute waterVolume : VolumeValue;
			
			item storedWater : Water {
				attribute :>> volume;
			}
		}
		
		part def DischargeReservoir {
			port inletPort : ~FluidPort;
			
			attribute capacity : VolumeValue;
			attribute currentLevel : LengthValue;
			attribute elevation : LengthValue;
			
			item receivedWater : Water {
				attribute :>> volume;
			}
		}
		
		part def FlowMeter {
			port measurementPort : ~FluidPort;
			
			attribute measuredFlowRate : VolumeFlowValue;
			attribute accuracy : Real;
			attribute calibrationDate : String;
		}
		
		part def PressureGauge {
			port measurementPort : ~FluidPort;
			
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real;
			attribute range : PressureValue;
		}
		
		part def ControlValve {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			
			attribute openingPercentage : Real;
			attribute flowCoefficient : Real;
			attribute maxPressureDrop : PressureValue;
		}
		
		action def PumpWater {
			in waterIn : Water;
			out waterOut : Water;
			
			attribute headDeveloped : LengthValue;
			attribute volumeTransferred : VolumeValue;
			attribute powerConsumed : PowerValue;
		}
		
		action def ConvertElectricalToMechanical {
			in electricalPower : PowerValue;
			out mechanicalPower : PowerValue;
			
			attribute conversionEfficiency : Real;
		}
		
		action def MonitorPumpingSystem {
			in inletPressure : PressureValue;
			in outletPressure : PressureValue;
			in flowRate : VolumeFlowValue;
			in motorCurrent : Real;
			out systemStatus : String;
			out alarmCondition : Boolean;
		}
		
		action def ControlPumpSpeed {
			in desiredFlowRate : VolumeFlowValue;
			in actualFlowRate : VolumeFlowValue;
			out speedAdjustment : AngularVelocityValue;
		}
		
		requirement def MinimumFlowRateRequirement {
			subject pump : WaterladderPump;
			
			doc /* The Waterladder pump shall deliver a minimum flow rate of 8.0 m^3/h. */
			
			require constraint {
				pump.actualFlowRate >= 8.0 [SI::m^3/SI::h]
			}
		}
		
		requirement def MaximumPowerConsumptionRequirement {
			subject motor : DriveMotor;
			
			doc /* The drive motor shall not exceed 15.0 kW power consumption. */
			
			require constraint {
				motor.ratedPower <= 15.0 [SI::kW]
			}
		}
		
		requirement def MinimumLiftHeightRequirement {
			subject pump : WaterladderPump;
			
			doc /* The pump shall lift water to a minimum height of 12.0 meters. */
			
			require constraint {
				pump.liftHeight >= 12.0 [SI::m]
			}
		}
		
		requirement def SystemEfficiencyRequirement {
			subject pump : WaterladderPump;
			
			doc /* The pumping system shall operate at minimum 65% efficiency. */
			
			require constraint {
				pump.efficiency >= 0.65
			}
		}
		
		requirement def ContinuousOperationRequirement {
			doc /* The pumping subsystem shall operate continuously for 10000 hours minimum. */
			
			attribute operatingHours : Real;
			
			require constraint {
				operatingHours >= 10000.0
			}
		}
	}
	
	package Usages {
		part pumpingSubsystem {
			part supplyReservoir : Definitions::SupplyReservoir {
				attribute :>> capacity = 100.0 [SI::m^3];
				attribute :>> currentLevel = 4.2 [SI::m];
				attribute :>> waterVolume = 85.0 [SI::m^3];
				
				item :>> storedWater {
					attribute :>> density = 1000.0 [SI::kg/SI::m^3];
					attribute :>> temperature = 288.15 [SI::K];
					attribute :>> volume = 85.0 [SI::m^3];
				}
			}
			
			flow of water : Definitions::Water
				from supplyReservoir.outletPort.fluid
				to inletValve.inletPort.fluid;
			
			part inletValve : Definitions::ControlValve {
				attribute :>> openingPercentage = 85.0;
				attribute :>> flowCoefficient = 150.0;
				attribute :>> maxPressureDrop = 50.0 [SI::Pa] * 1000.0;
			}
			
			flow of water : Definitions::Water
				from inletValve.outletPort.fluid
				to waterladderPump.inletPort.fluid;
			
			part inletPressureGauge : Definitions::PressureGauge {
				attribute :>> measuredPressure = 105.0 [SI::Pa] * 1000.0;
				attribute :>> accuracy = 0.015;
				attribute :>> range = 500.0 [SI::Pa] * 1000.0;
			}
			
			bind inletPressureGauge.measurementPort.fluid = waterladderPump.inletPort.fluid;
			
			part waterladderPump : Definitions::WaterladderPump {
				attribute :>> numberOfBuckets = 12;
				attribute :>> bucketCapacity = 12.0 [SI::L];
				attribute :>> drumDiameter = 2.0 [SI::m];
				attribute :>> liftHeight = 14.0 [SI::m];
				attribute :>> operatingSpeed = 12.0 [SI::rad/SI::min];
				attribute :>> efficiency = 0.68;
				attribute :>> actualFlowRate = 9.2 [SI::m^3/SI::h];
				attribute :>> developedHead = 14.5 [SI::m];
				
				part :>> rotatingDrum {
					attribute :>> diameter = 2.0 [SI::m];
					attribute :>> length = 2.8 [SI::m];
					attribute :>> rotationSpeed = 12.0 [SI::rad/SI::min];
				}
				
				part :>> buckets {
					attribute :>> capacity = 12.0 [SI::L];
					attribute :>> fillLevel = 0.92;
				}
				
				part :>> liftingChain {
					attribute :>> length = 18.0 [SI::m];
					attribute :>> tension = 4500.0 [SI::N];
				}
				
				perform action :>> pumpWater {
					attribute :>> headDeveloped = 14.5 [SI::m];
					attribute :>> volumeTransferred = 9.2 [SI::m^3/SI::h];
					attribute :>> powerConsumed = 11.8 [SI::kW];
				}
			}
			
			part driveMotor : Definitions::DriveMotor {
				attribute :>> ratedPower = 13.5 [SI::kW];
				attribute :>> outputTorque = 6500.0 [SI::N*SI::m];
				attribute :>> outputSpeed = 12.0 [SI::rad/SI::min];
				attribute :>> motorEfficiency = 0.88;
				
				perform action :>> convertPower {
					in electricalPower = 13.4 [SI::kW];
					out mechanicalPower = 11.8 [SI::kW];
					attribute :>> conversionEfficiency = 0.88;
				}
			}
			
			connect driveMotor.mechanicalOutput to waterladderPump.drivePort;
			
			flow of water : Definitions::Water
				from waterladderPump.outletPort.fluid
				to outletFlowMeter.measurementPort.fluid;
			
			part outletFlowMeter : Definitions::FlowMeter {
				attribute :>> measuredFlowRate = 9.1 [SI::m^3/SI::h];
				attribute :>> accuracy = 0.012;
				attribute :>> calibrationDate = "2024-11-15";
			}
			
			flow of water : Definitions::Water
				from outletFlowMeter.measurementPort.fluid
				to dischargeReservoir.inletPort.fluid;
			
			part outletPressureGauge : Definitions::PressureGauge {
				attribute :>> measuredPressure = 242.0 [SI::Pa] * 1000.0;
				attribute :>> accuracy = 0.015;
				attribute :>> range = 500.0 [SI::Pa] * 1000.0;
			}
			
			bind outletPressureGauge.measurementPort.fluid = waterladderPump.outletPort.fluid;
			
			part dischargeReservoir : Definitions::DischargeReservoir {
				attribute :>> capacity = 60.0 [SI::m^3];
				attribute :>> currentLevel = 2.8 [SI::m];
				attribute :>> elevation = 14.0 [SI::m];
				
				item :>> receivedWater {
					attribute :>> volume = 32.0 [SI::m^3];
				}
			}
			
			perform action monitorSystem : Definitions::MonitorPumpingSystem {
				in inletPressure = inletPressureGauge.measuredPressure;
				in outletPressure = outletPressureGauge.measuredPressure;
				in flowRate = outletFlowMeter.measuredFlowRate;
				in motorCurrent = 42.5;
				out systemStatus = "Normal Operation";
				out alarmCondition = false;
			}
			
			perform action controlSpeed : Definitions::ControlPumpSpeed {
				in desiredFlowRate = 9.0 [SI::m^3/SI::h];
				in actualFlowRate = outletFlowMeter.measuredFlowRate;
				out speedAdjustment = 12.0 [SI::rad/SI::min];
			}
			
			satisfy minimumFlowReq : Definitions::MinimumFlowRateRequirement {
				subject pump = waterladderPump;
			}
			
			satisfy maximumPowerReq : Definitions::MaximumPowerConsumptionRequirement {
				subject motor = driveMotor;
			}
			
			satisfy minimumLiftReq : Definitions::MinimumLiftHeightRequirement {
				subject pump = waterladderPump;
			}
			
			satisfy systemEfficiencyReq : Definitions::SystemEfficiencyRequirement {
				subject pump = waterladderPump;
			}
			
			satisfy continuousOperationReq : Definitions::ContinuousOperationRequirement {
				attribute :>> operatingHours = 12500.0;
			}
		}
	}
	
	package Analysis {
		part hydraulicAnalysis {
			attribute staticHead : LengthValue = 14.0 [SI::m];
			attribute frictionLoss : PressureValue = 8.5 [SI::Pa] * 1000.0;
			attribute totalDynamicHead : LengthValue = 15.2 [SI::m];
			attribute flowVelocity : SpeedValue = 1.8 [SI::m/SI::s];
			attribute reynoldsNumber : Real = 125000.0;
		}
		
		part powerAnalysis {
			attribute hydraulicPower : PowerValue = 10.2 [SI::kW];
			attribute shaftPower : PowerValue = 11.8 [SI::kW];
			attribute electricalPower : PowerValue = 13.4 [SI::kW];
			attribute overallEfficiency : Real = 0.76;
			attribute dailyEnergyConsumption : EnergyValue = 321.6 [SI::kW*SI::h];
		}
		
		part mechanicalAnalysis {
			attribute bucketLoadForce : ForceValue = 118.0 [SI::N];
			attribute drumTorque : TorqueValue = 6500.0 [SI::N*SI::m];
			attribute chainTension : ForceValue = 4500.0 [SI::N];
			attribute bearingLoad : ForceValue = 8200.0 [SI::N];
		}
	}
}
