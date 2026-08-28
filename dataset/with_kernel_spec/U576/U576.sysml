package HydraulicPowerSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	item def HydraulicFluid;
	attribute def Pressure :> Real;
	attribute def FlowRate :> Real;
	attribute def DisplacementCommand;
	attribute def StartSignal;
	attribute def PumpOnSignal;
	attribute def OverPressureAlert;
	attribute def ResetSignal;

	port def HydraulicPort {
		inout fluid : HydraulicFluid;
	}
	
	port def PressureSignalPort {
		out pressure : Pressure;
	}
	
	port def FlowRateSignalPort {
		out flowRate : FlowRate;
	}
	
	port def CommandInputPort {
		in command : DisplacementCommand;
	}
	
	port def CommandOutputPort {
		out command : DisplacementCommand;
	}

	part def Reservoir {
		port supplyPort : HydraulicPort;
		port returnPort : HydraulicPort;
	}

	part def Filter {
		port inPort : HydraulicPort;
		port outPort : HydraulicPort;
	}

	part def CheckValve {
		port inPort : HydraulicPort;
		port outPort : HydraulicPort;
	}

	part def VariableDisplacementPump {
		port inPort : HydraulicPort;
		port outPort : HydraulicPort;
		port commandPort : CommandInputPort;
		port pressureSensorPort : PressureSignalPort;
		port flowSensorPort : FlowRateSignalPort;
		
		exhibit state pumpStates : PumpStates;
	}
	
	part def PressureSensor {
		port fluidIn : HydraulicPort;
		port signalOut : PressureSignalPort;
	}
	
	part def FlowSensor {
		port fluidIn : HydraulicPort;
		port signalOut : FlowRateSignalPort;
	}

	part def HydraulicActuator {
		port inPort : HydraulicPort;
		port outPort : HydraulicPort;
	}

	part def PressureReliefValve {
		port inPort : HydraulicPort;
		port outPort : HydraulicPort;
	}

	part def DisplacementController {
		port pressureFeedbackPort { in pressure : Pressure; }
		port flowFeedbackPort { in flowRate : FlowRate; }
		port commandPort : CommandOutputPort;
	}

	state def PumpStates {
		entry; then stopped;
		state stopped;
		accept StartSignal then starting;
		state starting;
		accept PumpOnSignal then running;
		state running;
		accept OverPressureAlert then faulted;
		state faulted;
		accept ResetSignal then stopped;
	}

	part hydraulicSystem {
		part reservoir : Reservoir;
		part supplyFilter : Filter;
		part checkValve : CheckValve;
		part pump : VariableDisplacementPump;
		part pressureSensor : PressureSensor;
		part flowSensor : FlowSensor;
		part actuator : HydraulicActuator;
		part returnFilter : Filter;
		part reliefValve : PressureReliefValve;
		part controller : DisplacementController;
		
		flow supplyFlow of HydraulicFluid from reservoir.supplyPort.fluid to supplyFilter.inPort.fluid;
		flow filteredSupplyFlow of HydraulicFluid from supplyFilter.outPort.fluid to checkValve.inPort.fluid;
		flow checkedFlow of HydraulicFluid from checkValve.outPort.fluid to pump.inPort.fluid;
		flow highPressureFlow of HydraulicFluid from pump.outPort.fluid to actuator.inPort.fluid;
		flow pumpToPressureSensor of HydraulicFluid from pump.outPort.fluid to pressureSensor.fluidIn.fluid;
		flow pumpToFlowSensor of HydraulicFluid from pump.outPort.fluid to flowSensor.fluidIn.fluid;
		flow reliefInFlow of HydraulicFluid from pump.outPort.fluid to reliefValve.inPort.fluid;
		flow actuatorReturnFlow of HydraulicFluid from actuator.outPort.fluid to returnFilter.inPort.fluid;
		flow filteredReturnFlow of HydraulicFluid from returnFilter.outPort.fluid to reservoir.returnPort.fluid;
		flow reliefOutFlow of HydraulicFluid from reliefValve.outPort.fluid to reservoir.returnPort.fluid;
		
		flow commandFlow of DisplacementCommand from controller.commandPort.command to pump.commandPort.command;
		flow pressureFeedback of Pressure from pressureSensor.signalOut.pressure to controller.pressureFeedbackPort.pressure;
		flow flowFeedback of FlowRate from flowSensor.signalOut.flowRate to controller.flowFeedbackPort.flowRate;
	}
	
	requirement def HydraulicSystemRequirements {
		text = "This model describes a closed-loop hydraulic power system designed to precisely control and power a hydraulic actuator. The heart of the system is a variable displacement pump, which allows the amount of hydraulic fluid moved per revolution to be changed, enabling fine control over the flow rate and pressure supplied to the rest of the circuit. The system's operation begins at a fluid reservoir, which stores the hydraulic fluid at ambient pressure. From the reservoir, the fluid is drawn through a supply filter to remove contaminants and a check valve that ensures one-way flow into the variable displacement pump. The pump, driven at a constant rotational speed, pressurizes the fluid. The amount of flow it generates is determined by a command signal from a dedicated displacement controller. This high-pressure fluid is then directed towards a hydraulic actuator, which is the component that performs mechanical work (such as extending or retracting a piston). After passing through the actuator, the now lower-pressure fluid is routed through a return filter to remove any contaminants generated during operation before flowing back into the reservoir, completing the circuit. The entire system is actively managed for precision and safety. The displacement controller acts as the brain, continuously receiving feedback from a pressure sensor and a flow sensor located at the pump's outlet. It compares these actual readings to the desired target values and adjusts its command to the pump to maintain the required pressure and flow. For safety, a pressure relief valve is installed in the high-pressure line. If the pressure exceeds a safe limit, this valve automatically opens and diverts excess fluid back to the reservoir, protecting the components from damage. The pump itself operates in several states, including stopped, starting, running, and a faulted state. It can transition to the faulted state and shut down automatically if an overpressure condition is detected, providing an additional layer of safety.";
	}
}
