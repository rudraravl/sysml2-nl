package 'LiquidCapacitiveInclinometer' {
	private import ISQ::*;
	private import ScalarValues::*;
	
	package Definitions {
		item def DielectricFluid;
		item def AnodizedAluminum;
		item def GoldPlatedCopper;
		
		attribute def TiltAngle :> Real;
		attribute def TempValue :> Real;
		attribute def VoltageValue :> Real;
		attribute def CapacitanceValue :> Real;
		attribute def FrequencyValue :> Real;
		attribute def DigitalValue :> Integer;
		
		attribute def ACExcitation {
			attribute amplitude : VoltageValue;
			attribute frequency : FrequencyValue;
		}
		attribute def AnalogSignal :> VoltageValue;
		attribute def AngleData {
			attribute angle : TiltAngle;
			attribute temperature : TempValue;
		}
		attribute def InitComplete;
		attribute def CalibrationRequest;
		attribute def CalibrationComplete;
		attribute def FaultDetected;
		attribute def Reset;
		
		port def ExcitationPort {
			out excitation : ACExcitation;
		}
		port def CapacitancePort {
			out capacitance : CapacitanceValue;
		}
		port def AnalogSignalPort {
			out signal : AnalogSignal;
		}
		port def DigitalSignalPort {
			out data : DigitalValue;
		}
		port def TempSignalPort {
			out temp : TempValue;
		}
		port def AngleDataPort {
			out data : AngleData;
		}
		port def RS485Port {
			out data : AngleData;
		}
		
		interface def ExcitationInterface {
			end supplier : ExcitationPort;
			end consumer : ~ExcitationPort;
			flow of ACExcitation from supplier.excitation to consumer.excitation;
		}
		interface def CapacitanceInterface {
			end supplier : CapacitancePort;
			end consumer : ~CapacitancePort;
			flow of CapacitanceValue from supplier.capacitance to consumer.capacitance;
		}
		interface def AnalogSignalInterface {
			end supplier : AnalogSignalPort;
			end consumer : ~AnalogSignalPort;
			flow of AnalogSignal from supplier.signal to consumer.signal;
		}
		interface def DigitalSignalInterface {
			end supplier : DigitalSignalPort;
			end consumer : ~DigitalSignalPort;
			flow of DigitalValue from supplier.data to consumer.data;
		}
		interface def TempSignalInterface {
			end supplier : TempSignalPort;
			end consumer : ~TempSignalPort;
			flow of TempValue from supplier.temp to consumer.temp;
		}
		interface def AngleDataInterface {
			end supplier : AngleDataPort;
			end consumer : ~AngleDataPort;
			flow of AngleData from supplier.data to consumer.data;
		}
		interface def RS485Interface {
			end supplier : RS485Port;
			end consumer : ~RS485Port;
			flow of AngleData from supplier.data to consumer.data;
		}
		
		part def Inclinometer {
			port rs485Port : RS485Port;
			exhibit state 'operational states' : 'Operational States';
		}
		
		part def SealedChamber {
			attribute material : AnodizedAluminum;
			part fluid : DielectricFluid;
			part plate1 : GoldPlatedCopper;
			part plate2 : GoldPlatedCopper;
			port excitationIn : ~ExcitationPort;
			port capOut : CapacitancePort;
		}
		
		part def ExcitationCircuit {
			port excitationPort : ExcitationPort;
		}
		
		part def CapacitanceBridge {
			port inPort : ~CapacitancePort;
			port outPort : AnalogSignalPort;
		}
		
		part def SignalConditioner {
			port inPort : ~AnalogSignalPort;
			port outPort : AnalogSignalPort;
		}
		
		part def ADC {
			attribute resolution : Integer = 16;
			port inPort : ~AnalogSignalPort;
			port outPort : DigitalSignalPort;
		}
		
		part def TemperatureSensor {
			port outPort : TempSignalPort;
		}
		
		part def CPU {
			port digitalIn : ~DigitalSignalPort;
			port tempIn : ~TempSignalPort;
			port angleOut : AngleDataPort;
		}
		
		part def CommInterface {
			port inPort : ~AngleDataPort;
			port outPort : RS485Port;
		}
		
		part def ExternalSystem {
			port rs485Port : ~RS485Port;
		}
		
		action def 'Perform Self Test';
		action def 'Measure Capacitance';
		action def 'Calculate Tilt Angle';
		action def 'Transmit Data';
		
		state def 'Operational States' {
			entry; then initialization;
			state initialization {
				entry action 'perform self test' : 'Perform Self Test';
			}
			transition init_to_main
				first initialization
				accept InitComplete
				then main_loop;
			state main_loop {
				entry; then 'measure capacitance';
				action 'measure capacitance' : 'Measure Capacitance';
				transition first 'measure capacitance' then 'calculate tilt angle';
				action 'calculate tilt angle' : 'Calculate Tilt Angle';
				transition first 'calculate tilt angle' then 'transmit data';
				action 'transmit data' : 'Transmit Data';
				transition first 'transmit data' then 'measure capacitance';
			}
			transition main_to_cal
				first main_loop
				accept CalibrationRequest
				then calibration;
			state calibration;
			transition cal_to_main
				first calibration
				accept CalibrationComplete
				then main_loop;
			transition main_to_fault
				first main_loop
				accept FaultDetected
				then fault;
			state fault;
			transition fault_to_init
				first fault
				accept Reset
				then initialization;
		}
		
		requirement def 'High Precision Measurement' {
			subject inclinometer : Inclinometer;
			doc /* The inclinometer shall measure tilt angle with high accuracy and stability. */
		}
		
		requirement def 'Operating Temperature Range' {
			doc /* The system shall operate within a temperature range of -20 degC to +85 degC. */
			attribute minTemp : TempValue = -20;
			attribute maxTemp : TempValue = 85;
		}
		
		requirement def 'ADC Resolution' {
			doc /* A high-resolution 16-bit analog-to-digital converter shall be used. */
			attribute resolution : Integer = 16;
		}
		
		requirement def 'RS485 Communication' {
			doc /* The device shall transmit angle data using standard RS485 industrial protocol. */
		}
		
		requirement def 'Low Power Consumption' {
			doc /* The entire system shall be designed for low power consumption. */
		}
		
		requirement def 'Operational States' {
			doc /* The system shall support initialization with self-tests, a main measurement loop, a dedicated calibration mode, and a fault state for error handling. */
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part inclinometer : Inclinometer {
			part chamber : SealedChamber;
			part excitationCircuit : ExcitationCircuit;
			part capacitanceBridge : CapacitanceBridge;
			part signalConditioner : SignalConditioner;
			part adc : ADC;
			part tempSensor : TemperatureSensor;
			part cpu : CPU;
			part commInterface : CommInterface;
			
			interface 'Excitation Connection' : ExcitationInterface 
				connect excitationCircuit.excitationPort to chamber.excitationIn;
			interface 'Capacitance Connection' : CapacitanceInterface 
				connect chamber.capOut to capacitanceBridge.inPort;
			interface 'Analog Signal Connection' : AnalogSignalInterface 
				connect capacitanceBridge.outPort to signalConditioner.inPort;
			interface 'Conditioned Signal Connection' : AnalogSignalInterface 
				connect signalConditioner.outPort to adc.inPort;
			interface 'Digital Signal Connection' : DigitalSignalInterface 
				connect adc.outPort to cpu.digitalIn;
			interface 'Temperature Signal Connection' : TempSignalInterface 
				connect tempSensor.outPort to cpu.tempIn;
			interface 'Angle Data Connection' : AngleDataInterface 
				connect cpu.angleOut to commInterface.inPort;
			bind rs485Port = commInterface.outPort;
		}
		
		part externalSystem : ExternalSystem;
		interface 'RS485 Connection' : RS485Interface 
			connect inclinometer.rs485Port to externalSystem.rs485Port;
		
		requirement 'High Precision Requirement' : 'High Precision Measurement' {
			subject :>> inclinometer;
		}
		requirement 'Temperature Range Requirement' : 'Operating Temperature Range';
		requirement 'ADC Resolution Requirement' : 'ADC Resolution';
		requirement 'RS485 Requirement' : 'RS485 Communication';
		requirement 'Low Power Requirement' : 'Low Power Consumption';
		requirement 'States Requirement' : 'Operational States';
	}
}
