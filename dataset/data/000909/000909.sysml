package 'Knudsen Pump Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		attribute def Temperature {
			attribute num : Real;
			attribute unit : TemperatureUnit;
		}
		
		attribute def Pressure {
			attribute num : Real;
			attribute unit : PressureUnit;
		}
		
		attribute def FlowRate {
			attribute num : Real;
			attribute unit : VolumeFlowRateUnit;
		}
		
		attribute def Power {
			attribute num : Real;
			attribute unit : PowerUnit;
		}
		
		attribute def Length {
			attribute num : Real;
			attribute unit : LengthUnit;
		}
		
		item def Gas {
			attribute molecularMass : Real;
			attribute meanFreePath : Length;
			attribute pressure : Pressure;
			attribute temperature : Temperature;
		}
		
		port def GasPort {
			attribute pressure : Pressure;
			attribute temperature : Temperature;
			item gas : Gas;
		}
		
		port def ThermalPort {
			attribute temperature : Temperature;
			item heatFlow : Real;
		}
		
		port def PowerPort {
			attribute voltage : Real;
			attribute current : Real;
			item power : Real;
		}
		
		part def MicroChannel {
			attribute length : Length;
			attribute diameter : Length;
			attribute knudsenNumber : Real;
			
			port gasInlet : GasPort;
			port gasOutlet : GasPort;
			port hotSide : ThermalPort;
			port coldSide : ThermalPort;
			
			assert constraint knudsenRegime {
				knudsenNumber > 0.1 and knudsenNumber < 10.0
			}
		}
		
		part def HeatingElement {
			attribute maxTemperature : Temperature;
			attribute operatingTemperature : Temperature;
			attribute powerConsumption : Power;
			
			port powerIn : PowerPort;
			port thermalOut : ThermalPort;
			
			assert constraint temperatureLimit {
				operatingTemperature.num <= maxTemperature.num
			}
		}
		
		part def CoolingElement {
			attribute operatingTemperature : Temperature;
			attribute coolingCapacity : Power;
			
			port thermalIn : ThermalPort;
			port coolantIn : GasPort;
			port coolantOut : GasPort;
		}
		
		part def KnudsenPumpCore {
			attribute numberOfChannels : Integer;
			attribute hotSideTemperature : Temperature;
			attribute coldSideTemperature : Temperature;
			attribute temperatureGradient : Real;
			
			port gasInlet : GasPort;
			port gasOutlet : GasPort;
			
			part channels : MicroChannel[1..*];
			part heater : HeatingElement;
			part cooler : CoolingElement;
			
			connection heatingInterface
				connect heater.thermalOut to channels.hotSide;
			
			connection coolingInterface
				connect cooler.thermalIn to channels.coldSide;
			
			assert constraint effectiveGradient {
				temperatureGradient > 50.0
			}
		}
		
		part def GasReservoir {
			attribute volume : Real;
			attribute storedPressure : Pressure;
			
			port gasPort : GasPort;
			
			item storedGas : Gas {
				attribute quantity : Real;
			}
		}
		
		part def PressureSensor {
			attribute measuredPressure : Pressure;
			attribute accuracy : Real;
			
			port sensingPort : GasPort;
			port signalOut;
		}
		
		part def TemperatureSensor {
			attribute measuredTemperature : Temperature;
			attribute accuracy : Real;
			
			port sensingPort : ThermalPort;
			port signalOut;
		}
		
		part def FlowMeter {
			attribute measuredFlowRate : FlowRate;
			attribute accuracy : Real;
			
			port sensingPort : GasPort;
			port signalOut;
		}
		
		part def PowerSupply {
			attribute outputVoltage : Real;
			attribute maxCurrent : Real;
			attribute maxPower : Power;
			
			port powerOut : PowerPort;
		}
		
		action def MonitorPumpOperation {
			in inletPressure : Pressure;
			in outletPressure : Pressure;
			in flowRate : FlowRate;
			in hotTemperature : Temperature;
			in coldTemperature : Temperature;
			out compressionRatio : Real;
			out efficiency : Real;
		}
		
		action def ControlTemperature {
			in targetTemperature : Temperature;
			in currentTemperature : Temperature;
			in maxTemperature : Temperature;
			out powerAdjustment : Real;
		}
		
		action def RegulateFlow {
			in targetFlowRate : FlowRate;
			in currentFlowRate : FlowRate;
			in currentPressure : Pressure;
			out temperatureAdjustment : Real;
		}
		
		state def KnudsenPumpStates {
			attribute heaterPower : Real;
			attribute targetHotTemp : Temperature;
			attribute maxHotTemp : Temperature;
			attribute ambientTemp : Temperature;
			attribute hotTemp : Temperature;
			
			entry; then off;
			
			state off;
			
			transition off_to_warmup
				first off
				accept StartSignal
				then warmup;
			
			state warmup {
				do action heatup : ControlTemperature;
			}
			
			transition warmup_to_operating
				first warmup
				then operating;
			
			state operating {
				do action monitor : MonitorPumpOperation;
				do action controlTemp : ControlTemperature;
				do action controlFlow : RegulateFlow;
			}
			
			transition operating_to_cooldown
				first operating
				accept StopSignal
				then cooldown;
			
			state cooldown {
				do action cooling : ControlTemperature;
			}
			
			transition cooldown_to_off
				first cooldown
				then off;
			
			state fault;
			
			transition fault_to_cooldown
				first fault
				accept ResetSignal
				then cooldown;
		}
		
		requirement def KnudsenPumpRequirements {
			doc /* The Knudsen pump subsystem shall utilize thermal transpiration 
			       to move gas from low pressure to high pressure without mechanical 
			       moving parts. */
			
			subject pumpSystem;
			
			require thermalTranspiration {
				doc /* The pump shall generate flow by maintaining a temperature 
				       gradient across micro-channels operating in the Knudsen regime. */
			}
			
			require pressureIncrease {
				doc /* The pump shall achieve outlet pressure greater than inlet pressure. */
			}
			
			require flowGeneration {
				doc /* The pump shall maintain continuous gas flow from inlet to outlet. */
			}
			
			require temperatureControl {
				doc /* The pump shall maintain hot side temperature between 373K and 573K. */
			}
			
			require knudsenRegimeOperation {
				doc /* The pump channels shall operate with Knudsen number between 0.1 and 10. */
			}
			
			require noMovingParts {
				doc /* The pump shall operate without mechanical moving parts. */
			}
		}
	}
	
	package Usages {
		import Definitions::*;
		
		part knudsenPumpingSubsystem {
			
			part sourceReservoir : GasReservoir {
				attribute :>> volume = 0.002;
				attribute :>> storedPressure {
					attribute :>> num = 100.0;
					attribute :>> unit = SI::Pa;
				}
				
				item :>> storedGas : Gas {
					attribute :>> molecularMass = 28.97;
					attribute :>> meanFreePath {
						attribute :>> num = 6.8e-8;
						attribute :>> unit = SI::m;
					}
					attribute :>> pressure {
						attribute :>> num = 100.0;
						attribute :>> unit = SI::Pa;
					}
					attribute :>> temperature {
						attribute :>> num = 293.15;
						attribute :>> unit = SI::K;
					}
				}
			}
			
			part destinationReservoir : GasReservoir {
				attribute :>> volume = 0.002;
				attribute :>> storedPressure {
					attribute :>> num = 150.0;
					attribute :>> unit = SI::Pa;
				}
			}
			
			part knudsenPump : KnudsenPumpCore {
				attribute :>> numberOfChannels = 20;
				
				attribute :>> hotSideTemperature {
					attribute :>> num = 473.15;
					attribute :>> unit = SI::K;
				}
				
				attribute :>> coldSideTemperature {
					attribute :>> num = 293.15;
					attribute :>> unit = SI::K;
				}
				
				attribute :>> temperatureGradient = 180.0;
				
				part :>> channels : MicroChannel[20] {
					attribute :>> length {
						attribute :>> num = 0.001;
						attribute :>> unit = SI::m;
					}
					attribute :>> diameter {
						attribute :>> num = 1.0e-5;
						attribute :>> unit = SI::m;
					}
					attribute :>> knudsenNumber = 1.36;
				}
				
				part :>> heater : HeatingElement {
					attribute :>> maxTemperature {
						attribute :>> num = 573.15;
						attribute :>> unit = SI::K;
					}
					attribute :>> operatingTemperature {
						attribute :>> num = 473.15;
						attribute :>> unit = SI::K;
					}
					attribute :>> powerConsumption {
						attribute :>> num = 100.0;
						attribute :>> unit = SI::W;
					}
				}
				
				part :>> cooler : CoolingElement {
					attribute :>> operatingTemperature {
						attribute :>> num = 293.15;
						attribute :>> unit = SI::K;
					}
					attribute :>> coolingCapacity {
						attribute :>> num = 100.0;
						attribute :>> unit = SI::W;
					}
				}
			}
			
			part powerSupply : PowerSupply {
				attribute :>> outputVoltage = 24.0;
				attribute :>> maxCurrent = 5.0;
				attribute :>> maxPower {
					attribute :>> num = 120.0;
					attribute :>> unit = SI::W;
				}
			}
			
			part inletPressureSensor : PressureSensor {
				attribute :>> accuracy = 0.01;
			}
			
			part outletPressureSensor : PressureSensor {
				attribute :>> accuracy = 0.01;
			}
			
			part flowMeter : FlowMeter {
				attribute :>> accuracy = 0.02;
			}
			
			part hotSideTempSensor : TemperatureSensor {
				attribute :>> accuracy = 0.5;
			}
			
			part coldSideTempSensor : TemperatureSensor {
				attribute :>> accuracy = 0.5;
			}
			
			connection powerConnection
				connect powerSupply.powerOut to knudsenPump.heater.powerIn;
			
			bind inletPressureSensor.sensingPort = knudsenPump.gasInlet;
			bind outletPressureSensor.sensingPort = knudsenPump.gasOutlet;
			bind flowMeter.sensingPort = knudsenPump.gasOutlet;
			bind hotSideTempSensor.sensingPort = knudsenPump.heater.thermalOut;
			bind coldSideTempSensor.sensingPort = knudsenPump.cooler.thermalIn;
			
			flow of gas : Gas
				from sourceReservoir.gasPort.gas to knudsenPump.gasInlet.gas;
			
			flow of gas : Gas
				from knudsenPump.gasOutlet.gas to destinationReservoir.gasPort.gas;
			
			perform action operationMonitoring : MonitorPumpOperation {
				in inletPressure = inletPressureSensor.measuredPressure;
				in outletPressure = outletPressureSensor.measuredPressure;
				in flowRate = flowMeter.measuredFlowRate;
				in hotTemperature = hotSideTempSensor.measuredTemperature;
				in coldTemperature = coldSideTempSensor.measuredTemperature;
			}
			
			exhibit state pumpOperationalStates : KnudsenPumpStates {
				attribute :>> targetHotTemp {
					attribute :>> num = 473.15;
					attribute :>> unit = SI::K;
				}
				attribute :>> maxHotTemp {
					attribute :>> num = 573.15;
					attribute :>> unit = SI::K;
				}
				attribute :>> ambientTemp {
					attribute :>> num = 293.15;
					attribute :>> unit = SI::K;
				}
				bind hotTemp = hotSideTempSensor.measuredTemperature;
			}
			
			assert constraint flowRateCheck {
				flowMeter.measuredFlowRate.num > 0.0
			}
		}
		
		requirement knudsenPumpSystemRequirements : KnudsenPumpRequirements {
			subject pumpSystem = knudsenPumpingSubsystem.knudsenPump;
			
			satisfy thermalTranspiration by knudsenPumpingSubsystem.knudsenPump.temperatureGradient;
			satisfy flowGeneration by knudsenPumpingSubsystem.flowRateCheck;
			satisfy temperatureControl by knudsenPumpingSubsystem.knudsenPump.heater.temperatureLimit;
			satisfy knudsenRegimeOperation by knudsenPumpingSubsystem.knudsenPump.channels.knudsenRegime;
		}
	}
}
