package 'Belkin Wemo Smart Plug System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DeviceID;
	attribute def MACAddress;
	
	enum def SwitchState {
		off;
		on;
	}
	
	enum def CommandType {
		turnOn;
		turnOff;
		toggle;
		queryStatus;
		setSchedule;
	}
	
	attribute def WiFiCommand {
		attribute commandType : CommandType;
		attribute timestamp : TimeValue;
		attribute sourceID : DeviceID;
	}
	
	attribute def StatusReport {
		attribute switchState : SwitchState;
		attribute powerConsumption : PowerValue;
		attribute energyUsed : EnergyValue;
		attribute timestamp : TimeValue;
	}
	
	item def ACPower {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
		attribute frequency : FrequencyValue;
	}
	
	port def ACInputPort {
		in item acPower : ACPower;
	}
	
	port def ACOutputPort {
		out item acPower : ACPower;
	}
	
	port def WiFiPort {
		in item commands : WiFiCommand[*];
		out item status : StatusReport[*];
	}
	
	part def WiFiModule {
		port networkPort : WiFiPort;
		attribute macAddress : MACAddress;
		attribute isConnected : Boolean;
		
		action def ReceiveCommand {
			out command : WiFiCommand;
		}
		
		action def TransmitStatus {
			in statusData : StatusReport;
		}
	}
	
	part def ControlProcessor {
		attribute currentState : SwitchState;
		
		action def ProcessCommand {
			in command : WiFiCommand;
			in currentState : SwitchState;
			out newState : SwitchState;
			out relayControl : Boolean;
		}
	}
	
	part def RelaySwitch {
		attribute isClosed : Boolean;
		
		action def OperateRelay {
			in controlSignal : Boolean;
			out relayState : Boolean;
		}
	}
	
	part def PowerMeter {
		attribute accumulatedEnergy : EnergyValue;
		
		action def MeasurePower {
			in voltage : ElectricPotentialValue;
			in current : ElectricCurrentValue;
			out power : PowerValue;
		}
		
		action def AccumulateEnergy {
			in power : PowerValue;
			in deltaTime : TimeValue;
			in previousEnergy : EnergyValue;
			out totalEnergy : EnergyValue;
		}
	}
	
	part def LEDIndicator {
		attribute isLit : Boolean;
		
		action def UpdateIndicator {
			in deviceState : SwitchState;
			out ledState : Boolean;
		}
	}
	
	part def WemoSmartPlug {
		doc /* 
		Primary Function: The Belkin Wemo Smart Plug enables remote wireless control 
		of electrical appliances through WiFi connectivity. Users can turn connected 
		devices on or off via mobile applications, voice assistants, or automated 
		schedules. The system monitors real-time power consumption and accumulated 
		energy usage, providing insights into appliance efficiency. The plug operates 
		by receiving commands over WiFi, processing them through an internal controller, 
		and actuating a relay switch to control AC power flow to the connected load.
		*/
		
		port acInput : ACInputPort;
		port acOutput : ACOutputPort;
		port wifiInterface : WiFiPort;
		
		part wifi : WiFiModule {
			port networkPort = wemoSmartPlug.wifiInterface;
		}
		
		part controller : ControlProcessor;
		
		part relay : RelaySwitch;
		
		part meter : PowerMeter {
			attribute accumulatedEnergy = 0.0 [J];
		}
		
		part led : LEDIndicator;
		
		connection acInputConnection connect acInput to relay;
		connection acOutputConnection connect relay to acOutput;
		
		perform action operateWemoPlug {
			first start;
			then merge waitForCommand;
			
			action initialize {
				action initController : controller.ProcessCommand {
					in command : WiFiCommand;
					in currentState = SwitchState::off;
					out newState : SwitchState;
					out relayControl : Boolean;
				}
				then action initRelay : relay.OperateRelay {
					in controlSignal = false;
					out relayState : Boolean;
				}
				then action initLED : led.UpdateIndicator {
					in deviceState = SwitchState::off;
					out ledState : Boolean;
				}
			}
			then waitForCommand;
			
			action receiveCommand : wifi.ReceiveCommand {
				out command : WiFiCommand;
			}
			
			then action processCommand : controller.ProcessCommand {
				in command = receiveCommand.command;
				in currentState = controller.currentState;
				out newState : SwitchState;
				out relayControl : Boolean;
			}
			
			then action actuateRelay : relay.OperateRelay {
				in controlSignal = processCommand.relayControl;
				out relayState : Boolean;
			}
			
			then action updateLED : led.UpdateIndicator {
				in deviceState = processCommand.newState;
				out ledState : Boolean;
			}
			
			then action measurePower : meter.MeasurePower {
				in voltage = acInput.acPower.voltage;
				in current = acInput.acPower.current;
				out power : PowerValue;
			}
			
			then action updateEnergy : meter.AccumulateEnergy {
				in power = measurePower.power;
				in deltaTime = 1.0 [s];
				in previousEnergy = meter.accumulatedEnergy;
				out totalEnergy : EnergyValue;
			}
			
			then assign meter.accumulatedEnergy := updateEnergy.totalEnergy;
			
			then action reportStatus : wifi.TransmitStatus {
				in statusData : StatusReport {
					attribute switchState = processCommand.newState;
					attribute powerConsumption = measurePower.power;
					attribute energyUsed = updateEnergy.totalEnergy;
					attribute timestamp = 0.0 [s];
				}
			}
			
			then waitForCommand;
		}
	}
	
	requirement def RemoteControlRequirement {
		doc /* The system shall enable remote control of connected appliances 
		       via WiFi network commands from authorized mobile applications. */
		
		subject plug : WemoSmartPlug;
		
		require constraint {
			plug.wifiInterface.commands->notEmpty() implies
			(plug.controller.currentState == SwitchState::on or 
			 plug.controller.currentState == SwitchState::off)
		}
	}
	
	requirement def PowerMonitoringRequirement {
		doc /* The system shall continuously monitor and report power consumption 
		       and accumulated energy usage of connected appliances. */
		
		subject plug : WemoSmartPlug;
		
		require constraint {
			plug.meter.accumulatedEnergy >= 0.0 [J]
		}
	}
	
	requirement def ElectricalSafetyRequirement {
		doc /* The system shall operate safely within rated electrical specifications 
		       for standard North American residential power (120V, 15A maximum). */
		
		subject plug : WemoSmartPlug;
		
		require constraint {
			plug.acInput.acPower.voltage <= 125.0 [V] and
			plug.acInput.acPower.current <= 15.0 [A] and
			plug.acInput.acPower.frequency == 60.0 [Hz]
		}
	}
	
	requirement def WirelessConnectivityRequirement {
		doc /* The system shall maintain reliable WiFi connectivity for 
		       command reception and status reporting. */
		
		subject plug : WemoSmartPlug;
		
		require constraint {
			plug.wifi.isConnected == true
		}
	}
	
	part wemoSystem : WemoSmartPlug {
		satisfy RemoteControlRequirement;
		satisfy PowerMonitoringRequirement;
		satisfy ElectricalSafetyRequirement;
		satisfy WirelessConnectivityRequirement;
	}
	
	part def HomeElectricalSystem {
		part acSource : ACSource {
			port output : ACOutputPort {
				out item acPower : ACPower {
					attribute voltage = 120.0 [V];
					attribute current = 0.0 [A];
					attribute frequency = 60.0 [Hz];
				}
			}
		}
		
		part wemoPlug : WemoSmartPlug;
		
		part appliance : Appliance {
			port input : ACInputPort;
			attribute powerRating : PowerValue = 100.0 [W];
		}
		
		connect acSource.output to wemoPlug.acInput;
		connect wemoPlug.acOutput to appliance.input;
	}
	
	part def ACSource {
		port output : ACOutputPort;
	}
	
	part def Appliance {
		port input : ACInputPort;
		attribute powerRating : PowerValue;
	}
}
