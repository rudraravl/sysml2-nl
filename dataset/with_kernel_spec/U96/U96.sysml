package 'Organ Care System' {
	private import ScalarValues::*;
	
	package Definitions {
		attribute def TemperatureValue :> ScalarValues::Real;
		attribute def PressureValue :> ScalarValues::Real;
		attribute def FlowRateValue :> ScalarValues::Real;
		attribute def OxygenLevelValue :> ScalarValues::Real;
		attribute def LactateLevelValue :> ScalarValues::Real;
		attribute def TimeValue :> ScalarValues::Real;
		
		item def PreservationSolution;
		
		item def SensorData {
			attribute temperature : TemperatureValue;
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
			attribute oxygenLevel : OxygenLevelValue;
			attribute lactateLevel : LactateLevelValue;
		}
		
		item def PumpCommand {
			attribute speed : ScalarValues::Real;
		}
		
		item def ThermalCommand {
			attribute targetTemperature : TemperatureValue;
		}
		
		item def StatusDisplay {
			attribute sensorData : SensorData;
			attribute systemState : ScalarValues::String;
		}
		
		item def AlarmSignal;
		
		attribute def 'Prime Complete';
		attribute def 'Stable Parameters';
		attribute def 'Parameter Out of Range';
		attribute def 'Parameters Adjusted';
		
		port def FluidOutPort {
			out solution : PreservationSolution;
		}
		
		port def FluidInPort {
			in solution : PreservationSolution;
		}
		
		port def SensorDataOutPort {
			out data : SensorData;
		}
		
		port def SensorDataInPort {
			in data : SensorData;
		}
		
		port def PumpCommandInPort {
			in command : PumpCommand;
		}
		
		port def PumpCommandOutPort {
			out command : PumpCommand;
		}
		
		port def ThermalCommandInPort {
			in command : ThermalCommand;
		}
		
		port def ThermalCommandOutPort {
			out command : ThermalCommand;
		}
		
		port def StatusOutPort {
			out status : StatusDisplay;
		}
		
		port def StatusInPort {
			in status : StatusDisplay;
		}
		
		port def AlarmOutPort {
			out alarm : AlarmSignal;
		}
		
		port def AlarmInPort {
			in alarm : AlarmSignal;
		}
		
		part def Organ;
		
		part def PerfusionChamber {
			port solutionIn : FluidInPort;
			port solutionOut : FluidOutPort;
			part organ : Organ;
		}
		
		part def CirculationPump {
			port solutionIn : FluidInPort;
			port solutionOut : FluidOutPort;
			port commandIn : PumpCommandInPort;
		}
		
		part def FluidReservoir {
			port solutionOut : FluidOutPort;
			port solutionIn : FluidInPort;
		}
		
		part def OxygenationModule {
			port solutionIn : FluidInPort;
			port solutionOut : FluidOutPort;
		}
		
		part def ThermalRegulator {
			port solutionIn : FluidInPort;
			port solutionOut : FluidOutPort;
			port commandIn : ThermalCommandInPort;
		}
		
		part def BioSensorArray {
			port solutionSample : FluidInPort;
			port dataOut : SensorDataOutPort;
		}
		
		part def ControlProcessor {
			port dataIn : SensorDataInPort;
			port pumpCmdOut : PumpCommandOutPort;
			port thermalCmdOut : ThermalCommandOutPort;
			port statusOut : StatusOutPort;
			port alarmOut : AlarmOutPort;
			
			attribute maxTemp : TemperatureValue;
			attribute minTemp : TemperatureValue;
			attribute maxPressure : PressureValue;
			attribute minPressure : PressureValue;
			attribute maxFlowRate : FlowRateValue;
			attribute minFlowRate : FlowRateValue;
			attribute minOxygenLevel : OxygenLevelValue;
			attribute maxLactateLevel : LactateLevelValue;
			
			exhibit state 'processor states' : 'Processor States';
		}
		
		part def UserInterface {
			port statusIn : StatusInPort;
			port alarmIn : AlarmInPort;
		}
		
		part def OrganCareSystem {
			part perfusionChamber : PerfusionChamber;
			part circulationPump : CirculationPump;
			part fluidReservoir : FluidReservoir;
			part oxygenationModule : OxygenationModule;
			part thermalRegulator : ThermalRegulator;
			part bioSensorArray : BioSensorArray;
			part controlProcessor : ControlProcessor;
			part userInterface : UserInterface;
			
			exhibit state 'system states' : 'System States';
		}
		
		state def 'System States';
		state def 'Processor States';
		
		action def 'Prime Circuit';
		action def 'Perfuse Organ';
		action def 'Monitor Parameters';
		action def 'Raise Alarm';
		action def 'Adjust Parameters';
	}
	
	package Usages {
		private import Definitions::*;
		
		action 'prime circuit' : 'Prime Circuit';
		action 'perfuse organ' : 'Perfuse Organ';
		action 'monitor parameters' : 'Monitor Parameters';
		action 'raise alarm' : 'Raise Alarm';
		action 'adjust parameters' : 'Adjust Parameters';
		
		part ocs : OrganCareSystem {
			flow solutionFlow1 of PreservationSolution 
				from fluidReservoir.solutionOut.solution to circulationPump.solutionIn.solution;
			flow solutionFlow2 of PreservationSolution 
				from circulationPump.solutionOut.solution to oxygenationModule.solutionIn.solution;
			flow solutionFlow3 of PreservationSolution 
				from oxygenationModule.solutionOut.solution to thermalRegulator.solutionIn.solution;
			flow solutionFlow4 of PreservationSolution 
				from thermalRegulator.solutionOut.solution to perfusionChamber.solutionIn.solution;
			flow solutionFlow5 of PreservationSolution 
				from perfusionChamber.solutionOut.solution to fluidReservoir.solutionIn.solution;
			
			flow sensorSampleFlow of PreservationSolution 
				from perfusionChamber.solutionOut.solution to bioSensorArray.solutionSample.solution;
			
			flow sensorDataFlow of SensorData 
				from bioSensorArray.dataOut.data to controlProcessor.dataIn.data;
			flow pumpCmdFlow of PumpCommand 
				from controlProcessor.pumpCmdOut.command to circulationPump.commandIn.command;
			flow thermalCmdFlow of ThermalCommand 
				from controlProcessor.thermalCmdOut.command to thermalRegulator.commandIn.command;
			flow statusFlow of StatusDisplay 
				from controlProcessor.statusOut.status to userInterface.statusIn.status;
			flow alarmFlow of AlarmSignal 
				from controlProcessor.alarmOut.alarm to userInterface.alarmIn.alarm;
			
			state 'system states' : 'System States' {
				entry; then priming;
				state priming {
					entry 'prime circuit';
				}
				accept 'Prime Complete'
					then 'active perfusion';
				state 'active perfusion' {
					entry 'perfuse organ';
					do 'monitor parameters';
				}
				accept 'Stable Parameters'
					then monitoring;
				state monitoring {
					do 'monitor parameters';
				}
				accept 'Parameter Out of Range'
					then alarm;
				state alarm {
					entry 'raise alarm';
					do 'adjust parameters';
				}
				accept 'Parameters Adjusted'
					then monitoring;
			}
		}
		
		requirement def 'Organ Viability Requirement' {
			doc /*
			 * The system shall maintain donor organ viability by actively perfusing
			 * the organ with oxygenated, temperature-controlled preservation solution
			 * and continuously monitoring critical health indicators including
			 * temperature, pressure, flow rate, oxygen levels, and lactate levels.
			 */
			attribute preservationTime : TimeValue;
			assert constraint { preservationTime > 6.0 }
		}
		
		requirement def 'Safe Range Requirement' {
			doc /*
			 * The control processor shall keep all perfusion parameters within
			 * a predefined safe range by adjusting pump speed and thermal
			 * regulator output.
			 */
			subject processor : ControlProcessor;
			assert constraint { processor.maxTemp > processor.minTemp }
			assert constraint { processor.maxPressure > processor.minPressure }
			assert constraint { processor.maxFlowRate > processor.minFlowRate }
		}
		
		requirement organViabilityReq : 'Organ Viability Requirement';
		requirement safeRangeReq : 'Safe Range Requirement';
		
		satisfy organViabilityReq by ocs;
		satisfy safeRangeReq by ocs.controlProcessor;
	}
}
